from sqlalchemy import (
    Column, Integer, String, Boolean, DateTime, ForeignKey,
    Enum, Text
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum

from app.db.session import Base


class ReminderType(str, enum.Enum):
    MEETING = "meeting"          # auto-created by system before a meeting
    CUSTOM = "custom"            # manually created by staff
    URGENT = "urgent"            # urgent notify sent to all staff


class ReminderStatus(str, enum.Enum):
    PENDING = "pending"
    SENT = "sent"
    FAILED = "failed"
    DISMISSED = "dismissed"


class Reminder(Base):
    __tablename__ = "reminders"

    id = Column(Integer, primary_key=True, index=True)
    staff_id = Column(Integer, ForeignKey("staff.id", ondelete="CASCADE"), nullable=False, index=True)
    meeting_id = Column(Integer, ForeignKey("meetings.id", ondelete="CASCADE"), nullable=True)

    title = Column(String(200), nullable=False)
    body = Column(Text, nullable=True)
    reason = Column(Text, nullable=True)
    reminder_type = Column(Enum(ReminderType), nullable=False, default=ReminderType.CUSTOM)
    status = Column(Enum(ReminderStatus), nullable=False, default=ReminderStatus.PENDING)

    remind_at = Column(DateTime(timezone=True), nullable=False)
    is_ai_generated = Column(Boolean, default=False)
    is_read = Column(Boolean, default=False)

    created_by = Column(Integer, ForeignKey("staff.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    staff = relationship("Staff", foreign_keys=[staff_id])
    creator = relationship("Staff", foreign_keys=[created_by])
    meeting = relationship("Meeting", foreign_keys=[meeting_id])


class UrgentNotification(Base):
    __tablename__ = "urgent_notifications"

    id = Column(Integer, primary_key=True, index=True)
    sent_by = Column(Integer, ForeignKey("staff.id", ondelete="SET NULL"), nullable=True)
    title = Column(String(200), nullable=False)
    message = Column(Text, nullable=False)
    location = Column(String(300), nullable=True)    # optional meeting location
    total_recipients = Column(Integer, default=0)
    successful_sends = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    sender = relationship("Staff", foreign_keys=[sent_by])