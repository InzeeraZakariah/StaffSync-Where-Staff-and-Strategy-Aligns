from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.security import get_current_staff
from app.models.staff import Staff
from app.schemas.reminder import (
    ReminderCreateRequest,
    ReminderUpdateRequest,
    ReminderResponse,
    UrgentNotifyRequest,
    UrgentNotifyResponse,
    MessageResponse,
)
from app.services.reminder_service import (
    create_reminder,
    get_my_reminders,
    get_reminder_by_id,
    update_reminder,
    mark_reminder_read,
    delete_reminder,
    send_urgent_notification,
)

router = APIRouter(prefix="/reminders", tags=["Reminders & Urgent Notify"])


@router.post("/urgent", response_model=UrgentNotifyResponse, status_code=status.HTTP_201_CREATED)
async def urgent_notify(
    payload: UrgentNotifyRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    urgent = await send_urgent_notification(db, current_staff.id, payload)
    return urgent


@router.post("/", response_model=ReminderResponse, status_code=status.HTTP_201_CREATED)
async def create_custom_reminder(
    payload: ReminderCreateRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    reminder = await create_reminder(db, current_staff.id, payload, created_by=current_staff.id)
    return reminder


@router.get("/", response_model=List[ReminderResponse])
async def get_my_reminders_list(
    unread_only: bool = Query(default=False),
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    return await get_my_reminders(db, current_staff.id, unread_only)


@router.get("/{reminder_id}", response_model=ReminderResponse)
async def get_reminder(
    reminder_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    reminder = await get_reminder_by_id(db, reminder_id)
    if not reminder:
        raise HTTPException(status_code=404, detail="Reminder not found.")
    if reminder.staff_id != current_staff.id:
        raise HTTPException(status_code=403, detail="Access denied.")
    return reminder


@router.patch("/{reminder_id}", response_model=ReminderResponse)
async def update_my_reminder(
    reminder_id: int,
    payload: ReminderUpdateRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    reminder = await get_reminder_by_id(db, reminder_id)
    if not reminder:
        raise HTTPException(status_code=404, detail="Reminder not found.")
    if reminder.staff_id != current_staff.id:
        raise HTTPException(status_code=403, detail="Access denied.")
    return await update_reminder(db, reminder, payload)


@router.patch("/{reminder_id}/read", response_model=ReminderResponse)
async def mark_as_read(
    reminder_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    reminder = await get_reminder_by_id(db, reminder_id)
    if not reminder:
        raise HTTPException(status_code=404, detail="Reminder not found.")
    if reminder.staff_id != current_staff.id:
        raise HTTPException(status_code=403, detail="Access denied.")
    return await mark_reminder_read(db, reminder)


@router.delete("/{reminder_id}", response_model=MessageResponse)
async def delete_my_reminder(
    reminder_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    reminder = await get_reminder_by_id(db, reminder_id)
    if not reminder:
        raise HTTPException(status_code=404, detail="Reminder not found.")
    if reminder.staff_id != current_staff.id:
        raise HTTPException(status_code=403, detail="Access denied.")
    await delete_reminder(db, reminder)
    return MessageResponse(message="Reminder deleted successfully.")


@router.post("/{reminder_id}/share/group", response_model=MessageResponse)
async def share_reminder_to_group(
    reminder_id: int,
    group_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Share a reminder to a group chat."""
    reminder = await get_reminder_by_id(db, reminder_id)
    if not reminder:
        raise HTTPException(status_code=404, detail="Reminder not found.")
    if reminder.staff_id != current_staff.id:
        raise HTTPException(status_code=403, detail="Access denied.")

    from app.services.group_service import save_message, is_member
    from app.models.group import group_members, MessageType
    from app.models.staff import Staff as StaffModel
    from sqlalchemy import select as sql_select

    if not await is_member(db, group_id, current_staff.id):
        raise HTTPException(status_code=403, detail="Not a group member.")

    content = (
        f"🔔 Reminder: {reminder.title}\n"
        f"🕒 {reminder.remind_at.strftime('%d %b %Y at %I:%M %p')}\n"
        f"{reminder.body or ''}"
    )
    await save_message(
        db=db,
        group_id=group_id,
        sender_id=current_staff.id,
        content=content,
        message_type=MessageType.TEXT,
    )

    # Notify group members
    member_ids_result = await db.execute(
        sql_select(group_members.c.staff_id).where(
            group_members.c.group_id == group_id
        )
    )
    member_ids = [r[0] for r in member_ids_result.fetchall()
                  if r[0] != current_staff.id]
    if member_ids:
        tokens_result = await db.execute(
            sql_select(StaffModel.fcm_token).where(
                StaffModel.id.in_(member_ids),
                StaffModel.fcm_token.isnot(None),
                StaffModel.push_notifications_enabled == True,
            )
        )
        tokens = [r[0] for r in tokens_result.fetchall()]
        if tokens:
            from app.services.fcm_service import send_multicast_notification
            await send_multicast_notification(
                fcm_tokens=tokens,
                title=f"🔔 Reminder Shared: {reminder.title}",
                body=f"{current_staff.full_name} shared a reminder with your group.",
                data={"type": "reminder_shared", "reminder_id": str(reminder_id)},
            )

    return MessageResponse(message="Reminder shared to group successfully.")