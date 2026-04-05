from datetime import date as date_type
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.security import get_current_staff
from app.db.session import get_db
from app.models.staff import Achievement, Expertise, Journal, Patent, Staff
from app.schemas.staff import StaffProfileResponse

router = APIRouter(prefix="/profile", tags=["Profile"])


# ─── NESTED ITEM SCHEMAS (proper validation, not raw dict) ───────────────────

class AchievementIn(BaseModel):
    title: str
    description: Optional[str] = None
    date: Optional[date_type] = None          # parsed from "YYYY-MM-DD"


class PatentIn(BaseModel):
    title: str
    patent_number: Optional[str] = None
    issue_date: Optional[date_type] = None
    description: Optional[str] = None


class JournalIn(BaseModel):
    title: str
    journal_name: Optional[str] = None
    publisher: Optional[str] = None
    publication_date: Optional[date_type] = None
    doi: Optional[str] = None


class ExpertiseIn(BaseModel):
    subject: str
    proficiency_level: str = "Intermediate"
    years_experience: int = 0


# ─── PROFILE UPDATE SCHEMA ───────────────────────────────────────────────────

class ProfileUpdate(BaseModel):
    # Basic info
    bio: Optional[str] = None
    phone: Optional[str] = None
    full_name: Optional[str] = None
    department: Optional[str] = None
    designation: Optional[str] = None

    # Account settings (Flutter sends these as single-key patches)
    push_notifications_enabled: Optional[bool] = None
    email_notifications_enabled: Optional[bool] = None
    show_availability_to_others: Optional[bool] = None

    # Relational lists — only replaced when present in the payload
    achievements: Optional[List[AchievementIn]] = None
    patents: Optional[List[PatentIn]] = None
    journals: Optional[List[JournalIn]] = None
    expertises: Optional[List[ExpertiseIn]] = None


# ─── GET PROFILE ─────────────────────────────────────────────────────────────

@router.get("/me", response_model=StaffProfileResponse)
async def get_my_profile(
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """
    Return the authenticated staff member's full profile including
    all nested relationships (achievements, patents, journals, expertises).
    Uses selectinload so relations are always fresh on every request.
    """
    result = await db.execute(
        select(Staff)
        .where(Staff.id == current_staff.id)
        .options(
            selectinload(Staff.achievements),
            selectinload(Staff.patents),
            selectinload(Staff.journals),
            selectinload(Staff.expertises),
        )
    )
    staff = result.scalar_one_or_none()
    if staff is None:
        raise HTTPException(status_code=404, detail="Staff not found")
    return staff


# ─── PATCH PROFILE ───────────────────────────────────────────────────────────

@router.patch("/me", response_model=StaffProfileResponse)
async def update_my_profile(
    payload: ProfileUpdate,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """
    Partial update for the authenticated staff member.

    - Scalar fields are only written when present in the request body.
    - Relational lists perform a full replace (delete-all → insert-new)
      only when the key is present. Omitting the key leaves existing rows
      untouched.
    - After commit, the staff row is refreshed with fresh selectinload so
      the response always reflects the newly written data.
    """
    data = payload.model_dump(exclude_unset=True)

    # ── 1. Scalar fields ──────────────────────────────────────────────────
    scalar_fields = [
        "bio", "phone", "full_name", "department", "designation",
        "push_notifications_enabled",
        "email_notifications_enabled",
        "show_availability_to_others",
    ]
    for field in scalar_fields:
        if field in data:
            setattr(current_staff, field, data[field])

    # ── 2. Achievements ───────────────────────────────────────────────────
    if payload.achievements is not None:
        await db.execute(
            delete(Achievement).where(Achievement.staff_id == current_staff.id)
        )
        for item in payload.achievements:
            db.add(Achievement(
                staff_id=current_staff.id,
                title=item.title,
                description=item.description,
                date=item.date,          # already a date_type | None
            ))

    # ── 3. Patents ────────────────────────────────────────────────────────
    if payload.patents is not None:
        await db.execute(
            delete(Patent).where(Patent.staff_id == current_staff.id)
        )
        for item in payload.patents:
            db.add(Patent(
                staff_id=current_staff.id,
                title=item.title,
                patent_number=item.patent_number,
                issue_date=item.issue_date,
                description=item.description,
            ))

    # ── 4. Journals ───────────────────────────────────────────────────────
    if payload.journals is not None:
        await db.execute(
            delete(Journal).where(Journal.staff_id == current_staff.id)
        )
        for item in payload.journals:
            db.add(Journal(
                staff_id=current_staff.id,
                title=item.title,
                journal_name=item.journal_name,
                publisher=item.publisher,
                publication_date=item.publication_date,
                doi=item.doi,
            ))

    # ── 5. Expertises ─────────────────────────────────────────────────────
    if payload.expertises is not None:
        await db.execute(
            delete(Expertise).where(Expertise.staff_id == current_staff.id)
        )
        for item in payload.expertises:
            db.add(Expertise(
                staff_id=current_staff.id,
                subject=item.subject,
                proficiency_level=item.proficiency_level,
                years_experience=item.years_experience,
            ))

    # ── 6. Commit & refresh ───────────────────────────────────────────────
    try:
        await db.commit()
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

    # Re-query with selectinload so the response contains fresh rows.
    # db.refresh() alone does NOT reload selectin relationships after a
    # manual delete()+add() in the same session.
    result = await db.execute(
        select(Staff)
        .where(Staff.id == current_staff.id)
        .options(
            selectinload(Staff.achievements),
            selectinload(Staff.patents),
            selectinload(Staff.journals),
            selectinload(Staff.expertises),
        )
    )
    updated_staff = result.scalar_one()
    return updated_staff