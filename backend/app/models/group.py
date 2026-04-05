from sqlalchemy import (
    Column, Integer, String, Boolean, DateTime, ForeignKey,
    Text, Enum, Table
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum

from app.db.session import Base

from fastapi import APIRouter, WebSocket

routers =  APIRouter(prefix="/api/v1/groups", tags=["groups"])

@routers.websocket("/{group_id}/ws")
async def group_ws(websocket: WebSocket, group_id:int):
    await websocket.accept()
    await websocket.send_text(f"Connected to group {group_id}")
    while True:
        data = await websocket.receive_text()
        await websocket.send_text(f"Echo from group {group_id}: {data}")

class MessageType(str, enum.Enum):
    TEXT = "text"
    IMAGE = "image"
    FILE = "file"
    MEETING_INVITE = "meeting_invite"
    SYSTEM = "system"


# ─── Association table: group members ─────────────────────────────────────────

group_members = Table(
    "group_members",
    Base.metadata,
    Column("group_id", Integer, ForeignKey("groups.id", ondelete="CASCADE"), primary_key=True),
    Column("staff_id", Integer, ForeignKey("staff.id", ondelete="CASCADE"), primary_key=True),
    Column("joined_at", DateTime(timezone=True), server_default=func.now()),
    Column("is_admin", Boolean, default=False),
)


# ─── Group ────────────────────────────────────────────────────────────────────

class Group(Base):
    __tablename__ = "groups"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(150), nullable=False)
    description = Column(Text, nullable=True)
    department = Column(String(50), nullable=True)  
    created_by = Column(Integer, ForeignKey("staff.id", ondelete="SET NULL"), nullable=True)
    is_active = Column(Boolean, default=True)
    avatar_url = Column(String(500), nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationships
    messages = relationship("Message", back_populates="group", cascade="all, delete-orphan")
    members = relationship("Staff", secondary=group_members, backref="groups")
    creator = relationship("Staff", foreign_keys=[created_by])


# ─── Message ──────────────────────────────────────────────────────────────────

class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    group_id = Column(Integer, ForeignKey("groups.id", ondelete="CASCADE"), nullable=False, index=True)
    sender_id = Column(Integer, ForeignKey("staff.id", ondelete="SET NULL"), nullable=True)
    message_type = Column(Enum(MessageType), default=MessageType.TEXT, nullable=False)
    content = Column(Text, nullable=True)           # text content or caption
    file_url = Column(String(500), nullable=True)   # for image/file messages
    file_name = Column(String(255), nullable=True)
    is_deleted = Column(Boolean, default=False)
    reply_to_id = Column(Integer, ForeignKey("messages.id", ondelete="SET NULL"), nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    group = relationship("Group", back_populates="messages")
    sender = relationship("Staff", foreign_keys=[sender_id])
    reply_to = relationship("Message", remote_side=[id])


# ─── Message Read Receipt ─────────────────────────────────────────────────────

class MessageReadReceipt(Base):
    __tablename__ = "message_read_receipts"

    id = Column(Integer, primary_key=True, index=True)
    message_id = Column(Integer, ForeignKey("messages.id", ondelete="CASCADE"), nullable=False)
    staff_id = Column(Integer, ForeignKey("staff.id", ondelete="CASCADE"), nullable=False)
    read_at = Column(DateTime(timezone=True), server_default=func.now())