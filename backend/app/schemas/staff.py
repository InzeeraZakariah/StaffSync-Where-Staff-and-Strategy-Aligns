from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional, List
from datetime import datetime, date

from app.models.staff import Department, Designation, ProficiencyLevel


# ─── REGISTER ─────────────────────────────────────────

class StaffRegisterRequest(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=150)
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=64)
    phone: Optional[str] = Field(None, max_length=20)
    department: Department
    designation: Designation
    employee_id: Optional[str] = Field(None, max_length=50)

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if not any(c.isupper() for c in v):
            raise ValueError("Password must contain uppercase letter")
        if not any(c.isdigit() for c in v):
            raise ValueError("Password must contain digit")
        return v


# ─── LOGIN ────────────────────────────────────────────

class StaffLoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshTokenRequest(BaseModel):
    refresh_token: str


# ─── ACHIEVEMENTS ─────────────────────────────────────

class AchievementBase(BaseModel):
    title: str
    description: Optional[str] = None
    date: Optional[datetime] = None


class AchievementCreate(AchievementBase):
    pass


class AchievementResponse(AchievementBase):
    id: int
    staff_id: int

    model_config = {"from_attributes": True}


# ─── PATENTS ──────────────────────────────────────────

class PatentBase(BaseModel):
    title: str
    patent_number: Optional[str] = None
    issue_date: Optional[date] = None
    description: Optional[str] = None


class PatentCreate(PatentBase):
    pass


class PatentResponse(PatentBase):
    id: int
    staff_id: int

    model_config = {"from_attributes": True}


# ─── JOURNALS ─────────────────────────────────────────

class JournalBase(BaseModel):
    title: str
    journal_name: Optional[str] = None
    publisher: Optional[str] = None
    publication_date: Optional[date] = None
    doi: Optional[str] = None


class JournalCreate(JournalBase):
    pass


class JournalResponse(JournalBase):
    id: int
    staff_id: int

    model_config = {"from_attributes": True}


# ─── EXPERTISE ────────────────────────────────────────

class ExpertiseBase(BaseModel):
    subject: str
    proficiency_level: ProficiencyLevel = ProficiencyLevel.INTERMEDIATE
    years_experience: int = 0


class ExpertiseCreate(ExpertiseBase):
    pass


class ExpertiseResponse(ExpertiseBase):
    id: int
    staff_id: int

    model_config = {"from_attributes": True}


# ─── PROFILE RESPONSE (UPDATED) ───────────────────────

class StaffProfileResponse(BaseModel):
    id: int
    full_name: str
    email: str
    phone: Optional[str]
    department: Department
    designation: Designation
    employee_id: Optional[str]
    bio: Optional[str]
    avatar_url: Optional[str]
    date_of_joining: Optional[datetime]

    is_active: bool
    is_admin: bool

    push_notifications_enabled: bool
    email_notifications_enabled: bool
    show_availability_to_others: bool

    created_at: datetime
    last_login_at: Optional[datetime]

    # 🔥 NEW LINKEDIN-STYLE DATA
    achievements: List[AchievementResponse] = []
    patents: List[PatentResponse] = []
    journals: List[JournalResponse] = []
    expertises: List[ExpertiseResponse] = []

    model_config = {"from_attributes": True}


# ─── UPDATE PROFILE ───────────────────────────────────

class StaffUpdateProfileRequest(BaseModel):
    full_name: Optional[str] = Field(None, min_length=2, max_length=150)
    phone: Optional[str] = Field(None, max_length=20)
    bio: Optional[str] = Field(None, max_length=500)
    department: Optional[Department] = None
    designation: Optional[Designation] = None
    date_of_joining: Optional[datetime] = None


# ─── ACCOUNT SETTINGS ─────────────────────────────────

class AccountSettingsUpdateRequest(BaseModel):
    push_notifications_enabled: Optional[bool] = None
    email_notifications_enabled: Optional[bool] = None
    show_availability_to_others: Optional[bool] = None


# ─── CHANGE PASSWORD ──────────────────────────────────

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=8, max_length=64)

    @field_validator("new_password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if not any(c.isupper() for c in v):
            raise ValueError("Password must contain uppercase letter")
        if not any(c.isdigit() for c in v):
            raise ValueError("Password must contain digit")
        return v


# ─── GENERIC RESPONSE ─────────────────────────────────

class MessageResponse(BaseModel):
    message: str
