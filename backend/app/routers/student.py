# app/routers/students.py  — key additions: sync endpoint + form URL in list CRUD

from datetime import datetime, timezone
from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.security import get_current_staff
from app.db.session import get_db
from app.models.staff import Staff
from app.models.student import StudentList, Student, StudentProfile
from app.schemas.student import (
    StudentListCreate, StudentListUpdate, StudentListResponse,
    StudentAdd, StudentResponse,
    StudentSummaryResponse, RankedStudent,
    SyncResult,
)
from app.services.sheet_sync_service import sync_sheet_to_db

router = APIRouter(prefix="/students", tags=["Students"])


# ── Helpers ───────────────────────────────────────────────────────────────────

def _list_response(sl: StudentList) -> StudentListResponse:
    alert_count = sum(1 for s in sl.students if s.missed_updates_this_month >= 3)
    return StudentListResponse(
        id=sl.id, name=sl.name, description=sl.description,
        token=sl.token, is_active=sl.is_active, created_at=sl.created_at,
        total_students=len(sl.students), alert_count=alert_count,
        google_form_url=sl.google_form_url,
        google_sheet_id=sl.google_sheet_id,
        sheet_tab_name=sl.sheet_tab_name,
    )


async def _own_list(list_id: int, staff_id: int, db: AsyncSession) -> StudentList:
    r = await db.execute(
        select(StudentList)
        .where(StudentList.id == list_id, StudentList.staff_id == staff_id)
        .options(selectinload(StudentList.students))
    )
    sl = r.scalar_one_or_none()
    if not sl:
        raise HTTPException(404, "Student list not found")
    return sl


def _profile_opts():
    return selectinload(Student.profile).options(
        selectinload(StudentProfile.semesters),
        selectinload(StudentProfile.patents),
        selectinload(StudentProfile.journals),
        selectinload(StudentProfile.conferences),
    )


def _activity_score(p) -> float:
    if p is None: return 0.0
    cgpa = (p.overall_cgpa or 0.0) * 4
    best = max((s.gpa for s in p.semesters), default=0.0) * 2
    return round(cgpa + best + len(p.patents)*10 + len(p.journals)*8 + len(p.conferences)*5, 4)


# ── Lists CRUD ────────────────────────────────────────────────────────────────

