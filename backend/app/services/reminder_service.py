from datetime import datetime, timedelta, timezone
from typing import List, Optional

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, update
from fastapi import HTTPException, status

from app.models.reminder import Reminder, UrgentNotification, ReminderType, ReminderStatus
from app.models.staff import Staff
from app.schemas.reminder import ReminderCreateRequest, ReminderUpdateRequest, UrgentNotifyRequest
from app.services.fcm_service import send_push_notification, send_multicast_notification
from app.services.reminder_ai_service import generate_ai_reminder_message, generate_urgent_notify_message


async def create_reminder(
    db: AsyncSession,
    staff_id: int,
    payload: ReminderCreateRequest,
    created_by: int,
) -> Reminder:
    reminder = Reminder(
        staff_id=staff_id,
        title=payload.title,
        body=payload.body,
        reason=payload.reason,
        remind_at=payload.remind_at,
        meeting_id=payload.meeting_id,
        reminder_type=ReminderType.MEETING if payload.meeting_id else ReminderType.CUSTOM,
        created_by=created_by,
        is_ai_generated=False,
    )
    db.add(reminder)
    await db.flush()
    await db.refresh(reminder)
    return reminder


async def create_ai_meeting_reminder(
    db: AsyncSession,
    staff_id: int,
    meeting_id: int,
    meeting_title: str,
    scheduled_at: datetime,
    platform: str,
    staff_name: str,
) -> Reminder:
    remind_at = scheduled_at - timedelta(minutes=10)

    ai_message = await generate_ai_reminder_message(
        meeting_title=meeting_title,
        scheduled_at=scheduled_at,
        platform=platform,
        staff_name=staff_name,
    )

    reminder = Reminder(
        staff_id=staff_id,
        meeting_id=meeting_id,
        title=ai_message["title"],
        body=ai_message["body"],
        remind_at=remind_at,
        reminder_type=ReminderType.MEETING,
        is_ai_generated=True,
        created_by=staff_id,
    )
    db.add(reminder)
    await db.flush()
    await db.refresh(reminder)
    return reminder


async def get_my_reminders(
    db: AsyncSession,
    staff_id: int,
    unread_only: bool = False,
) -> List[Reminder]:
    conditions = [Reminder.staff_id == staff_id]
    if unread_only:
        conditions.append(Reminder.is_read == False)
    result = await db.execute(
        select(Reminder)
        .where(and_(*conditions))
        .order_by(Reminder.remind_at.asc())
    )
    return result.scalars().all()


async def get_reminder_by_id(db: AsyncSession, reminder_id: int) -> Optional[Reminder]:
    result = await db.execute(select(Reminder).where(Reminder.id == reminder_id))
    return result.scalar_one_or_none()


async def get_pending_reminders_due_now(db: AsyncSession) -> List[Reminder]:
    now = datetime.now(timezone.utc)
    result = await db.execute(
        select(Reminder).where(
            and_(
                Reminder.status == ReminderStatus.PENDING,
                Reminder.remind_at <= now,
            )
        )
    )
    return result.scalars().all()


async def update_reminder(
    db: AsyncSession, reminder: Reminder, payload: ReminderUpdateRequest
) -> Reminder:
    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(reminder, field, value)
    await db.flush()
    await db.refresh(reminder)
    return reminder


async def mark_reminder_read(db: AsyncSession, reminder: Reminder) -> Reminder:
    reminder.is_read = True
    reminder.status = ReminderStatus.DISMISSED
    await db.flush()
    await db.refresh(reminder)
    return reminder


async def delete_reminder(db: AsyncSession, reminder: Reminder) -> None:
    await db.delete(reminder)
    await db.flush()


async def dispatch_reminder(db: AsyncSession, reminder: Reminder) -> None:
    staff_result = await db.execute(select(Staff).where(Staff.id == reminder.staff_id))
    staff = staff_result.scalar_one_or_none()

    if not staff or not staff.push_notifications_enabled:
        reminder.status = ReminderStatus.FAILED
        await db.flush()
        return

    fcm_token = getattr(staff, "fcm_token", None)
    if not fcm_token:
        reminder.status = ReminderStatus.FAILED
        await db.flush()
        return

    # Map reminder type to FCM type Flutter understands
    fcm_type = (
        "meeting_reminder" if reminder.reminder_type == ReminderType.MEETING
        else reminder.reminder_type.value
    )

    success = await send_push_notification(
        fcm_token=fcm_token,
        title=reminder.title,
        body=reminder.body or "",
        data={
            "reminder_id": str(reminder.id),
            "type": fcm_type,
            "meeting_id": str(reminder.meeting_id) if reminder.meeting_id else "",
        },
    )

    reminder.status = ReminderStatus.SENT if success else ReminderStatus.FAILED
    await db.flush()


async def send_urgent_notification(
    db: AsyncSession,
    sender_id: int,
    payload: UrgentNotifyRequest,
) -> UrgentNotification:
    sender_result = await db.execute(select(Staff).where(Staff.id == sender_id))
    sender = sender_result.scalar_one_or_none()
    sender_name = sender.full_name if sender else "Admin"

    enhanced_body = await generate_urgent_notify_message(
        sender_name=sender_name,
        title=payload.title,
        location=payload.location,
    )

    conditions = [Staff.is_active == True, Staff.push_notifications_enabled == True]
    if payload.department:
        conditions.append(Staff.department == payload.department)

    staff_result = await db.execute(select(Staff).where(and_(*conditions)))
    all_staff = staff_result.scalars().all()

    fcm_tokens = [
        getattr(s, "fcm_token", None)
        for s in all_staff
        if getattr(s, "fcm_token", None) and s.id != sender_id
    ]

    success_count, failed_count = await send_multicast_notification(
        fcm_tokens=fcm_tokens,
        title=f"🚨 URGENT: {payload.title}",
        body=enhanced_body,
        data={"type": "urgent", "location": payload.location or "", "sender": sender_name},
    )

    urgent = UrgentNotification(
        sent_by=sender_id,
        title=payload.title,
        message=enhanced_body,
        location=payload.location,
        total_recipients=len(fcm_tokens),
        successful_sends=success_count,
    )
    db.add(urgent)

    for staff in all_staff:
        if staff.id == sender_id:
            continue
        reminder = Reminder(
            staff_id=staff.id,
            title=f"🚨 URGENT: {payload.title}",
            body=enhanced_body,
            remind_at=datetime.now(timezone.utc),
            reminder_type=ReminderType.URGENT,
            status=ReminderStatus.SENT,
            is_ai_generated=True,
            created_by=sender_id,
        )
        db.add(reminder)

    await db.flush()
    await db.refresh(urgent)
    return urgent