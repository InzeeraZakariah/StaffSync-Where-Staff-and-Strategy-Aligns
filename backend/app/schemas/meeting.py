from pydantic import BaseModel, Field, HttpUrl
from typing import Optional, List
from datetime import datetime

from app.models.meeting import MeetingPlatform, MeetingStatus, AttendeeStatus


# ─── Create Meeting ───────────────────────────────────────────────────────────

class MeetingCreateRequest(BaseModel):
    title: str = Field(..., min_length=3, max_length=200)
    description: Optional[str] = Field(None, max_length=1000)
    platform: MeetingPlatform
    meeting_link: str = Field(..., min_length=5, max_length=500)
    meeting_id_external: Optional[str] = Field(None, max_length=200)
    passcode: Optional[str] = Field(None, max_length=100)
    scheduled_at: datetime
    duration_minutes: int = Field(default=60, ge=15, le=480)
    attendee_ids: List[int] = Field(default_factory=list)
    shared_to_group_id: Optional[int] = None
    bot_enabled: bool = True


# ─── Update Meeting ───────────────────────────────────────────────────────────

class MeetingUpdateRequest(BaseModel):
    title: Optional[str] = Field(None, min_length=3, max_length=200)
    description: Optional[str] = None
    meeting_link: Optional[str] = Field(None, max_length=500)
    scheduled_at: Optional[datetime] = None
    duration_minutes: Optional[int] = Field(None, ge=15, le=480)
    status: Optional[MeetingStatus] = None
    bot_enabled: Optional[bool] = None


# ─── Attendee Response ────────────────────────────────────────────────────────

class AttendeeResponse(BaseModel):
    id: int
    full_name: str
    department: str
    avatar_url: Optional[str]
    status: AttendeeStatus
    bot_attending: bool

    model_config = {"from_attributes": True}


# ─── Meeting Response ─────────────────────────────────────────────────────────

class MeetingResponse(BaseModel):
    id: int
    title: str
    description: Optional[str]
    platform: MeetingPlatform
    meeting_link: str
    meeting_id_external: Optional[str]
    passcode: Optional[str]
    scheduled_at: datetime
    duration_minutes: int
    status: MeetingStatus
    created_by: Optional[int]
    shared_to_group_id: Optional[int]
    bot_enabled: bool
    bot_joined: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class MeetingDetailResponse(MeetingResponse):
    attendees: List[dict]
    summary: Optional["MeetingSummaryResponse"] = None
    bot_profile: Optional["BotProfileResponse"] = None


# ─── Meeting Summary ──────────────────────────────────────────────────────────

class MeetingSummaryResponse(BaseModel):
    id: int
    meeting_id: int
    summary: str
    key_points: Optional[List[str]]
    action_items: Optional[List[str]]
    generated_by_ai: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# ─── Bot Profile ──────────────────────────────────────────────────────────────

class BotProfileCreateRequest(BaseModel):
    bot_name: str = Field(..., min_length=2, max_length=100)
    bot_persona: Optional[str] = Field(None, max_length=500)
    auto_join: bool = True
    notify_after_summary: bool = True


class BotProfileResponse(BaseModel):
    id: int
    meeting_id: int
    staff_id: int
    bot_name: str
    bot_persona: Optional[str]
    auto_join: bool
    notify_after_summary: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# ─── AI Summary Generation Request ───────────────────────────────────────────

class GenerateSummaryRequest(BaseModel):
    transcript: str = Field(..., min_length=10)
    meeting_title: Optional[str] = None


# ─── Share to Group ───────────────────────────────────────────────────────────

class ShareMeetingToGroupRequest(BaseModel):
    group_id: int


# ─── Attendee Status Update ───────────────────────────────────────────────────

class UpdateAttendeeStatusRequest(BaseModel):
    status: AttendeeStatus


class MessageResponse(BaseModel):
    message: str


MeetingDetailResponse.model_rebuild()