@router.get("/lists", response_model=List[StudentListResponse])
async def get_lists(
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    r = await db.execute(
        select(StudentList)
        .where(StudentList.staff_id == current_staff.id)
        .options(selectinload(StudentList.students))
        .order_by(StudentList.created_at.desc())
    )
    return [_list_response(sl) for sl in r.scalars().all()]


@router.post("/lists", response_model=StudentListResponse, status_code=201)
async def create_list(
    payload: StudentListCreate,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    sl = StudentList(
        staff_id=current_staff.id,
        name=payload.name,
        description=payload.description,
        google_form_url=payload.google_form_url,
        google_sheet_id=payload.google_sheet_id,
        sheet_tab_name=payload.sheet_tab_name or "Form Responses 1",
    )
    db.add(sl)
    try:
        await db.commit()
        await db.refresh(sl)
    except Exception as e:
        await db.rollback()
        raise HTTPException(500, f"DB error: {str(e)}")
    r = await db.execute(
        select(StudentList).where(StudentList.id == sl.id)
        .options(selectinload(StudentList.students))
    )
    return _list_response(r.scalar_one())


@router.patch("/lists/{list_id}", response_model=StudentListResponse)
async def update_list(
    list_id: int, payload: StudentListUpdate,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    sl = await _own_list(list_id, current_staff.id, db)
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(sl, k, v)
    await db.commit()
    r = await db.execute(
        select(StudentList).where(StudentList.id == sl.id)
        .options(selectinload(StudentList.students))
    )
    return _list_response(r.scalar_one())


@router.delete("/lists/{list_id}", status_code=204)
async def delete_list(
    list_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    sl = await _own_list(list_id, current_staff.id, db)
    await db.delete(sl)
    await db.commit()


# ── Students in a list ────────────────────────────────────────────────────────

@router.get("/lists/{list_id}/students", response_model=List[StudentResponse])
async def get_students(
    list_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    await _own_list(list_id, current_staff.id, db)
    r = await db.execute(
        select(Student).where(Student.list_id == list_id)
        .options(_profile_opts()).order_by(Student.student_name)
    )
    return r.scalars().all()


@router.post("/lists/{list_id}/students",
             response_model=StudentResponse, status_code=201)
async def add_student(
    list_id: int, payload: StudentAdd,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    await _own_list(list_id, current_staff.id, db)
    dup = await db.execute(
        select(Student).where(
            Student.list_id == list_id,
            Student.register_number == payload.register_number,
        )
    )
    if dup.scalar_one_or_none():
        raise HTTPException(409, "Register number already exists in this list")
    s = Student(list_id=list_id, student_name=payload.student_name,
                register_number=payload.register_number, email=payload.email)
    db.add(s)
    try:
        await db.commit()
        await db.refresh(s)
    except Exception as e:
        await db.rollback()
        raise HTTPException(500, f"DB error: {str(e)}")
    r = await db.execute(
        select(Student).where(Student.id == s.id).options(_profile_opts())
    )
    return r.scalar_one()


@router.delete("/lists/{list_id}/students/{student_id}", status_code=204)
async def remove_student(
    list_id: int, student_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    await _own_list(list_id, current_staff.id, db)
    r = await db.execute(
        select(Student).where(Student.id == student_id, Student.list_id == list_id)
    )
    s = r.scalar_one_or_none()
    if not s: raise HTTPException(404, "Student not found")
    await db.delete(s)
    await db.commit()


# ── SYNC from Google Sheet ────────────────────────────────────────────────────

@router.post("/lists/{list_id}/sync", response_model=SyncResult)
async def sync_from_google_sheet(
    list_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """
    Reads the linked Google Sheet and upserts student profiles.
    Staff taps this button after students have filled the Google Form.
    """
    sl = await _own_list(list_id, current_staff.id, db)

    if not sl.google_sheet_id:
        raise HTTPException(
            400,
            "No Google Sheet ID linked to this list. "
            "Edit the list and paste the Sheet ID first."
        )

    result = await sync_sheet_to_db(sl, db)
    msg = (
        f"Sync complete: {result['synced']} student(s) updated"
        + (f", {result['skipped']} skipped" if result['skipped'] else "")
        + ("." if not result['errors'] else f". {len(result['errors'])} error(s).")
    )
    return SyncResult(**result, message=msg)


# ── Summary / Rankings ────────────────────────────────────────────────────────

@router.get("/lists/{list_id}/summary", response_model=StudentSummaryResponse)
async def get_summary(
    list_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    sl = await _own_list(list_id, current_staff.id, db)
    r = await db.execute(
        select(Student).where(Student.list_id == list_id).options(_profile_opts())
    )
    students  = r.scalars().all()
    submitted = [s for s in students if s.profile is not None]
    alert_ct  = sum(1 for s in students if s.missed_updates_this_month >= 3)

    def ranked(s: Student, rank: int) -> RankedStudent:
        p = s.profile
        return RankedStudent(
            rank=rank, student_id=s.id,
            student_name=s.student_name, register_number=s.register_number,
            overall_cgpa=p.overall_cgpa if p else None,
            highest_sem_gpa=max((x.gpa for x in p.semesters), default=None) if p else None,
            patent_count=len(p.patents) if p else 0,
            journal_count=len(p.journals) if p else 0,
            conference_count=len(p.conferences) if p else 0,
            activity_score=_activity_score(p),
        )

    by_cgpa     = sorted(submitted, key=lambda s: s.profile.overall_cgpa or 0.0, reverse=True)[:3]
    by_activity = sorted(submitted, key=lambda s: _activity_score(s.profile), reverse=True)[:3]

    return StudentSummaryResponse(
        list_id=list_id, list_name=sl.name,
        total_students=len(students), submitted=len(submitted),
        alert_students=alert_ct,
        top_cgpa=[ranked(s, i+1) for i, s in enumerate(by_cgpa)],
        top_activity=[ranked(s, i+1) for i, s in enumerate(by_activity)],
        generated_at=datetime.now(timezone.utc),
    )