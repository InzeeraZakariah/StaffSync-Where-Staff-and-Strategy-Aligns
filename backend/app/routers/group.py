import os
import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, Form, status, WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, delete
from sqlalchemy.orm import selectinload

from app.db.session import get_db
from app.core.security import get_current_staff
from app.core.config import settings

from app.services.webSocket_manager import manager
from app.core.security import decode_token
from app.services.auth_service import get_staff_by_id
from app.models.group import Message, MessageType, group_members
from app.services.group_share_service import share_to_group


router = APIRouter(prefix="/groups", tags=["Groups & Chat"])


# ─── Helpers ──────────────────────────────────────────────────────────────────

def serialize_group(group, current_staff_id: int = None) -> dict:
    """Safely serialize group without triggering lazy loads."""
    members = []
    try:
        for m in (group.members or []):
            members.append({
                "id": m.id,
                "full_name": m.full_name,
                "department": m.department.value if hasattr(m.department, 'value') else str(m.department),
                "designation": m.designation.value if hasattr(m.designation, 'value') else str(m.designation),
                "avatar_url": m.avatar_url,
            })
    except Exception:
        members = []

    return {
        "id": group.id,
        "name": group.name,
        "description": group.description,
        "department": group.department.value if group.department and hasattr(group.department, 'value') else group.department,
        "created_by": group.created_by,
        "is_active": group.is_active,
        "avatar_url": group.avatar_url,
        "member_count": len(members),
        "members": members,
        "created_at": group.created_at.isoformat() if group.created_at else None,
    }


def serialize_message(msg) -> dict:
    sender = None
    try:
        if msg.sender:
            sender = {
                "id": msg.sender.id,
                "full_name": msg.sender.full_name,
                "avatar_url": msg.sender.avatar_url,
                "department": msg.sender.department.value if hasattr(msg.sender.department, 'value') else str(msg.sender.department),
            }
    except Exception:
        pass

    return {
        "id": msg.id,
        "group_id": msg.group_id,
        "sender": sender,
        "message_type": msg.message_type.value if hasattr(msg.message_type, 'value') else str(msg.message_type),
        "content": msg.content,
        "file_url": msg.file_url,
        "file_name": msg.file_name,
        "is_deleted": msg.is_deleted,
        "reply_to_id": msg.reply_to_id,
        "created_at": msg.created_at.isoformat() if msg.created_at else None,
    }


# ─── Create Group ─────────────────────────────────────────────────────────────

