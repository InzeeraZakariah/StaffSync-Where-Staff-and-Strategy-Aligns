from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.models.group import Group, Message, MessageType, group_members
from app.models.staff import Staff
from app.services.webSocket_manager import manager
from app.services.fcm_service import send_multicast_notification


async def share_to_group(
    db: AsyncSession,
    group_id: int,
    sender_id: int,
    share_type: str,          # "resource" | "meeting" | "reminder" | "urgent"
    title: str,
    description: Optional[str],
    link: Optional[str],
    is_urgent: bool = False,
) -> dict:
    """
    Share any content (resource/meeting/reminder) to a group.
    Creates a message in the group chat and sends push notifications.
    """

    # Build message content
    type_icons = {
        "resource": "📎",
        "meeting":  "📅",
        "reminder": "🔔",
        "urgent":   "🚨",
    }
    icon = type_icons.get(share_type, "📌")

    content_parts = [f"{icon} *{title}*"]
    if description:
        content_parts.append(description)
    if link:
        content_parts.append(f"🔗 {link}")

    content = "\n".join(content_parts)

    # Save message in group chat
    msg = Message(
        group_id=group_id,
        sender_id=sender_id,
        message_type=MessageType.TEXT,
        content=content,
    )
    db.add(msg)
    await db.flush()
    await db.refresh(msg)

    # Get sender info
    sender_result = await db.execute(
        select(Staff).where(Staff.id == sender_id)
    )
    sender = sender_result.scalar_one_or_none()
    sender_name = sender.full_name if sender else "Staff"

    # Get group members for notification
    members_result = await db.execute(
        select(Staff)
        .join(group_members, Staff.id == group_members.c.staff_id)
        .where(group_members.c.group_id == group_id)
    )
    members = members_result.scalars().all()

    fcm_tokens = [
        m.fcm_token for m in members
        if m.fcm_token and m.id != sender_id
        and m.push_notifications_enabled
    ]

    # Send push notification
    notif_title  = f"🚨 {title}" if is_urgent else f"{icon} {title}"
    notif_body   = f"{sender_name} shared in group"
    notif_channel = "staffsync_urgent" if is_urgent else "staffsync_chat"

    if fcm_tokens:
        await send_multicast_notification(
            fcm_tokens=fcm_tokens,
            title=notif_title,
            body=notif_body,
            data={
                "type":       share_type,
                "group_id":   str(group_id),
                "is_urgent":  "true" if is_urgent else "false",
                "link":       link or "",
            },
        )

    # Broadcast via WebSocket
    await manager.broadcast(
        group_id=group_id,
        event="new_message",
        data={
            "id":           msg.id,
            "group_id":     group_id,
            "sender_id":    sender_id,
            "sender_name":  sender_name,
            "message_type": "text",
            "content":      content,
            "is_deleted":   False,
            "created_at":   msg.created_at.isoformat(),
        },
    )

    return {
        "message_id": msg.id,
        "shared_to":  len(fcm_tokens),
        "content":    content,
    }