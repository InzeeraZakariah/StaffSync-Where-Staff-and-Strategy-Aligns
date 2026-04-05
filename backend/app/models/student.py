# app/models/student.py  — only showing what CHANGES
# Add these two columns to the existing StudentList model

# Inside class StudentList(Base):
#   ... existing columns ...

#   google_form_url = Column(String(500))   # the form link staff shares with students
#   google_sheet_id = Column(String(200))   # the Sheet ID to read responses from
#   sheet_tab_name  = Column(String(100), default="Form Responses 1")  # sheet tab name

# Full updated model below:

import uuid
from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey, Text, Date, UniqueConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.db.session import Base


def _gen_token() -> str:
    return uuid.uuid4().hex


class StudentList(Base):
    __tablename__ = "student_lists"

    id              = Column(Integer, primary_key=True, index=True)
    staff_id        = Column(Integer, ForeignKey("staff.id", ondelete="CASCADE"), nullable=False, index=True)
    name            = Column(String(200), nullable=False)
    description     = Column(Text)
    token           = Column(String(64), unique=True, nullable=False, default=_gen_token)
    is_active       = Column(Boolean, default=True, nullable=False)

    # ── Google Forms integration ───────────────────────────────────────────
    google_form_url = Column(String(500))        # shared with students
    google_sheet_id = Column(String(200))        # from Sheet URL: /d/SHEET_ID/edit
    sheet_tab_name  = Column(String(100), default="Form Responses 1")

    created_at  = Column(DateTime(timezone=True), server_default=func.now())
    updated_at  = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    staff    = relationship("Staff", backref="student_lists")
    students = relationship("Student", back_populates="student_list",
                            cascade="all, delete-orphan", lazy="selectin")


class Student(Base):
    __tablename__ = "students"
    __table_args__ = (UniqueConstraint("list_id", "register_number", name="uq_student_list_regnum"),)

    id                        = Column(Integer, primary_key=True, index=True)
    list_id                   = Column(Integer, ForeignKey("student_lists.id", ondelete="CASCADE"), nullable=False, index=True)
    student_name              = Column(String(150), nullable=False)
    register_number           = Column(String(50), nullable=False)
    email                     = Column(String(255))
    missed_updates_this_month = Column(Integer, default=0, nullable=False)
    last_updated_at           = Column(DateTime(timezone=True))
    created_at                = Column(DateTime(timezone=True), server_default=func.now())

    student_list = relationship("StudentList", back_populates="students")
    profile      = relationship("StudentProfile", back_populates="student",
                                uselist=False, cascade="all, delete-orphan", lazy="selectin")


class StudentProfile(Base):
    __tablename__ = "student_profiles"

    id                = Column(Integer, primary_key=True, index=True)
    student_id        = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)
    overall_cgpa      = Column(Float)
    submission_count  = Column(Integer, default=0, nullable=False)
    last_submitted_at = Column(DateTime(timezone=True))

    student     = relationship("Student", back_populates="profile")
    semesters   = relationship("SemesterGPA",       back_populates="profile", cascade="all, delete-orphan", lazy="selectin", order_by="SemesterGPA.semester_number")
    patents     = relationship("StudentPatent",      back_populates="profile", cascade="all, delete-orphan", lazy="selectin")
    journals    = relationship("StudentJournal",     back_populates="profile", cascade="all, delete-orphan", lazy="selectin")
    conferences = relationship("StudentConference",  back_populates="profile", cascade="all, delete-orphan", lazy="selectin")


class SemesterGPA(Base):
    __tablename__ = "student_semester_gpas"
    __table_args__ = (UniqueConstraint("profile_id", "semester_number", name="uq_profile_semester"),)

    id              = Column(Integer, primary_key=True, index=True)
    profile_id      = Column(Integer, ForeignKey("student_profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    semester_number = Column(Integer, nullable=False)
    gpa             = Column(Float, nullable=False)
    profile         = relationship("StudentProfile", back_populates="semesters")


class StudentPatent(Base):
    __tablename__ = "student_patents"

    id                 = Column(Integer, primary_key=True, index=True)
    profile_id         = Column(Integer, ForeignKey("student_profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    title              = Column(String(300), nullable=False)
    application_number = Column(String(100))
    profile            = relationship("StudentProfile", back_populates="patents")


class StudentJournal(Base):
    __tablename__ = "student_journals"

    id           = Column(Integer, primary_key=True, index=True)
    profile_id   = Column(Integer, ForeignKey("student_profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    title        = Column(String(300), nullable=False)
    journal_name = Column(String(200))
    publish_date = Column(Date)
    profile      = relationship("StudentProfile", back_populates="journals")


class StudentConference(Base):
    __tablename__ = "student_conferences"

    id              = Column(Integer, primary_key=True, index=True)
    profile_id      = Column(Integer, ForeignKey("student_profiles.id", ondelete="CASCADE"), nullable=False, index=True)
    conference_name = Column(String(300), nullable=False)
    paper_title     = Column(String(300))
    attended_date   = Column(Date)
    location        = Column(String(200))
    profile         = relationship("StudentProfile", back_populates="conferences")