# app/schemas/student.py  — add Google Form fields to StudentListCreate/Update/Response

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import date, datetime


class SemesterGPAIn(BaseModel):
    semester_number: int = Field(..., ge=1, le=20)
    gpa: float = Field(..., ge=0.0, le=10.0)

class SemesterGPAOut(SemesterGPAIn):
    id: int
    model_config = {"from_attributes": True}


class PatentOut(BaseModel):
    id: int
    title: str
    application_number: Optional[str]
    model_config = {"from_attributes": True}


class JournalOut(BaseModel):
    id: int
    title: str
    journal_name: Optional[str]
    publish_date: Optional[date]
    model_config = {"from_attributes": True}


class ConferenceOut(BaseModel):
    id: int
    conference_name: str
    paper_title: Optional[str]
    attended_date: Optional[date]
    location: Optional[str]
    model_config = {"from_attributes": True}


class StudentProfileResponse(BaseModel):
    id: int
    student_id: int
    overall_cgpa: Optional[float]
    submission_count: int
    last_submitted_at: Optional[datetime]
    semesters:   List[SemesterGPAOut] = []
    patents:     List[PatentOut]      = []
    journals:    List[JournalOut]     = []
    conferences: List[ConferenceOut]  = []
    model_config = {"from_attributes": True}


class StudentAdd(BaseModel):
    student_name:    str = Field(..., min_length=2, max_length=150)
    register_number: str = Field(..., min_length=1, max_length=50)
    email:           Optional[str] = None


class StudentResponse(BaseModel):
    id:                        int
    list_id:                   int
    student_name:              str
    register_number:           str
    email:                     Optional[str]
    missed_updates_this_month: int
    last_updated_at:           Optional[datetime]
    created_at:                datetime
    profile:                   Optional[StudentProfileResponse] = None
    model_config = {"from_attributes": True}


# ── Student List ──────────────────────────────────────────────────────────────

class StudentListCreate(BaseModel):
    name:           str = Field(..., min_length=2, max_length=200)
    description:    Optional[str] = None
    # Google Form integration — staff pastes these after creating the form
    google_form_url: Optional[str] = None
    google_sheet_id: Optional[str] = None
    sheet_tab_name:  Optional[str] = "Form Responses 1"


class StudentListUpdate(BaseModel):
    name:            Optional[str] = Field(None, min_length=2, max_length=200)
    description:     Optional[str] = None
    is_active:       Optional[bool] = None
    google_form_url: Optional[str] = None
    google_sheet_id: Optional[str] = None
    sheet_tab_name:  Optional[str] = None


class StudentListResponse(BaseModel):
    id:              int
    name:            str
    description:     Optional[str]
    token:           str
    is_active:       bool
    created_at:      datetime
    total_students:  int = 0
    alert_count:     int = 0
    # Google Form fields shown in UI
    google_form_url: Optional[str] = None
    google_sheet_id: Optional[str] = None
    sheet_tab_name:  Optional[str] = None
    model_config = {"from_attributes": True}


# ── Sync result ───────────────────────────────────────────────────────────────

class SyncResult(BaseModel):
    synced:  int
    skipped: int
    errors:  List[str] = []
    message: str


# ── Rankings ─────────────────────────────────────────────────────────────────

class RankedStudent(BaseModel):
    rank:             int
    student_id:       int
    student_name:     str
    register_number:  str
    overall_cgpa:     Optional[float]
    highest_sem_gpa:  Optional[float]
    patent_count:     int
    journal_count:    int
    conference_count: int
    activity_score:   float


class StudentSummaryResponse(BaseModel):
    list_id:        int
    list_name:      str
    total_students: int
    submitted:      int
    alert_students: int
    top_cgpa:       List[RankedStudent]
    top_activity:   List[RankedStudent]
    generated_at:   datetime