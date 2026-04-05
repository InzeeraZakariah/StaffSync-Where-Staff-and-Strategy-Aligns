from sqlalchemy import (
    Column, Integer, String, Boolean, DateTime,
    ForeignKey, Text, JSON, Float, Enum
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum

from app.db.session import Base


class GameType(str, enum.Enum):
    QUIZ         = "quiz"
    WORD_SCRAMBLE = "word_scramble"
    HANGMAN      = "hangman"
    WORD_SEARCH  = "word_search"
    TRUE_FALSE   = "true_false"


class GameDifficulty(str, enum.Enum):
    EASY   = "easy"
    MEDIUM = "medium"
    HARD   = "hard"


class GameSessionStatus(str, enum.Enum):
    ACTIVE    = "active"
    COMPLETED = "completed"
    ABANDONED = "abandoned"


class GameCategory(str, enum.Enum):
    GENERAL      = "general"
    TECHNOLOGY   = "technology"
    SCIENCE      = "science"
    COLLEGE_LIFE = "college_life"
    MATHEMATICS  = "mathematics"
    ENGLISH      = "english"
    HISTORY      = "history"
    SPORTS       = "sports"


# ─── Game (question/puzzle) ───────────────────────────────────────────────────

class Game(Base):
    __tablename__ = "games"

    id          = Column(Integer, primary_key=True, index=True)
    game_type   = Column(Enum(GameType), nullable=False)
    difficulty  = Column(Enum(GameDifficulty), nullable=False, default=GameDifficulty.MEDIUM)
    category    = Column(Enum(GameCategory), nullable=False, default=GameCategory.GENERAL)
    title       = Column(String(300), nullable=False)
    description = Column(Text, nullable=True)
    is_active   = Column(Boolean, default=True)
    is_daily    = Column(Boolean, default=False)
    play_count  = Column(Integer, default=0)

    # Game-specific payload stored as JSON
    # quiz:         { question, options:[A,B,C,D], answer:"A", explanation }
    # word_scramble:{ word, scrambled, hint, category }
    # hangman:      { word, hint, category, max_attempts:6 }
    # word_search:  { words:[], grid:[[]], size:10 }
    # true_false:   { statement, answer:true/false, explanation }
    payload     = Column(JSON, nullable=False, default=dict)

    # Points
    base_points     = Column(Integer, default=10)
    time_bonus_secs = Column(Integer, default=30)

    created_at  = Column(DateTime(timezone=True), server_default=func.now())
    updated_at  = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    sessions    = relationship("GameSession", back_populates="game")


# ─── Game Session (one play) ──────────────────────────────────────────────────

class GameSession(Base):
    __tablename__ = "game_sessions"

    id          = Column(Integer, primary_key=True, index=True)
    game_id     = Column(Integer, ForeignKey("games.id", ondelete="CASCADE"), nullable=False)
    staff_id    = Column(Integer, ForeignKey("staff.id", ondelete="CASCADE"), nullable=False)
    status      = Column(Enum(GameSessionStatus), nullable=False, default=GameSessionStatus.ACTIVE)

    score           = Column(Integer, default=0)
    max_score       = Column(Integer, default=0)          
    time_taken_secs = Column(Integer, nullable=True)
    attempts        = Column(Integer, default=0)
    answer_given    = Column(Text, nullable=True)         
    is_correct      = Column(Boolean, nullable=True)

    session_data    = Column(JSON, default=dict)

    started_at   = Column(DateTime(timezone=True), server_default=func.now())
    completed_at = Column(DateTime(timezone=True), nullable=True)

    game  = relationship("Game", back_populates="sessions")
    staff = relationship("Staff", foreign_keys=[staff_id])

# ─── Leaderboard ──────────────────────────────────────────────────────────────

class Leaderboard(Base):
    __tablename__ = "leaderboard"

    id = Column(Integer, primary_key=True, index=True)
    staff_id = Column(Integer, ForeignKey("staff.id", ondelete="CASCADE"), nullable=False, unique=True)

    total_score = Column(Integer, default=0)
    games_played = Column(Integer, default=0)
    games_won = Column(Integer, default=0)
    current_streak = Column(Integer, default=0)
    best_streak = Column(Integer, default=0)

    ranking = Column(Integer, nullable=True)  # ✅ already correct

    last_played_at = Column(DateTime(timezone=True), nullable=True)  # ✅ ADD THIS

    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    staff = relationship("Staff", foreign_keys=[staff_id])