from pydantic import BaseModel, Field
from typing import Optional, List, Any, Dict
from datetime import datetime
from app.models.game import GameType, GameDifficulty, GameSessionStatus, GameCategory


# ─── Game ─────────────────────────────────────────────────────────────────────

class GameOut(BaseModel):
    id:          int
    game_type:   GameType
    difficulty:  GameDifficulty
    category:    GameCategory
    title:       str
    description: Optional[str]    = None
    is_active:   bool
    is_daily:    bool
    play_count:  int               = 0
    base_points: int               = 10
    payload:     Dict[str, Any]    = {}
    created_at:  Optional[datetime] = None

    model_config = {"from_attributes": True}


class GameListOut(BaseModel):
    id:          int
    game_type:   GameType
    difficulty:  GameDifficulty
    category:    GameCategory
    title:       str
    description: Optional[str] = None
    is_daily:    bool
    play_count:  int           = 0
    base_points: int           = 10

    model_config = {"from_attributes": True}


# ─── Session ──────────────────────────────────────────────────────────────────

class StartSessionOut(BaseModel):
    session_id:  int
    game_id:     int
    game_type:   str
    title:       str
    difficulty:  str
    category:    str
    payload:     Dict[str, Any]
    base_points: int
    started_at:  Optional[datetime] = None

    model_config = {"from_attributes": True}


class SubmitAnswerRequest(BaseModel):
    answer:         Any
    time_taken_secs: Optional[int] = None


class SubmitAnswerOut(BaseModel):
    is_correct:     bool
    score:          int
    correct_answer: Any
    explanation:    Optional[str] = None
    session_id:     int
    total_score:    int

    model_config = {"from_attributes": True}


class GameSessionOut(BaseModel):
    id:             int
    game_id:        int
    status:         GameSessionStatus
    score:          int
    time_taken_secs: Optional[int]  = None
    attempts:       int
    is_correct:     Optional[bool]  = None
    started_at:     Optional[datetime] = None
    completed_at:   Optional[datetime] = None

    model_config = {"from_attributes": True}


# ─── Leaderboard ──────────────────────────────────────────────────────────────

class LeaderboardEntryOut(BaseModel):
    rank:           int
    staff_id:       int
    full_name:      str
    department:     str
    avatar_url:     Optional[str] = None
    total_score:    int
    games_played:   int
    games_won:      int
    current_streak: int
    best_streak:    int

    model_config = {"from_attributes": True}


# ─── AI Generate ──────────────────────────────────────────────────────────────

class AIGenerateRequest(BaseModel):
    game_type:  GameType       = GameType.QUIZ
    difficulty: GameDifficulty = GameDifficulty.MEDIUM
    category:   GameCategory   = GameCategory.GENERAL
    count:      int            = Field(default=1, ge=1, le=5)


class MessageResponse(BaseModel):
    message: str