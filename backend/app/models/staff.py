# models/staff.py 
from sqlalchemy import (
    Column, Integer, String, Boolean, DateTime,
    Enum, Text, ForeignKey, Date
)
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
import enum

from app.db.session import Base


# ─── ENUMS ──────────────────────────────────────

class Department(str, enum.Enum):
    CSE = "CSE"
    IT = "IT"
    ECE = "ECE"
    EEE = "EEE"
    MECH = "MECH"
    CIVIL = "CIVIL"
    MBA = "MBA"
    MCA = "MCA"
    ADMIN = "ADMIN"
    OTHER = "OTHER"


class Designation(str, enum.Enum):
    PROFESSOR = "Professor"
    ASSOCIATE_PROFESSOR = "Associate Professor"
    ASSISTANT_PROFESSOR = "Assistant Professor"
    HOD = "Head of Department"
    PRINCIPAL = "Principal"
    LAB_INSTRUCTOR = "Lab Instructor"
    ADMIN_STAFF = "Admin Staff"
    OTHER = "Other"


class ProficiencyLevel(str, enum.Enum):
    BEGINNER = "Beginner"
    INTERMEDIATE = "Intermediate"
    ADVANCED = "Advanced"
    EXPERT = "Expert"


# ─── STAFF MODEL ──────────────────────────────────────

class Staff(Base):
    __tablename__ = "staff"

    id = Column(Integer, primary_key=True, index=True)

    full_name = Column(String(150), nullable=False)
    email = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)

    phone = Column(String(20))
    department = Column(Enum(Department), nullable=False)
    designation = Column(Enum(Designation), nullable=False)

    employee_id = Column(String(50), unique=True, index=True)
    bio = Column(Text)
    avatar_url = Column(String(500))
    date_of_joining = Column(DateTime)

    # ─── ACCOUNT SETTINGS ─────────────────────────────
    is_active = Column(Boolean, default=True, nullable=False)
    is_admin = Column(Boolean, default=False, nullable=False)

    push_notifications_enabled = Column(Boolean, default=True, nullable=False)
    email_notifications_enabled = Column(Boolean, default=True, nullable=False)
    show_availability_to_others = Column(Boolean, default=True, nullable=False)

    # ─── TIMESTAMPS ───────────────────────────────────
    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False
    )

    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False
    )

    last_login_at = Column(DateTime(timezone=True))

    # ─── RELATIONSHIPS (OPTIMIZED) ─────────────────────
    achievements = relationship(
        "Achievement",
        back_populates="staff",
        cascade="all, delete-orphan",
        lazy="selectin"
    )

    patents = relationship(
        "Patent",
        back_populates="staff",
        cascade="all, delete-orphan",
        lazy="selectin"
    )

    journals = relationship(
        "Journal",
        back_populates="staff",
        cascade="all, delete-orphan",
        lazy="selectin"
    )

    expertises = relationship(
        "Expertise",
        back_populates="staff",
        cascade="all, delete-orphan",
        lazy="selectin"
    )


# ─── ACHIEVEMENT ─────────────────────────────────────

class Achievement(Base):
    __tablename__ = "achievements"

    id = Column(Integer, primary_key=True, index=True)
    staff_id = Column(
        Integer,
        ForeignKey("staff.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    title = Column(String(200), nullable=False)
    description = Column(Text)
    date = Column(Date)

    staff = relationship("Staff", back_populates="achievements")


# ─── PATENT ──────────────────────────────────────────

class Patent(Base):
    __tablename__ = "patents"

    id = Column(Integer, primary_key=True, index=True)
    staff_id = Column(
        Integer,
        ForeignKey("staff.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    title = Column(String(200), nullable=False)
    patent_number = Column(String(100))
    issue_date = Column(Date)
    description = Column(Text)

    staff = relationship("Staff", back_populates="patents")


# ─── JOURNAL ─────────────────────────────────────────

class Journal(Base):
    __tablename__ = "journals"

    id = Column(Integer, primary_key=True, index=True)
    staff_id = Column(
        Integer,
        ForeignKey("staff.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    title = Column(String(200), nullable=False)
    journal_name = Column(String(150))
    publisher = Column(String(150))
    publication_date = Column(Date)
    doi = Column(String(100))

    staff = relationship("Staff", back_populates="journals")


# ─── EXPERTISE ───────────────────────────────────────

class Expertise(Base):
    __tablename__ = "expertises"

    id = Column(Integer, primary_key=True, index=True)
    staff_id = Column(
        Integer,
        ForeignKey("staff.id", ondelete="CASCADE"),
        nullable=False,
        index=True
    )

    subject = Column(String(100), nullable=False)
    proficiency_level = Column(
        Enum(ProficiencyLevel),
        default=ProficiencyLevel.INTERMEDIATE,
        nullable=False
    )
    years_experience = Column(Integer, default=0, nullable=False)

    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False
    )

    staff = relationship("Staff", back_populates="expertises")