@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_group(
    payload: dict,
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    from app.models.group import Group, group_members
    from app.models.staff import Staff

    name = payload.get("name", "").strip()
    if not name:
        raise HTTPException(status_code=400, detail="Group name is required.")

    group = Group(
        name=name,
        description=payload.get("description"),
        department=payload.get("department"),
        created_by=current_staff.id,
    )
    db.add(group)
    await db.flush()

    # Add creator as member
    member_ids = list(set([current_staff.id] + payload.get("member_ids", [])))
    for staff_id in member_ids:
        await db.execute(
            group_members.insert().values(
                group_id=group.id,
                staff_id=staff_id,
            )
        )
    await db.flush()

    # Reload with members eagerly
    result = await db.execute(
        select(Group)
        .options(selectinload(Group.members))
        .where(Group.id == group.id)
    )
    group = result.scalar_one()
    return serialize_group(group, current_staff.id)


# ─── Get My Groups ────────────────────────────────────────────────────────────

@router.get("/")
async def get_my_groups(
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    from app.models.group import Group, group_members

    result = await db.execute(
        select(Group)
        .join(group_members, Group.id == group_members.c.group_id)
        .where(
            and_(
                group_members.c.staff_id == current_staff.id,
                Group.is_active == True,
            )
        )
        .options(selectinload(Group.members))
        .order_by(Group.created_at.desc())
    )
    groups = result.scalars().all()
    return [serialize_group(g, current_staff.id) for g in groups]


# ─── Get Group Detail ─────────────────────────────────────────────────────────

@router.get("/{group_id}")
async def get_group_detail(
    group_id: int,
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    from app.models.group import Group

    result = await db.execute(
        select(Group)
        .options(selectinload(Group.members))
        .where(Group.id == group_id)
    )
    group = result.scalar_one_or_none()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found.")
    return serialize_group(group, current_staff.id)


# ─── Update Group ─────────────────────────────────────────────────────────────

@router.patch("/{group_id}")
async def update_group(
    group_id: int,
    payload: dict,
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    from app.models.group import Group

    result = await db.execute(
        select(Group)
        .options(selectinload(Group.members))
        .where(Group.id == group_id)
    )
    group = result.scalar_one_or_none()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found.")
    if group.created_by != current_staff.id:
        raise HTTPException(status_code=403, detail="Only the group creator can update it.")

    for field in ["name", "description", "avatar_url"]:
        if field in payload:
            setattr(group, field, payload[field])

    await db.flush()
    result = await db.execute(
        select(Group).options(selectinload(Group.members)).where(Group.id == group_id)
    )
    group = result.scalar_one()
    return serialize_group(group, current_staff.id)


# ─── Add Members ─────────────────────────────────────────────────────────────

@router.post("/{group_id}/members", status_code=status.HTTP_201_CREATED)
async def add_members(
    group_id: int,
    payload: dict,
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    from app.models.group import Group, group_members
    from app.models.staff import Staff

    result = await db.execute(
        select(Group)
        .options(selectinload(Group.members))
        .where(Group.id == group_id)
    )
    group = result.scalar_one_or_none()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found.")

    # Check requester is a member
    current_ids = [m.id for m in group.members]
    if current_staff.id not in current_ids:
        raise HTTPException(status_code=403, detail="You are not a member of this group.")

    new_ids = payload.get("member_ids", [])
    added = []
    for staff_id in new_ids:
        if staff_id in current_ids:
            continue
        # Verify staff exists
        sr = await db.execute(select(Staff).where(Staff.id == staff_id))
        staff = sr.scalar_one_or_none()
        if not staff:
            continue
        await db.execute(
            group_members.insert().values(group_id=group_id, staff_id=staff_id)
        )
        added.append(staff_id)

    await db.flush()
    result = await db.execute(
        select(Group).options(selectinload(Group.members)).where(Group.id == group_id)
    )
    group = result.scalar_one()
    return {
        "message": f"Added {len(added)} member(s) successfully.",
        "group": serialize_group(group, current_staff.id),
    }


# ─── Remove Member ────────────────────────────────────────────────────────────

@router.delete("/{group_id}/members/{staff_id}")
async def remove_member(
    group_id: int,
    staff_id: int,
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    from app.models.group import Group, group_members

    result = await db.execute(
        select(Group)
        .options(selectinload(Group.members))
        .where(Group.id == group_id)
    )
    group = result.scalar_one_or_none()
    if not group:
        raise HTTPException(status_code=404, detail="Group not found.")

    if group.created_by != current_staff.id and staff_id != current_staff.id:
        raise HTTPException(status_code=403, detail="Only the creator can remove members.")

    await db.execute(
        delete(group_members).where(
            and_(
                group_members.c.group_id == group_id,
                group_members.c.staff_id == staff_id,
            )
        )
    )
    await db.flush()
    return {"message": "Member removed successfully."}


# ─── Get Messages ─────────────────────────────────────────────────────────────

@router.get("/{group_id}/messages")
async def get_messages(
    group_id: int,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, le=100),
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    from app.models.group import Message

    result = await db.execute(
        select(Message)
        .options(selectinload(Message.sender))
        .where(Message.group_id == group_id)
        .order_by(Message.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    messages = result.scalars().all()
    messages = list(reversed(messages))
    return {"messages": [serialize_message(m) for m in messages], "page": page}


# ─── Upload File/Image to Group ───────────────────────────────────────────────

@router.post("/{group_id}/upload")
async def upload_file_to_group(
    group_id: int,
    file: UploadFile = File(...),
    caption: Optional[str] = Form(None),
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    from app.models.group import Group, Message, MessageType, group_members

    # Check membership
    result = await db.execute(
        select(group_members).where(
            and_(
                group_members.c.group_id == group_id,
                group_members.c.staff_id == current_staff.id,
            )
        )
    )
    if not result.fetchone():
        raise HTTPException(status_code=403, detail="You are not a member of this group.")

    # Validate file type
    allowed_types = {
        "image/jpeg", "image/png", "image/gif", "image/webp",
        "application/pdf",
        "application/vnd.ms-powerpoint",
        "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        "video/mp4", "video/quicktime",
        "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    }
    if file.content_type not in allowed_types:
        raise HTTPException(status_code=415, detail="File type not allowed.")

    # Detect message type
    if file.content_type.startswith("image/"):
        msg_type = MessageType.IMAGE
        folder = "uploads/groups/images"
    elif file.content_type.startswith("video/"):
        msg_type = MessageType.FILE
        folder = "uploads/groups/videos"
    else:
        msg_type = MessageType.FILE
        folder = "uploads/groups/files"

    os.makedirs(folder, exist_ok=True)

    # Save file
    content = await file.read()
    max_bytes = 20 * 1024 * 1024  # 20MB
    if len(content) > max_bytes:
        raise HTTPException(status_code=413, detail="File too large. Max 20MB.")

    ext = file.filename.rsplit(".", 1)[-1] if "." in file.filename else "bin"
    filename = f"{group_id}_{current_staff.id}_{uuid.uuid4().hex}.{ext}"
    filepath = os.path.join(folder, filename)

    with open(filepath, "wb") as f:
        f.write(content)

    file_url = f"/static/groups/{msg_type.value}s/{filename}"

    # Save as message
    msg = Message(
        group_id=group_id,
        sender_id=current_staff.id,
        message_type=msg_type,
        content=caption or file.filename,
        file_url=file_url,
        file_name=file.filename,
    )
    db.add(msg)
    await db.flush()
    await db.refresh(msg)

    # Broadcast via WebSocket
    result2 = await db.execute(
        select(Message)
        .options(selectinload(Message.sender))
        .where(Message.id == msg.id)
    )
    msg_loaded = result2.scalar_one()
    await manager.broadcast(
        group_id=group_id,
        event="new_message",
        data=serialize_message(msg_loaded),
    )

    return serialize_message(msg_loaded)


# ─── Delete Message ───────────────────────────────────────────────────────────

@router.delete("/{group_id}/messages/{message_id}")
async def delete_message(
    group_id: int,
    message_id: int,
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    from app.models.group import Message

    result = await db.execute(
        select(Message).where(
            and_(Message.id == message_id, Message.group_id == group_id)
        )
    )
    msg = result.scalar_one_or_none()
    if not msg:
        raise HTTPException(status_code=404, detail="Message not found.")
    if msg.sender_id != current_staff.id:
        raise HTTPException(status_code=403, detail="You can only delete your own messages.")

    msg.is_deleted = True
    msg.content = None
    await db.flush()

    await manager.broadcast(
        group_id=group_id,
        event="message_deleted",
        data={"message_id": message_id},
    )
    return {"message": "Message deleted."}


# ─── WebSocket Chat ───────────────────────────────────────────────────────────

@router.websocket("/{group_id}/ws")
async def websocket_endpoint(
    group_id: int,
    websocket: WebSocket,
    token: str,
    db: AsyncSession = Depends(get_db),
):
   

    # Authenticate
    try:
        payload = decode_token(token)
        staff_id = int(payload.get("sub"))
        staff = await get_staff_by_id(db, staff_id)
        if not staff:
            await websocket.close(code=4001)
            return
    except Exception:
        await websocket.close(code=4001)
        return

    # Check membership
    result = await db.execute(
        select(group_members).where(
            and_(
                group_members.c.group_id == group_id,
                group_members.c.staff_id == staff_id,
            )
        )
    )
    if not result.fetchone():
        await websocket.close(code=4003)
        return

    await manager.connect(websocket, group_id, staff_id)

    try:
        while True:
            data = await websocket.receive_json()
            msg_type = data.get("type")

            if msg_type == "message":
                content = data.get("content", "").strip()
                if not content:
                    continue

                msg = Message(
                    group_id=group_id,
                    sender_id=staff_id,
                    message_type=MessageType.TEXT,
                    content=content,
                    reply_to_id=data.get("reply_to_id"),
                )
                db.add(msg)
                await db.flush()

                result2 = await db.execute(
                    select(Message)
                    .options(selectinload(Message.sender))
                    .where(Message.id == msg.id)
                )
                msg_loaded = result2.scalar_one()
                await db.commit()

                await manager.broadcast(
                    group_id=group_id,
                    event="new_message",
                    data=serialize_message(msg_loaded),
                )

            elif msg_type == "typing":
                await manager.broadcast(
                    group_id=group_id,
                    event="typing",
                    data={"staff_id": staff_id, "full_name": staff.full_name},
                    exclude=websocket,
                )

            elif msg_type == "read":
                await manager.broadcast(
                    group_id=group_id,
                    event="read",
                    data={"staff_id": staff_id},
                    exclude=websocket,
                )

    except WebSocketDisconnect:
        manager.disconnect(websocket, group_id, staff_id)
        await manager.broadcast(
            group_id=group_id,
            event="member_offline",
            data={"staff_id": staff_id},
        )

from app.services.group_share_service import share_to_group
 
@router.post("/{group_id}/share/resource")
async def share_resource_to_group(
    group_id: int,
    payload: dict,
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Share a resource link/file to group chat. Sends push notification."""
    result = await share_to_group(
        db=db,
        group_id=group_id,
        sender_id=current_staff.id,
        share_type="resource",
        title=payload.get("title", "Resource"),
        description=payload.get("description"),
        link=payload.get("link"),
        is_urgent=False,
    )
    await db.commit()
    return result


# ─── Share Meeting to Group ───────────────────────────────────────────────────

@router.post("/{group_id}/share/meeting")
async def share_meeting_to_group(
    group_id: int,
    payload: dict,
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Share a meeting invite to group chat with notification."""
    result = await share_to_group(
        db=db,
        group_id=group_id,
        sender_id=current_staff.id,
        share_type="meeting",
        title=payload.get("title", "Meeting"),
        description=payload.get("description"),
        link=payload.get("link"),
        is_urgent=False,
    )
    await db.commit()
    return result


# ─── Share Reminder to Group ──────────────────────────────────────────────────

@router.post("/{group_id}/share/reminder")
async def share_reminder_to_group(
    group_id: int,
    payload: dict,
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Share a reminder to group chat with notification."""
    result = await share_to_group(
        db=db,
        group_id=group_id,
        sender_id=current_staff.id,
        share_type="reminder",
        title=payload.get("title", "Reminder"),
        description=payload.get("description"),
        link=payload.get("link"),
        is_urgent=False,
    )
    await db.commit()
    return result


# ─── Share Urgent to Group ────────────────────────────────────────────────────

@router.post("/{group_id}/share/urgent")
async def share_urgent_to_group(
    group_id: int,
    payload: dict,
    current_staff=Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Send emergency alert to group chat with alarm notification sound."""
    result = await share_to_group(
        db=db,
        group_id=group_id,
        sender_id=current_staff.id,
        share_type="urgent",
        title=payload.get("title", "Urgent Alert"),
        description=payload.get("description"),
        link=None,
        is_urgent=True,
    )
    await db.commit()
    return result

