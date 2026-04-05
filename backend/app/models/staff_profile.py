from sqlalchemy import (
    Column, Integer, String, Boolean, DateTime, ForeignKey, Text, JSON
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.db.session import Base


class StaffProfile(Base):

    __tablename__ = "staff_profiles"
    id             = Column(Integer, primary_key=True, index=True)
    staff_id       = Column(Integer, ForeignKey("staff.id", ondelete="CASCADE"),
                           nullable=False, unique=True)

    headline       = Column(String(300), nullable=True)
    about          = Column(Text, nullable=True)
    # Long-form description like LinkedIn summary

    # Contact
    linkedin_url   = Column(String(500), nullable=True)
    personal_website = Column(String(500), nullable=True)
    office_location  = Column(String(200), nullable=True)

    # Achievements stored as JSON list
    # [{ title, issuer, date, description, icon }]
    achievements   = Column(JSON, default=list)

    # Research / Publications
    # [{ title, journal, year, url }]
    publications   = Column(JSON, default=list)

    # Skills
    # ["Python", "Machine Learning", "Data Science"]
    skills         = Column(JSON, default=list)

    # Education
    # [{ degree, institution, year, field }]
    education      = Column(JSON, default=list)

    # Experience (before joining college)
    # [{ role, organization, from_year, to_year, description }]
    experience     = Column(JSON, default=list)

    # Awards
    # [{ title, year, description }]
    awards         = Column(JSON, default=list)

    created_at     = Column(DateTime(timezone=True), server_default=func.now())
    updated_at     = Column(DateTime(timezone=True),
                           server_default=func.now(), onupdate=func.now())

    staff          = relationship("Staff", foreign_keys=[staff_id])

