from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.security import get_current_staff
from app.models.game import GameType, GameDifficulty, GameCategory
from app.schemas.game import (
    GameOut, GameListOut, StartSessionOut, SubmitAnswerRequest,
    SubmitAnswerOut, GameSessionOut, LeaderboardEntryOut,
    AIGenerateRequest, MessageResponse,
)
from app.services.game_service import (
    get_games, get_game_by_id, get_daily_challenge,
    start_session, submit_answer, abandon_session,
    get_my_sessions, get_leaderboard, get_my_leaderboard_entry,
)

router = APIRouter(prefix="/games", tags=["Games & Leaderboard"])


# ─── List Games ───────────────────────────────────────────────────────────────

@router.get("/", response_model=List[GameListOut])
async def list_games(
    game_type:  Optional[GameType]       = Query(None),
    difficulty: Optional[GameDifficulty] = Query(None),
    category:   Optional[GameCategory]   = Query(None),
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """List all active games with optional filters."""
    games = await get_games(db, game_type, difficulty, category)
    return games


# ─── Daily Challenge ──────────────────────────────────────────────────────────

@router.get("/daily", response_model=GameOut)
async def daily_challenge(
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Get today's daily challenge game."""
    game = await get_daily_challenge(db)
    if not game:
        raise HTTPException(
            status_code=404,
            detail="No daily challenge available. Ask admin to add games.")
    return game


# ─── Get Single Game ──────────────────────────────────────────────────────────

@router.get("/{game_id}", response_model=GameOut)
async def get_game(
    game_id: int,
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    game = await get_game_by_id(db, game_id)
    if not game:
        raise HTTPException(status_code=404, detail="Game not found.")
    return game


# ─── Start Session ────────────────────────────────────────────────────────────

@router.post("/{game_id}/start", status_code=status.HTTP_201_CREATED)
async def start_game_session(
    game_id: int,
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Start a new game session. Returns game payload to play."""
    session = await start_session(db, game_id, current_staff.id)
    game    = await get_game_by_id(db, game_id)
    await db.commit()

    # Build payload — hide answer for quiz/true_false
    payload = dict(game.payload)
    if game.game_type.value in ("quiz", "true_false"):
        payload.pop("answer", None)
        payload.pop("explanation", None)
    if game.game_type.value == "word_scramble":
        payload["scrambled"] = session.session_data.get("scrambled", "")
        payload.pop("word", None)
    if game.game_type.value == "hangman":
        word = payload.get("word", "")
        payload["word_length"] = len(word)
        payload["display"]     = ["_"] * len(word)
        payload.pop("word", None)

    dept = current_staff.department.value \
        if hasattr(current_staff.department, 'value') \
        else str(current_staff.department)

    return {
        "session_id":  session.id,
        "game_id":     game.id,
        "game_type":   game.game_type.value,
        "title":       game.title,
        "difficulty":  game.difficulty.value,
        "category":    game.category.value,
        "payload":     payload,
        "base_points": game.base_points,
        "started_at":  session.started_at,
    }


# ─── Submit Answer ────────────────────────────────────────────────────────────

@router.post("/sessions/{session_id}/submit")
async def submit_game_answer(
    session_id: int,
    payload: SubmitAnswerRequest,
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Submit answer for a game session."""
    is_correct, score, correct_answer, explanation, total_score = \
        await submit_answer(
            db, session_id, current_staff.id,
            payload.answer, payload.time_taken_secs
        )
    await db.commit()
    return {
        "is_correct":     is_correct,
        "score":          score,
        "correct_answer": correct_answer,
        "explanation":    explanation,
        "session_id":     session_id,
        "total_score":    total_score,
    }


# ─── Abandon Session ──────────────────────────────────────────────────────────

@router.post("/sessions/{session_id}/abandon")
async def abandon_game_session(
    session_id: int,
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    await abandon_session(db, session_id, current_staff.id)
    await db.commit()
    return {"message": "Session abandoned."}


# ─── My Sessions ─────────────────────────────────────────────────────────────

@router.get("/sessions/me", response_model=List[GameSessionOut])
async def my_sessions(
    limit: int = Query(default=20, le=50),
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Get my recent game sessions."""
    sessions = await get_my_sessions(db, current_staff.id, limit)
    return sessions


# ─── Leaderboard ─────────────────────────────────────────────────────────────

@router.get("/leaderboard/all")
async def leaderboard(
    limit: int = Query(default=20, le=50),
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Get top staff leaderboard."""
    entries = await get_leaderboard(db, limit)
    my_entry = await get_my_leaderboard_entry(db, current_staff.id)
    return {
        "leaderboard": entries,
        "my_stats": {
            "total_score":    my_entry.total_score    if my_entry else 0,
            "games_played":   my_entry.games_played   if my_entry else 0,
            "games_won":      my_entry.games_won       if my_entry else 0,
            "current_streak": my_entry.current_streak  if my_entry else 0,
            "best_streak":    my_entry.best_streak     if my_entry else 0,
        },
    }


# ─── AI Generate Games ────────────────────────────────────────────────────────

@router.post("/ai-generate", status_code=status.HTTP_201_CREATED)
async def ai_generate_games(
    payload: AIGenerateRequest,
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """
    Use Groq AI to auto-generate game questions and save them.
    Use this to populate your games database quickly.
    """
    from app.services.ai_service import generate_game_question
    from app.models.game import Game

    created = []
    for _ in range(payload.count):
        data = await generate_game_question(
            game_type=payload.game_type.value,
            difficulty=payload.difficulty.value,
            category=payload.category.value,
        )
        if not data:
            continue

        title = data.pop("title", f"AI {payload.game_type.value.replace('_',' ').title()}")

        game = Game(
            game_type=payload.game_type,
            difficulty=payload.difficulty,
            category=payload.category,
            title=title,
            description=f"AI-generated {payload.difficulty.value} {payload.category.value} question",
            payload=data,
            base_points={"easy":10,"medium":20,"hard":40}.get(payload.difficulty.value, 20),
            is_active=True,
            is_daily=False,
        )
        db.add(game)
        await db.flush()
        created.append({"id": game.id, "title": title})

    await db.commit()
    return {
        "message": f"Generated {len(created)} game(s) successfully.",
        "games": created,
    }


# ─── Seed Sample Games (admin use) ───────────────────────────────────────────

@router.post("/seed", status_code=status.HTTP_201_CREATED)
async def seed_sample_games(
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """
    Seed the database with 20 sample games across all types.
    Call this once to populate your games list.
    """
    from app.models.game import Game, GameType, GameDifficulty, GameCategory

    sample_games = [
        # ── QUIZ ──────────────────────────────────────────────────────────────
        {
            "game_type": GameType.QUIZ, "difficulty": GameDifficulty.EASY,
            "category": GameCategory.GENERAL,
            "title": "What is the capital of India?",
            "payload": {
                "question": "What is the capital of India?",
                "options": ["A. Mumbai", "B. New Delhi", "C. Kolkata", "D. Chennai"],
                "answer": "B",
                "explanation": "New Delhi is the capital of India."
            },
        },
        {
            "game_type": GameType.QUIZ, "difficulty": GameDifficulty.EASY,
            "category": GameCategory.TECHNOLOGY,
            "title": "What does CPU stand for?",
            "payload": {
                "question": "What does CPU stand for?",
                "options": [
                    "A. Central Processing Unit",
                    "B. Computer Personal Unit",
                    "C. Central Program Unit",
                    "D. Computer Processing Unit"
                ],
                "answer": "A",
                "explanation": "CPU stands for Central Processing Unit — the brain of a computer."
            },
        },
        {
            "game_type": GameType.QUIZ, "difficulty": GameDifficulty.MEDIUM,
            "category": GameCategory.SCIENCE,
            "title": "What is the chemical symbol for Gold?",
            "payload": {
                "question": "What is the chemical symbol for Gold?",
                "options": ["A. Go", "B. Gd", "C. Au", "D. Ag"],
                "answer": "C",
                "explanation": "Gold's symbol 'Au' comes from the Latin word 'Aurum'."
            },
        },
        {
            "game_type": GameType.QUIZ, "difficulty": GameDifficulty.MEDIUM,
            "category": GameCategory.MATHEMATICS,
            "title": "What is the value of π (pi) to 2 decimal places?",
            "payload": {
                "question": "What is the value of π (pi) to 2 decimal places?",
                "options": ["A. 3.12", "B. 3.14", "C. 3.16", "D. 3.18"],
                "answer": "B",
                "explanation": "Pi (π) ≈ 3.14159... Rounded to 2 decimal places = 3.14"
            },
        },
        {
            "game_type": GameType.QUIZ, "difficulty": GameDifficulty.HARD,
            "category": GameCategory.TECHNOLOGY,
            "title": "Which sorting algorithm has O(n log n) average time?",
            "payload": {
                "question": "Which sorting algorithm has O(n log n) average time complexity?",
                "options": ["A. Bubble Sort", "B. Selection Sort", "C. Merge Sort", "D. Insertion Sort"],
                "answer": "C",
                "explanation": "Merge Sort always runs in O(n log n) in best, average, and worst case."
            },
        },
        {
            "game_type": GameType.QUIZ, "difficulty": GameDifficulty.EASY,
            "category": GameCategory.ENGLISH,
            "title": "Which is the correct spelling?",
            "payload": {
                "question": "Which of the following is spelled correctly?",
                "options": ["A. Recieve", "B. Receive", "C. Receve", "D. Recieve"],
                "answer": "B",
                "explanation": "'Receive' — remember: I before E except after C."
            },
        },
        {
            "game_type": GameType.QUIZ, "difficulty": GameDifficulty.MEDIUM,
            "category": GameCategory.COLLEGE_LIFE,
            "title": "What is a semester credit hour?",
            "payload": {
                "question": "In college, what does 'credit hour' typically represent?",
                "options": [
                    "A. Hours spent in library",
                    "B. One hour of class per week for one semester",
                    "C. Total exam marks",
                    "D. Number of assignments submitted"
                ],
                "answer": "B",
                "explanation": "One credit hour = one hour of classroom instruction per week for 15-16 weeks."
            },
        },
        {
            "game_type": GameType.QUIZ, "difficulty": GameDifficulty.HARD,
            "category": GameCategory.SCIENCE,
            "title": "What is the speed of light?",
            "payload": {
                "question": "What is the approximate speed of light in a vacuum?",
                "options": [
                    "A. 3 × 10⁶ m/s",
                    "B. 3 × 10⁸ m/s",
                    "C. 3 × 10¹⁰ m/s",
                    "D. 3 × 10¹² m/s"
                ],
                "answer": "B",
                "explanation": "The speed of light is approximately 3 × 10⁸ meters per second (299,792,458 m/s)."
            },
        },

        # ── TRUE / FALSE ──────────────────────────────────────────────────────
        {
            "game_type": GameType.TRUE_FALSE, "difficulty": GameDifficulty.EASY,
            "category": GameCategory.TECHNOLOGY,
            "title": "Python is a compiled language — True or False?",
            "payload": {
                "statement": "Python is a compiled programming language.",
                "answer": False,
                "explanation": "Python is an interpreted language, not compiled like C or Java."
            },
        },
        {
            "game_type": GameType.TRUE_FALSE, "difficulty": GameDifficulty.EASY,
            "category": GameCategory.SCIENCE,
            "title": "Water boils at 100°C at sea level — True or False?",
            "payload": {
                "statement": "Water boils at 100°C at sea level.",
                "answer": True,
                "explanation": "Water boils at 100°C (212°F) at standard atmospheric pressure (sea level)."
            },
        },
        {
            "game_type": GameType.TRUE_FALSE, "difficulty": GameDifficulty.MEDIUM,
            "category": GameCategory.MATHEMATICS,
            "title": "Zero is a positive number — True or False?",
            "payload": {
                "statement": "Zero (0) is classified as a positive number.",
                "answer": False,
                "explanation": "Zero is neither positive nor negative. It is a neutral integer."
            },
        },
        {
            "game_type": GameType.TRUE_FALSE, "difficulty": GameDifficulty.MEDIUM,
            "category": GameCategory.GENERAL,
            "title": "The Great Wall of China is visible from space — True or False?",
            "payload": {
                "statement": "The Great Wall of China is clearly visible from space with the naked eye.",
                "answer": False,
                "explanation": "This is a common myth. Astronauts have confirmed it is not visible from space without aid."
            },
        },

        # ── WORD SCRAMBLE ─────────────────────────────────────────────────────
        {
            "game_type": GameType.WORD_SCRAMBLE, "difficulty": GameDifficulty.EASY,
            "category": GameCategory.TECHNOLOGY,
            "title": "Unscramble: Computer Term",
            "payload": {
                "word": "PYTHON",
                "hint": "A popular programming language named after a snake 🐍",
                "category": "Technology"
            },
        },
        {
            "game_type": GameType.WORD_SCRAMBLE, "difficulty": GameDifficulty.MEDIUM,
            "category": GameCategory.TECHNOLOGY,
            "title": "Unscramble: Database Term",
            "payload": {
                "word": "DATABASE",
                "hint": "Organized collection of structured data 💾",
                "category": "Technology"
            },
        },
        {
            "game_type": GameType.WORD_SCRAMBLE, "difficulty": GameDifficulty.EASY,
            "category": GameCategory.COLLEGE_LIFE,
            "title": "Unscramble: College Term",
            "payload": {
                "word": "SEMESTER",
                "hint": "Half of an academic year 📚",
                "category": "College Life"
            },
        },
        {
            "game_type": GameType.WORD_SCRAMBLE, "difficulty": GameDifficulty.HARD,
            "category": GameCategory.SCIENCE,
            "title": "Unscramble: Science Term",
            "payload": {
                "word": "PHOTOSYNTHESIS",
                "hint": "Process plants use to make food from sunlight 🌱",
                "category": "Science"
            },
        },

        # ── HANGMAN ───────────────────────────────────────────────────────────
        {
            "game_type": GameType.HANGMAN, "difficulty": GameDifficulty.EASY,
            "category": GameCategory.TECHNOLOGY,
            "title": "Hangman: Programming Language",
            "payload": {
                "word": "FLUTTER",
                "hint": "Google's UI framework for cross-platform apps 📱",
                "category": "Technology",
                "max_attempts": 6
            },
        },
        {
            "game_type": GameType.HANGMAN, "difficulty": GameDifficulty.MEDIUM,
            "category": GameCategory.COLLEGE_LIFE,
            "title": "Hangman: Academic Term",
            "payload": {
                "word": "CURRICULUM",
                "hint": "The subjects forming a course of study 📋",
                "category": "College Life",
                "max_attempts": 6
            },
        },
        {
            "game_type": GameType.HANGMAN, "difficulty": GameDifficulty.EASY,
            "category": GameCategory.GENERAL,
            "title": "Hangman: Country",
            "payload": {
                "word": "CANADA",
                "hint": "North American country known for maple syrup 🍁",
                "category": "General",
                "max_attempts": 6
            },
        },
        {
            "game_type": GameType.HANGMAN, "difficulty": GameDifficulty.HARD,
            "category": GameCategory.TECHNOLOGY,
            "title": "Hangman: Tech Company",
            "payload": {
                "word": "ALGORITHM",
                "hint": "Step-by-step procedure for solving a problem 🔢",
                "category": "Technology",
                "max_attempts": 6
            },
        },
    ]

    added = 0
    for g in sample_games:
        payload_data = g.pop("payload")
        game = Game(
            **g,
            payload=payload_data,
            base_points={"easy":10,"medium":20,"hard":40}.get(
                g["difficulty"].value, 20),
            is_active=True,
            is_daily=(added < 3),
        )
        db.add(game)
        added += 1

    await db.commit()
    return {"message": f"Seeded {added} sample games successfully!"}

