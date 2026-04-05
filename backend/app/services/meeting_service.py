import json
from typing import List, Optional, Tuple
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, update
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, status

from app.models.meeting import (
    Meeting, MeetingSummary, MeetingBotProfile,
    meeting_attendees, MeetingStatus, AttendeeStatus
)
from app.models.staff import Staff
from app.schemas.meeting import (
    MeetingCreateRequest, MeetingUpdateRequest,
    BotProfileCreateRequest,
)
from app.services.availability_service import check_staff_availability
from app.services.fireflies_service import deploy_fireflies_bot   # ← replaces recall


# ─── Create Meeting ───────────────────────────────────────────────────────────

async def create_meeting(
    db: AsyncSession,
    payload: MeetingCreateRequest,
    creator_id: int,
) -> Tuple[Meeting, List[dict]]:
    """
    Creates a meeting, checks availability for all attendees,
    and marks bot_attending=True for unavailable staff.
    Deploys Fireflies bot if any staff are unavailable.
    Returns (meeting, list of unavailable staff dicts).
    """
    meeting = Meeting(
        title=payload.title,
        description=payload.description,
        platform=payload.platform,
        meeting_link=payload.meeting_link,
        meeting_id_external=payload.meeting_id_external,
        passcode=payload.passcode,
        scheduled_at=payload.scheduled_at,
        duration_minutes=payload.duration_minutes,
        created_by=creator_id,
        shared_to_group_id=payload.shared_to_group_id,
        bot_enabled=payload.bot_enabled,
    )
    db.add(meeting)
    await db.flush()

    all_attendee_ids = list(set([creator_id] + payload.attendee_ids))
    unavailable_staff = []

    meeting_date = payload.scheduled_at.date()
    meeting_time = payload.scheduled_at.time()

    for staff_id in all_attendee_ids:
        is_available, _ = await check_staff_availability(
            db, staff_id, meeting_date, meeting_time
        )
        bot_attending = not is_available and payload.bot_enabled

        await db.execute(
            meeting_attendees.insert().values(
                meeting_id=meeting.id,
                staff_id=staff_id,
                status=AttendeeStatus.INVITED,
                bot_attending=bot_attending,
            )
        )

        if bot_attending:
            staff_result = await db.execute(
                select(Staff).where(Staff.id == staff_id)
            )
            staff = staff_result.scalar_one_or_none()
            if staff:
                unavailable_staff.append({
                    "staff_id": staff_id,
                    "full_name": staff.full_name,
                })

    await db.flush()
    await db.refresh(meeting)

    # Deploy Fireflies bot if any staff are unavailable and bot is enabled
    if unavailable_staff and payload.bot_enabled:
        success = await deploy_fireflies_bot(
            meeting_link=payload.meeting_link,
            bot_name="StaffSync AI Bot",
            duration_minutes=payload.duration_minutes or 60,
            meeting_title=payload.title,
        )
        if success:
            meeting.bot_joined = True
            meeting.bot_join_time = datetime.now(timezone.utc)
            await db.flush()

    return meeting, unavailable_staff


# ─── Read ─────────────────────────────────────────────────────────────────────

async def get_meeting_by_id(db: AsyncSession, meeting_id: int) -> Optional[Meeting]:
    result = await db.execute(
        select(Meeting)
        .options(
            selectinload(Meeting.attendees),
            selectinload(Meeting.summary),
            selectinload(Meeting.bot_profile),
            selectinload(Meeting.creator),
        )
        .where(Meeting.id == meeting_id)
    )
    return result.scalar_one_or_none()


