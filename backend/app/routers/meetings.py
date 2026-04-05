import json
from typing import List, Optional
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update as sql_update

from app.db.session import get_db
from app.core.security import get_current_staff
from app.models.staff import Staff
from app.models.meeting import MeetingStatus, AttendeeStatus, meeting_attendees, Meeting
from app.schemas.meeting import (
    MeetingCreateRequest,
    MeetingUpdateRequest,
    MeetingResponse,
    MeetingDetailResponse,
    MeetingSummaryResponse,
    BotProfileCreateRequest,
    BotProfileResponse,
    GenerateSummaryRequest,
    ShareMeetingToGroupRequest,
    UpdateAttendeeStatusRequest,
    MessageResponse,
)
from app.services.meeting_service import (
    create_meeting,
    get_meeting_by_id,
    get_meetings_for_staff,
    get_attendee_status,
    update_meeting,
    update_attendee_status,
    cancel_meeting,
    create_bot_profile,
    save_meeting_summary,
)
from app.services.ai_service import (
    generate_meeting_summary,
    check_availability_and_decide_bot,
)
from app.services.fireflies_service import (   # ← replaces recall imports
    extract_transcript_from_webhook,
    fetch_fireflies_transcript,
    is_fireflies_sentinel,
    extract_fireflies_id,
)
from app.services.fcm_service import send_multicast_notification


router = APIRouter(prefix="/meetings", tags=["Meetings & AI Bot"])


# ─── Helpers ──────────────────────────────────────────────────────────────────

def serialize_summary(summary) -> Optional[dict]:
    if not summary:
        return None
    return {
        "id": summary.id,
        "meeting_id": summary.meeting_id,
        "summary": summary.summary,
        "key_points": json.loads(summary.key_points) if summary.key_points else [],
        "action_items": json.loads(summary.action_items) if summary.action_items else [],
        "generated_by_ai": summary.generated_by_ai,
        "created_at": summary.created_at.isoformat(),
    }


def serialize_meeting(meeting, include_detail=False) -> dict:
    base = {
        "id": meeting.id,
        "title": meeting.title,
        "description": meeting.description,
        "platform": meeting.platform.value,
        "meeting_link": meeting.meeting_link,
        "meeting_id_external": meeting.meeting_id_external,
        "passcode": meeting.passcode,
        "scheduled_at": meeting.scheduled_at.isoformat(),
        "duration_minutes": meeting.duration_minutes,
        "status": meeting.status.value,
        "created_by": meeting.created_by,
        "shared_to_group_id": meeting.shared_to_group_id,
        "bot_enabled": meeting.bot_enabled,
        "bot_joined": meeting.bot_joined,
        "created_at": meeting.created_at.isoformat(),
    }

    if include_detail:
        base["attendees"] = [
            {
                "id": a.id,
                "full_name": a.full_name,
                "department": a.department.value,
                "avatar_url": a.avatar_url,
            }
            for a in (meeting.attendees or [])
        ]
        base["summary"] = serialize_summary(meeting.summary)
        base["bot_profile"] = {
            "id": meeting.bot_profile.id,
            "bot_name": meeting.bot_profile.bot_name,
            "bot_persona": meeting.bot_profile.bot_persona,
            "auto_join": meeting.bot_profile.auto_join,
            "notify_after_summary": meeting.bot_profile.notify_after_summary,
        } if meeting.bot_profile else None

    return base


# ─── Create Meeting ───────────────────────────────────────────────────────────

