from sqlalchemy import (
    Column, Integer, String, Boolean, DateTime, ForeignKey,
    Enum, Text, BigInteger
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum

from app.db.session import Base


# ══════════════════════════════════════════════════════════════════
#   ENUMS
# ══════════════════════════════════════════════════════════════════

class ResourceType(str, enum.Enum):
    PDF      = "pdf"
    PPT      = "ppt"
    IMAGE    = "image"
    VIDEO    = "video"
    LINK     = "link"
    DOCUMENT = "document"


class ResourceVisibility(str, enum.Enum):
    DEPARTMENT = "department"   # visible to a specific department
    ALL_STAFF  = "all_staff"    # visible to all college staff
    PRIVATE    = "private"      # only visible to uploader + explicit shares


# ══════════════════════════════════════════════════════════════════
#   RESOURCE
# ══════════════════════════════════════════════════════════════════

class Resource(Base):
    __tablename__ = "resources"

    id               = Column(Integer, primary_key=True, index=True)
    uploaded_by      = Column(Integer, ForeignKey("staff.id", ondelete="SET NULL"), nullable=True)
    title            = Column(String(250), nullable=False)
    description      = Column(Text, nullable=True)
    resource_type    = Column(Enum(ResourceType), nullable=False)
    visibility       = Column(Enum(ResourceVisibility), nullable=False,
                               default=ResourceVisibility.DEPARTMENT)
    department       = Column(String(50), nullable=True)

    # File fields (PDF / PPT / IMAGE / VIDEO / DOCUMENT)
    file_url         = Column(String(600), nullable=True)
    file_name        = Column(String(300), nullable=True)
    file_size_bytes  = Column(BigInteger, nullable=True)
    mime_type        = Column(String(100), nullable=True)

    # Link field
    link_url         = Column(String(600), nullable=True)

    # Metadata
    download_count   = Column(Integer, default=0)
    is_active        = Column(Boolean, default=True)
    tags             = Column(String(500), nullable=True)   # comma-separated

    created_at       = Column(DateTime(timezone=True), server_default=func.now())
    updated_at       = Column(DateTime(timezone=True), server_default=func.now(),
                               onupdate=func.now())

    uploader         = relationship("Staff", foreign_keys=[uploaded_by])
    shares           = relationship("ResourceShare", back_populates="resource",
                                    cascade="all, delete-orphan")


# ══════════════════════════════════════════════════════════════════
#   RESOURCE SHARE
#   One row per explicit share target (staff member OR group).
# ══════════════════════════════════════════════════════════════════

class ResourceShare(Base):
    __tablename__ = "resource_shares"

    id = Column(Integer, primary_key=True, index=True)
    resource_id  = Column(Integer, ForeignKey("resources.id",  ondelete="CASCADE"),
                                  nullable=False)
    # Exactly one of these two is set per row
    shared_to_staff_id  = Column(Integer, ForeignKey("staff.id",   ondelete="CASCADE"),
                                  nullable=True)
    shared_to_group_id  = Column(Integer, ForeignKey("groups.id",  ondelete="CASCADE"),
                                  nullable=True)

    shared_by           = Column(Integer, ForeignKey("staff.id",   ondelete="SET NULL"),
                                  nullable=True)
    shared_at           = Column(DateTime(timezone=True), server_default=func.now())

    resource            = relationship("Resource",  foreign_keys=[resource_id],
                                        back_populates="shares")
    recipient_staff     = relationship("Staff",     foreign_keys=[shared_to_staff_id])
    shared_by_staff     = relationship("Staff",     foreign_keys=[shared_by])


# ══════════════════════════════════════════════════════════════════
#   NOTE
# ══════════════════════════════════════════════════════════════════

class Note(Base):
    __tablename__ = "notes"

    id             = Column(Integer, primary_key=True, index=True)
    created_by     = Column(Integer, ForeignKey("staff.id", ondelete="SET NULL"), nullable=True)
    title          = Column(String(250), nullable=False)
    content        = Column(Text, nullable=False)
    department     = Column(String(50), nullable=False)
    tags           = Column(String(500), nullable=True)
    is_pinned      = Column(Boolean, default=False)
    is_active      = Column(Boolean, default=True)
    last_edited_by = Column(Integer, ForeignKey("staff.id", ondelete="SET NULL"), nullable=True)

    created_at     = Column(DateTime(timezone=True), server_default=func.now())
    updated_at     = Column(DateTime(timezone=True), server_default=func.now(),
                             onupdate=func.now())

    creator        = relationship("Staff", foreign_keys=[created_by])
    editor         = relationship("Staff", foreign_keys=[last_edited_by])


# ══════════════════════════════════════════════════════════════════
#   NOTE EDIT HISTORY
# ══════════════════════════════════════════════════════════════════

class NoteEditHistory(Base):
    __tablename__ = "note_edit_history"

    id               = Column(Integer, primary_key=True, index=True)
    note_id          = Column(Integer, ForeignKey("notes.id", ondelete="CASCADE"), nullable=False)
    edited_by        = Column(Integer, ForeignKey("staff.id", ondelete="SET NULL"), nullable=True)
    previous_content = Column(Text, nullable=False)
    edited_at        = Column(DateTime(timezone=True), server_default=func.now())

    note             = relationship("Note",  foreign_keys=[note_id])
    editor           = relationship("Staff", foreign_keys=[edited_by])