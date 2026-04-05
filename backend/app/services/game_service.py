import random
from datetime import datetime, timezone
from typing import List, Optional, Tuple, Any

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func
from sqlalchemy.orm import selectinload
from fastapi import HTTPException

from app.models.game import (
    Game, GameSession, Leaderboard,
    GameType, GameDifficulty, GameSessionStatus
)
from app.models.staff import Staff


# ─── Scoring ──────────────────────────────────────────────────────────────────

SCORE_TABLE = {
    GameDifficulty.EASY:   {"base": 10, "time_bonus": 5,  "max_time": 30},
    GameDifficulty.MEDIUM: {"base": 20, "time_bonus": 10, "max_time": 60},
    GameDifficulty.HARD:   {"base": 40, "time_bonus": 20, "max_time": 120},
}

MAX_ATTEMPTS = {
    GameType.QUIZ:          1,
    GameType.TRUE_FALSE:    1,
    GameType.WORD_SCRAMBLE: 3,
    GameType.HANGMAN:       6,
    GameType.WORD_SEARCH:   1,
}


def calculate_score(
    game: Game,
    is_correct: bool,
    time_taken: Optional[int],
    attempts: int,
) -> int:
    if not is_correct:
        return 0
    cfg = SCORE_TABLE.get(game.difficulty, SCORE_TABLE[GameDifficulty.MEDIUM])
    score = cfg["base"]
    # Time bonus
    if time_taken is not None and time_taken < cfg["max_time"]:
        bonus = max(0, cfg["time_bonus"] - int(time_taken / 5))
        score += bonus
    # Attempt penalty
    if attempts > 1:
        score = max(1, score - (attempts - 1) * 3)
    return score


def check_answer(game: Game, answer: Any, session: GameSession) -> Tuple[bool, Any, Optional[str]]:
    """
    Check if the answer is correct.
    Returns (is_correct, correct_answer, explanation)
    """
    payload = game.payload
    gtype   = game.game_type

    if gtype == GameType.QUIZ:
        correct = payload.get("answer", "").strip().upper()
        given   = str(answer).strip().upper()
        # Accept just the letter "A" or full "A. Option text"
        given_letter = given[0] if given else ""
        is_correct = given_letter == correct[0] if correct else False
        return is_correct, correct, payload.get("explanation")

    if gtype == GameType.TRUE_FALSE:
        correct = payload.get("answer", False)
        if isinstance(answer, str):
            given = answer.lower() in ("true", "1", "yes")
        else:
            given = bool(answer)
        return given == correct, correct, payload.get("explanation")

    if gtype in (GameType.WORD_SCRAMBLE, GameType.HANGMAN):
        correct = payload.get("word", "").strip().upper()
        given   = str(answer).strip().upper()
        return given == correct, correct, payload.get("hint")

    if gtype == GameType.WORD_SEARCH:
        # answer = list of words found
        words   = [w.upper() for w in payload.get("words", [])]
        given   = [w.upper() for w in (answer if isinstance(answer, list) else [])]
        found   = [w for w in given if w in words]
        is_correct = len(found) == len(words)
        return is_correct, words, None

    return False, None, None


def scramble_word(word: str) -> str:
    chars = list(word.upper())
    random.shuffle(chars)
    scrambled = "".join(chars)
    if scrambled == word.upper() and len(word) > 1:
        return scramble_word(word)
    return scrambled


# ─── CRUD ─────────────────────────────────────────────────────────────────────

async def get_games(
    db: AsyncSession,
    game_type: Optional[GameType] = None,
    difficulty: Optional[GameDifficulty] = None,
    category=None,
) -> List[Game]:
    q = select(Game).where(Game.is_active == True)
    if game_type:
        q = q.where(Game.game_type == game_type)
    if difficulty:
        q = q.where(Game.difficulty == difficulty)
    if category:
        q = q.where(Game.category == category)
    q = q.order_by(Game.created_at.desc())
    result = await db.execute(q)
    return result.scalars().all()


async def get_game_by_id(db: AsyncSession, game_id: int) -> Optional[Game]:
    result = await db.execute(select(Game).where(Game.id == game_id))
    return result.scalar_one_or_none()


async def get_daily_challenge(db: AsyncSession) -> Optional[Game]:
    result = await db.execute(
        select(Game)
        .where(Game.is_active == True, Game.is_daily == True)
        .order_by(func.random())
        .limit(1)
    )
    game = result.scalar_one_or_none()
    if not game:
        # Fallback to any random game
        result = await db.execute(
            select(Game).where(Game.is_active == True)
            .order_by(func.random()).limit(1)
        )
        game = result.scalar_one_or_none()
    return game


