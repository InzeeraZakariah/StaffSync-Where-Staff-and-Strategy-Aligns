from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

from app.models.reminder import ReminderType, ReminderStatus


# ─── Create Reminder ──────────────────────────────────────────────────────────

class ReminderCreateRequest(BaseModel):
    title: str = Field(..., min_length=2, max_length=200)
    body: Optional[str] = Field(None, max_length=500)
    reason: Optional[str] = Field(None, max_length=300)
    remind_at: datetime
    meeting_id: Optional[int] = None


# ─── Update Reminder ──────────────────────────────────────────────────────────

class ReminderUpdateRequest(BaseModel):
    title: Optional[str] = Field(None, min_length=2, max_length=200)
    body: Optional[str] = None
    reason: Optional[str] = None
    remind_at: Optional[datetime] = None


# ─── Reminder Response ────────────────────────────────────────────────────────

class ReminderResponse(BaseModel):
    id: int
    staff_id: int
    meeting_id: Optional[int]
    title: str
    body: Optional[str]
    reason: Optional[str]
    reminder_type: ReminderType
    status: ReminderStatus
    remind_at: datetime
    is_ai_generated: bool
    is_read: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# ─── Urgent Notify ────────────────────────────────────────────────────────────

class UrgentNotifyRequest(BaseModel):
    title: str = Field(..., min_length=3, max_length=200)
    message: str = Field(..., min_length=5, max_length=1000)
    location: Optional[str] = Field(None, max_length=300)
    department: Optional[str] = None    # None = send to ALL staff


class UrgentNotifyResponse(BaseModel):
    id: int
    sent_by: Optional[int]
    title: str
    message: str
    location: Optional[str]
    total_recipients: int
    successful_sends: int
    created_at: datetime

    model_config = {"from_attributes": True}


# ─── AI Meeting Reminder (internal) ──────────────────────────────────────────

class AIReminderCreateRequest(BaseModel):
    meeting_id: int
    staff_id: int
    meeting_title: str
    scheduled_at: datetime
    platform: str


class MessageResponse(BaseModel):
    message: str