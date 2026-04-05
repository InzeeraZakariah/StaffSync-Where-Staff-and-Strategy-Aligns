from sqlalchemy import (
    Column, Integer, String, Boolean, DateTime, ForeignKey,
    Enum, Text, Table
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum

from app.db.session import Base


class MeetingPlatform(str, enum.Enum):
    ZOOM = "zoom"
    GOOGLE_MEET = "google_meet"
    MS_TEAMS = "ms_teams"
    OTHER = "other"


class MeetingStatus(str, enum.Enum):
    SCHEDULED = "scheduled"
    ONGOING = "ongoing"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class AttendeeStatus(str, enum.Enum):
    INVITED = "invited"
    ACCEPTED = "accepted"
    DECLINED = "declined"
    BOT_ATTENDING = "bot_attending"


# ─── Association: meeting attendees ──────────────────────────────────────────

meeting_attendees = Table(
    "meeting_attendees",
    Base.metadata,
    Column("meeting_id", Integer, ForeignKey("meetings.id", ondelete="CASCADE"), primary_key=True),
    Column("staff_id", Integer, ForeignKey("staff.id", ondelete="CASCADE"), primary_key=True),
    Column("status", Enum(AttendeeStatus), default=AttendeeStatus.INVITED),
    Column("bot_attending", Boolean, default=False),
    Column("joined_at", DateTime(timezone=True), nullable=True),
)


# ─── Meeting ─────────────────────────────────────────────────────────────────

class Meeting(Base):
    __tablename__ = "meetings"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    platform = Column(Enum(MeetingPlatform), nullable=False)
    meeting_link = Column(String(500), nullable=False)
    meeting_id_external = Column(String(200), nullable=True)
    passcode = Column(String(100), nullable=True)

    scheduled_at = Column(DateTime(timezone=True), nullable=False)
    duration_minutes = Column(Integer, default=60)
    status = Column(Enum(MeetingStatus), default=MeetingStatus.SCHEDULED)

    created_by = Column(Integer, ForeignKey("staff.id", ondelete="SET NULL"), nullable=True)
    shared_to_group_id = Column(Integer, ForeignKey("groups.id", ondelete="SET NULL"), nullable=True)

    # AI Bot fields
    bot_enabled = Column(Boolean, default=True)
    bot_joined = Column(Boolean, default=False)
    bot_join_time = Column(DateTime(timezone=True), nullable=True)
    # recall_bot_id removed — using Fireflies directly, no Recall.ai

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationships
    creator = relationship("Staff", foreign_keys=[created_by])
    attendees = relationship("Staff", secondary=meeting_attendees, backref="meetings")
    summary = relationship("MeetingSummary", back_populates="meeting", uselist=False)
    bot_profile = relationship("MeetingBotProfile", back_populates="meeting", uselist=False)


# ─── Meeting Summary (AI Generated) ──────────────────────────────────────────

class MeetingSummary(Base):
    __tablename__ = "meeting_summaries"

    id = Column(Integer, primary_key=True, index=True)
    meeting_id = Column(Integer, ForeignKey("meetings.id", ondelete="CASCADE"), nullable=False, unique=True)
    transcript = Column(Text, nullable=True)
    summary = Column(Text, nullable=False)
    key_points = Column(Text, nullable=True)       # JSON string list
    action_items = Column(Text, nullable=True)     # JSON string list
    generated_by_ai = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    meeting = relationship("Meeting", back_populates="summary")


# ─── Meeting Bot Profile ──────────────────────────────────────────────────────

class MeetingBotProfile(Base):
    __tablename__ = "meeting_bot_profiles"

    id = Column(Integer, primary_key=True, index=True)
    meeting_id = Column(Integer, ForeignKey("meetings.id", ondelete="CASCADE"), nullable=False, unique=True)
    staff_id = Column(Integer, ForeignKey("staff.id", ondelete="CASCADE"), nullable=False)
    bot_name = Column(String(100), nullable=False)
    bot_persona = Column(Text, nullable=True)
    auto_join = Column(Boolean, default=True)
    notify_after_summary = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    meeting = relationship("Meeting", back_populates="bot_profile")
    staff = relationship("Staff", foreign_keys=[staff_id])