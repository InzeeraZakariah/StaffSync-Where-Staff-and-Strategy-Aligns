from datetime import datetime, timezone
from typing import List

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, update
from sqlalchemy.orm import selectinload

from app.models.student import StudentList, StudentEntry, StudentPatent, StudentPaper
from app.schemas.student import TopStudentEntry, StudentSummaryResponse


# ─── ACHIEVEMENT SCORE ────────────────────────────────────────────────────────

def _compute_score(entry: StudentEntry) -> float:
    """
    Composite score used to rank 'high achievers'.
    Weights: CGPA 50% + SGPA 30% + patents 5pts each + papers 3pts each.
    CGPA and SGPA are on a 0–10 scale.
    """
    cgpa = (entry.overall_cgpa or 0.0) * 0.5
    sgpa = (entry.semester_gpa or 0.0) * 0.3
    patents = len(entry.patents) * 5
    papers = len(entry.papers) * 3
    return round(cgpa + sgpa + patents + papers, 4)


# ─── SUMMARY ──────────────────────────────────────────────────────────────────

async def get_summary(
    list_id: int, db: AsyncSession
) -> StudentSummaryResponse | None:
    result = await db.execute(
        select(StudentList)
        .where(StudentList.id == list_id)
        .options(
            selectinload(StudentList.entries)
            .selectinload(StudentEntry.patents),
            selectinload(StudentList.entries)
            .selectinload(StudentEntry.papers),
        )
    )
    student_list = result.scalar_one_or_none()
    if not student_list:
        return None

    entries = student_list.entries
    alert_students = sum(1 for e in entries if e.missed_updates_this_month >= 3)

    # Build scored list
    scored = [
        TopStudentEntry(
            id=e.id,
            student_name=e.student_name,
            register_number=e.register_number,
            semester_gpa=e.semester_gpa,
            overall_cgpa=e.overall_cgpa,
            patent_count=len(e.patents),
            paper_count=len(e.papers),
            achievement_score=_compute_score(e),
        )
        for e in entries
    ]

    top_achievers = sorted(scored, key=lambda x: x.achievement_score, reverse=True)[:3]
    top_cgpa = sorted(
        [s for s in scored if s.overall_cgpa is not None],
        key=lambda x: x.overall_cgpa,
        reverse=True,
    )[:3]

    return StudentSummaryResponse(
        list_id=list_id,
        list_name=student_list.name,
        total_students=len(entries),
        alert_students=alert_students,
        top_achievers=top_achievers,
        top_cgpa=top_cgpa,
        generated_at=datetime.now(timezone.utc),
    )


# ─── ALERT TICK (called by scheduler) ────────────────────────────────────────

async def tick_missed_updates(db: AsyncSession) -> None:
    """
    Run once per day (hooked into the existing scheduler.py).
    For every StudentEntry where last_updated_at is NOT today,
    increment missed_updates_this_month.

    At month rollover (day == 1), reset the counter.
    """
    now = datetime.now(timezone.utc)

    if now.day == 1:
        # Reset all counters at start of new month
        await db.execute(
            update(StudentEntry).values(missed_updates_this_month=0)
        )
    else:
        # Increment for entries not updated today
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        await db.execute(
            update(StudentEntry)
            .where(
                (StudentEntry.last_updated_at == None)  # never submitted
                | (StudentEntry.last_updated_at < today_start)
            )
            .values(
                missed_updates_this_month=StudentEntry.missed_updates_this_month + 1
            )
        )

    await db.commit()