async def get_meetings_for_staff(
    db: AsyncSession,
    staff_id: int,
    upcoming_only: bool = False,
) -> List[Meeting]:
    query = (
        select(Meeting)
        .join(meeting_attendees, Meeting.id == meeting_attendees.c.meeting_id)
        .where(meeting_attendees.c.staff_id == staff_id)
        .options(selectinload(Meeting.attendees), selectinload(Meeting.summary))
        .order_by(Meeting.scheduled_at.asc())
    )
    if upcoming_only:
        query = query.where(
            Meeting.scheduled_at >= datetime.now(timezone.utc),
            Meeting.status == MeetingStatus.SCHEDULED,
        )

    result = await db.execute(query)
    return result.scalars().all()


async def get_attendee_status(
    db: AsyncSession, meeting_id: int, staff_id: int
) -> Optional[dict]:
    result = await db.execute(
        select(meeting_attendees).where(
            and_(
                meeting_attendees.c.meeting_id == meeting_id,
                meeting_attendees.c.staff_id == staff_id,
            )
        )
    )
    row = result.fetchone()
    if row:
        return {"status": row.status, "bot_attending": row.bot_attending}
    return None


# ─── Update Meeting ───────────────────────────────────────────────────────────

async def update_meeting(
    db: AsyncSession, meeting: Meeting, payload: MeetingUpdateRequest
) -> Meeting:
    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(meeting, field, value)
    await db.flush()
    await db.refresh(meeting)
    return meeting


async def update_attendee_status(
    db: AsyncSession, meeting_id: int, staff_id: int, new_status: AttendeeStatus
) -> None:
    await db.execute(
        update(meeting_attendees)
        .where(
            and_(
                meeting_attendees.c.meeting_id == meeting_id,
                meeting_attendees.c.staff_id == staff_id,
            )
        )
        .values(status=new_status)
    )
    await db.flush()


async def cancel_meeting(db: AsyncSession, meeting: Meeting) -> None:
    """Cancel meeting. No bot cancellation needed — Fireflies bot exits when meeting ends."""
    meeting.status = MeetingStatus.CANCELLED
    await db.flush()


# ─── Bot Profile ──────────────────────────────────────────────────────────────

async def create_bot_profile(
    db: AsyncSession,
    meeting_id: int,
    staff_id: int,
    payload: BotProfileCreateRequest,
) -> MeetingBotProfile:
    existing = await db.execute(
        select(MeetingBotProfile).where(MeetingBotProfile.meeting_id == meeting_id)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A bot profile already exists for this meeting.",
        )

    bot_profile = MeetingBotProfile(
        meeting_id=meeting_id,
        staff_id=staff_id,
        bot_name=payload.bot_name,
        bot_persona=payload.bot_persona,
        auto_join=payload.auto_join,
        notify_after_summary=payload.notify_after_summary,
    )
    db.add(bot_profile)
    await db.flush()
    await db.refresh(bot_profile)
    return bot_profile


# ─── Meeting Summary ──────────────────────────────────────────────────────────

async def save_meeting_summary(
    db: AsyncSession,
    meeting_id: int,
    summary: str,
    key_points: List[str],
    action_items: List[str],
    transcript: Optional[str] = None,
) -> MeetingSummary:
    existing = await db.execute(
        select(MeetingSummary).where(MeetingSummary.meeting_id == meeting_id)
    )
    existing_summary = existing.scalar_one_or_none()

    if existing_summary:
        existing_summary.summary = summary
        existing_summary.key_points = json.dumps(key_points)
        existing_summary.action_items = json.dumps(action_items)
        existing_summary.transcript = transcript
        await db.flush()
        await db.refresh(existing_summary)
        return existing_summary

    meeting_summary = MeetingSummary(
        meeting_id=meeting_id,
        summary=summary,
        key_points=json.dumps(key_points),
        action_items=json.dumps(action_items),
        transcript=transcript,
        generated_by_ai=True,
    )
    db.add(meeting_summary)

    await db.execute(
        update(Meeting)
        .where(Meeting.id == meeting_id)
        .values(status=MeetingStatus.COMPLETED)
    )

    await db.flush()
    await db.refresh(meeting_summary)
    return meeting_summary