async def start_session(
    db: AsyncSession, game_id: int, staff_id: int
) -> GameSession:
    game = await get_game_by_id(db, game_id)
    if not game:
        raise HTTPException(status_code=404, detail="Game not found.")
    if not game.is_active:
        raise HTTPException(status_code=400, detail="This game is not active.")

    # Increment play count
    game.play_count = (game.play_count or 0) + 1

    # For word_scramble, store scrambled in session_data
    session_data = {}
    if game.game_type == GameType.WORD_SCRAMBLE:
        word = game.payload.get("word", "")
        session_data["scrambled"] = scramble_word(word)
    if game.game_type == GameType.HANGMAN:
        session_data["wrong_guesses"] = []
        session_data["revealed"] = []

    session = GameSession(
        game_id=game_id,
        staff_id=staff_id,
        status=GameSessionStatus.ACTIVE,
        session_data=session_data,
    )
    db.add(session)
    await db.flush()
    await db.refresh(session)
    return session


async def submit_answer(
    db: AsyncSession,
    session_id: int,
    staff_id: int,
    answer: Any,
    time_taken: Optional[int],
) -> Tuple[bool, int, Any, Optional[str], int]:
    """Returns (is_correct, score, correct_answer, explanation, total_score)"""

    result = await db.execute(
        select(GameSession)
        .options(selectinload(GameSession.game))
        .where(GameSession.id == session_id, GameSession.staff_id == staff_id)
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found.")
    if session.status != GameSessionStatus.ACTIVE:
        raise HTTPException(status_code=400, detail="Session already completed.")

    session.attempts = (session.attempts or 0) + 1
    game = session.game

    is_correct, correct_answer, explanation = check_answer(game, answer, session)
    score = calculate_score(game, is_correct, time_taken, session.attempts)

    session.is_correct      = is_correct
    session.score           = score
    session.time_taken_secs = time_taken
    session.status          = GameSessionStatus.COMPLETED
    session.completed_at    = datetime.now(timezone.utc)

    await db.flush()

    # Update leaderboard
    total_score = await update_leaderboard(db, staff_id, score, is_correct)

    return is_correct, score, correct_answer, explanation, total_score


async def abandon_session(
    db: AsyncSession, session_id: int, staff_id: int
) -> None:
    result = await db.execute(
        select(GameSession).where(
            GameSession.id == session_id,
            GameSession.staff_id == staff_id,
        )
    )
    session = result.scalar_one_or_none()
    if session:
        session.status = GameSessionStatus.ABANDONED
        session.completed_at = datetime.now(timezone.utc)
        await db.flush()


async def get_my_sessions(
    db: AsyncSession, staff_id: int, limit: int = 20
) -> List[GameSession]:
    result = await db.execute(
        select(GameSession)
        .where(GameSession.staff_id == staff_id)
        .options(selectinload(GameSession.game))
        .order_by(GameSession.started_at.desc())
        .limit(limit)
    )
    return result.scalars().all()


# ─── Leaderboard ──────────────────────────────────────────────────────────────

async def update_leaderboard(
    db: AsyncSession, staff_id: int, score: int, won: bool
) -> int:
    result = await db.execute(
        select(Leaderboard).where(Leaderboard.staff_id == staff_id)
    )
    entry = result.scalar_one_or_none()

    if not entry:
        entry = Leaderboard(
            staff_id=staff_id,
            total_score=0,
            games_played=0,
            games_won=0,
            current_streak=0,
            best_streak=0,
        )
        db.add(entry)

    entry.total_score  = (entry.total_score or 0) + score
    entry.games_played = (entry.games_played or 0) + 1

    if won:
        entry.games_won      = (entry.games_won or 0) + 1
        entry.current_streak = (entry.current_streak or 0) + 1
        if entry.current_streak > (entry.best_streak or 0):
            entry.best_streak = entry.current_streak
    else:
        entry.current_streak = 0

    await db.flush()
    return entry.total_score


async def get_leaderboard(db: AsyncSession, limit: int = 20):
    result = await db.execute(
        select(Leaderboard, Staff)
        .join(Staff, Leaderboard.staff_id == Staff.id)
        .order_by(Leaderboard.total_score.desc())
        .limit(limit)
    )
    rows = result.all()
    entries = []
    for rank, (lb, staff) in enumerate(rows, start=1):
        dept = staff.department.value \
            if hasattr(staff.department, 'value') else str(staff.department)
        entries.append({
            "rank":           rank,
            "staff_id":       staff.id,
            "full_name":      staff.full_name,
            "department":     dept,
            "avatar_url":     staff.avatar_url,
            "total_score":    lb.total_score or 0,
            "games_played":   lb.games_played or 0,
            "games_won":      lb.games_won or 0,
            "current_streak": lb.current_streak or 0,
            "best_streak":    lb.best_streak or 0,
        })
    return entries


async def get_my_leaderboard_entry(db: AsyncSession, staff_id: int):
    result = await db.execute(
        select(Leaderboard).where(Leaderboard.staff_id == staff_id)
    )
    return result.scalar_one_or_none()