@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_new_meeting(
    payload: MeetingCreateRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """
    Create a meeting. The system automatically:
    1. Checks availability of all invited staff.
    2. Marks bot_attending=True for unavailable staff.
    3. Deploys Fireflies AI bot for unavailable staff.
    4. Creates FCM reminders 10 min before for all attendees.
    """
    meeting, unavailable = await create_meeting(db, payload, current_staff.id)

    bot_message = None
    if unavailable:
        bot_message = await check_availability_and_decide_bot(
            unavailable_staff=unavailable,
            meeting_title=meeting.title,
            scheduled_at=meeting.scheduled_at.strftime("%d %b %Y at %I:%M %p"),
        )

    # Create AI-generated reminders 10 min before meeting for all attendees
    from app.services.reminder_service import create_ai_meeting_reminder

    attendee_ids = list(set([current_staff.id] + payload.attendee_ids))
    staff_result = await db.execute(
        select(Staff).where(Staff.id.in_(attendee_ids))
    )
    all_attendees = staff_result.scalars().all()

    for attendee in all_attendees:
        try:
            await create_ai_meeting_reminder(
                db=db,
                staff_id=attendee.id,
                meeting_id=meeting.id,
                meeting_title=meeting.title,
                scheduled_at=meeting.scheduled_at,
                platform=meeting.platform.value,
                staff_name=attendee.full_name,
            )
        except Exception:
            pass  # Never block meeting creation if reminder fails

    await db.commit()

    return {
        "meeting": serialize_meeting(meeting),
        "unavailable_staff": unavailable,
        "bot_notification": bot_message,
    }


# ─── Get My Meetings ──────────────────────────────────────────────────────────

@router.get("/", response_model=List[dict])
async def get_my_meetings(
    upcoming_only: bool = Query(default=False),
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    meetings = await get_meetings_for_staff(db, current_staff.id, upcoming_only)
    return [serialize_meeting(m) for m in meetings]


# ─── Get Meeting Detail ───────────────────────────────────────────────────────

@router.get("/{meeting_id}")
async def get_meeting_detail(
    meeting_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    meeting = await get_meeting_by_id(db, meeting_id)
    if not meeting:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meeting not found.")

    attendee = await get_attendee_status(db, meeting_id, current_staff.id)
    if not attendee and meeting.created_by != current_staff.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You are not part of this meeting.")

    return serialize_meeting(meeting, include_detail=True)


# ─── Update Meeting ───────────────────────────────────────────────────────────

@router.patch("/{meeting_id}")
async def update_meeting_info(
    meeting_id: int,
    payload: MeetingUpdateRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    meeting = await get_meeting_by_id(db, meeting_id)
    if not meeting:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meeting not found.")
    if meeting.created_by != current_staff.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the meeting creator can update it.")

    updated = await update_meeting(db, meeting, payload)
    return serialize_meeting(updated)


# ─── Cancel Meeting ───────────────────────────────────────────────────────────

@router.delete("/{meeting_id}", response_model=MessageResponse)
async def cancel_my_meeting(
    meeting_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    meeting = await get_meeting_by_id(db, meeting_id)
    if not meeting:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meeting not found.")
    if meeting.created_by != current_staff.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the meeting creator can cancel it.")
    if meeting.status == MeetingStatus.CANCELLED:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Meeting is already cancelled.")

    await cancel_meeting(db, meeting)
    return MessageResponse(message="Meeting cancelled successfully.")


# ─── RSVP ─────────────────────────────────────────────────────────────────────

@router.patch("/{meeting_id}/rsvp", response_model=MessageResponse)
async def rsvp_meeting(
    meeting_id: int,
    payload: UpdateAttendeeStatusRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    attendee = await get_attendee_status(db, meeting_id, current_staff.id)
    if not attendee:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="You are not invited to this meeting.")

    await update_attendee_status(db, meeting_id, current_staff.id, payload.status)
    return MessageResponse(message=f"RSVP updated to '{payload.status.value}'.")


# ─── Share Meeting to Group ───────────────────────────────────────────────────

@router.post("/{meeting_id}/share", response_model=MessageResponse)
async def share_meeting_to_group(
    meeting_id: int,
    payload: ShareMeetingToGroupRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    from app.services.group_service import save_message, is_member
    from app.models.group import MessageType

    meeting = await get_meeting_by_id(db, meeting_id)
    if not meeting:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meeting not found.")

    if not await is_member(db, payload.group_id, current_staff.id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You are not a member of this group.")

    content = (
        f"📅 Meeting Invite: {meeting.title}\n"
        f"🕒 {meeting.scheduled_at.strftime('%d %b %Y at %I:%M %p')}\n"
        f"📍 Platform: {meeting.platform.value.replace('_', ' ').title()}\n"
        f"🔗 {meeting.meeting_link}"
    )

    await save_message(
        db=db,
        group_id=payload.group_id,
        sender_id=current_staff.id,
        content=content,
        message_type=MessageType.MEETING_INVITE,
    )

    return MessageResponse(message="Meeting shared to group successfully.")


# ─── Create Bot Profile ───────────────────────────────────────────────────────

@router.post("/{meeting_id}/bot-profile", response_model=dict)
async def setup_bot_profile(
    meeting_id: int,
    payload: BotProfileCreateRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    meeting = await get_meeting_by_id(db, meeting_id)
    if not meeting:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meeting not found.")

    attendee = await get_attendee_status(db, meeting_id, current_staff.id)
    if not attendee:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You are not part of this meeting.")

    bot_profile = await create_bot_profile(db, meeting_id, current_staff.id, payload)

    return {
        "id": bot_profile.id,
        "meeting_id": bot_profile.meeting_id,
        "staff_id": bot_profile.staff_id,
        "bot_name": bot_profile.bot_name,
        "bot_persona": bot_profile.bot_persona,
        "auto_join": bot_profile.auto_join,
        "notify_after_summary": bot_profile.notify_after_summary,
        "created_at": bot_profile.created_at.isoformat(),
    }


# ─── Generate AI Summary (manual) ────────────────────────────────────────────

@router.post("/{meeting_id}/summary", response_model=dict)
async def generate_summary(
    meeting_id: int,
    payload: GenerateSummaryRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """
    Manual: submit a transcript and get Groq AI summary.
    Auto: Fireflies webhook triggers this automatically via /webhook/fireflies.
    """
    meeting = await get_meeting_by_id(db, meeting_id)
    if not meeting:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meeting not found.")

    attendee = await get_attendee_status(db, meeting_id, current_staff.id)
    if not attendee and meeting.created_by != current_staff.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You are not part of this meeting.")

    ai_result = await generate_meeting_summary(
        transcript=payload.transcript,
        meeting_title=meeting.title,
    )

    summary = await save_meeting_summary(
        db=db,
        meeting_id=meeting_id,
        summary=ai_result["summary"],
        key_points=ai_result["key_points"],
        action_items=ai_result["action_items"],
        transcript=payload.transcript,
    )

    return serialize_summary(summary)


# ─── Get Meeting Summary ──────────────────────────────────────────────────────

@router.get("/{meeting_id}/summary")
async def get_meeting_summary(
    meeting_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    meeting = await get_meeting_by_id(db, meeting_id)
    if not meeting:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Meeting not found.")

    if not meeting.summary:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No summary available yet.")

    return serialize_summary(meeting.summary)


# ─── Fireflies Webhook ────────────────────────────────────────────────────────

@router.post("/webhook/fireflies", include_in_schema=False)
async def fireflies_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """
    Fireflies calls this when transcription is complete.

    Payload: { "meetingId": "xxx", "eventType": "Transcription completed" }

    Setup: Fireflies Dashboard → Settings → Developer Settings → Webhooks
    → paste: https://your-server.com/meetings/webhook/fireflies

    Flow:
    1. Extract meetingId from payload
    2. Fetch full transcript from Fireflies API
    3. Generate Groq AI summary
    4. Save to MeetingSummary table
    5. Send FCM push to all attendees
    """
    payload = await request.json()
    event_type = payload.get("eventType", "")

    # ── Bot joined (transcription started) ───────────────────────────────────
    if event_type == "Transcription started":
        # We don't have a meeting_id mapping at this stage — no action needed.
        # bot_joined is set to True at deploy time in meeting_service.py
        return {"status": "ok"}

    # ── Transcription complete ────────────────────────────────────────────────
    if event_type != "Transcription completed":
        return {"status": "unhandled_event", "event": event_type}

    # extract_transcript_from_webhook returns sentinel string with transcript ID
    sentinel = extract_transcript_from_webhook(payload)
    if not sentinel or not is_fireflies_sentinel(sentinel):
        return {"status": "missing_meeting_id"}

    transcript_id = extract_fireflies_id(sentinel)

    # Fetch full transcript text from Fireflies API
    transcript = await fetch_fireflies_transcript(transcript_id)
    if not transcript:
        return {"status": "transcript_fetch_failed"}

    # Find the matching meeting by bot_joined=True and status=ONGOING or SCHEDULED
    # Best match: most recent meeting that has bot_joined=True and no summary yet
    from sqlalchemy.orm import selectinload as sil
    result = await db.execute(
        select(Meeting)
        .options(
            sil(Meeting.attendees),
            sil(Meeting.summary),
            sil(Meeting.bot_profile),
        )
        .where(
            Meeting.bot_joined == True,
            Meeting.status.in_([MeetingStatus.SCHEDULED, MeetingStatus.ONGOING]),
        )
        .order_by(Meeting.scheduled_at.desc())
        .limit(1)
    )
    meeting = result.scalar_one_or_none()

    if not meeting:
        return {"status": "no_matching_meeting"}

    # Generate Groq AI summary
    try:
        ai_result = await generate_meeting_summary(
            transcript=transcript,
            meeting_title=meeting.title,
        )
    except Exception as e:
        return {"status": "summary_failed", "error": str(e)}

    # Save summary to DB
    await save_meeting_summary(
        db=db,
        meeting_id=meeting.id,
        summary=ai_result["summary"],
        key_points=ai_result["key_points"],
        action_items=ai_result["action_items"],
        transcript=transcript,
    )
    await db.commit()

    # Send FCM push notifications to all attendees
    if meeting.bot_profile and meeting.bot_profile.notify_after_summary:
        attendee_ids = [a.id for a in (meeting.attendees or [])]
        if attendee_ids:
            tokens_result = await db.execute(
                select(Staff.fcm_token).where(
                    Staff.id.in_(attendee_ids),
                    Staff.fcm_token.isnot(None),
                    Staff.push_notifications_enabled == True,
                )
            )
            tokens = [row[0] for row in tokens_result.fetchall()]
            if tokens:
                await send_multicast_notification(
                    fcm_tokens=tokens,
                    title=f"Meeting Summary Ready: {meeting.title}",
                    body="AI bot has generated a summary. Tap to view key points and action items.",
                    data={"meeting_id": str(meeting.id), "type": "meeting_summary"},
                )

    return {"status": "summary_saved"}


# ─── Old bot-webhook route kept for any legacy references ────────────────────
# All new traffic goes to /webhook/fireflies above.

@router.post("/{meeting_id}/bot-webhook", include_in_schema=False)
async def legacy_bot_webhook(
    meeting_id: int,
    payload: dict,
    db: AsyncSession = Depends(get_db),
):
    """Legacy route — redirects logic to fireflies webhook handler."""
    return {"status": "deprecated", "message": "Use /meetings/webhook/fireflies instead."}