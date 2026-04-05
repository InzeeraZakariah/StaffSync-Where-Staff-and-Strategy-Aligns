from typing import List, Optional, Tuple
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, delete, and_
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, status

from app.models.group import Group, Message, MessageReadReceipt, group_members, MessageType
from app.models.staff import Staff
from app.schemas.group import GroupCreateRequest, GroupUpdateRequest


# ─── Group Operations ─────────────────────────────────────────────────────────

async def create_group(
    db: AsyncSession, payload: GroupCreateRequest, creator_id: int
) -> Group:
    group = Group(
        name=payload.name,
        description=payload.description,
        department=payload.department,
        created_by=creator_id,
    )
    db.add(group)
    await db.flush()

    # Add creator as admin member
    member_ids = list(set([creator_id] + payload.member_ids))
    for staff_id in member_ids:
        is_admin = staff_id == creator_id
        await db.execute(
            group_members.insert().values(
                group_id=group.id,
                staff_id=staff_id,
                is_admin=is_admin,
            )
        )

    await db.flush()
    await db.refresh(group)
    result = await db.execute(
        select(Group).options(selectinload(Group.members)).where(Group.id == group.id)
    )
    group = result.scalar_one()
    return group


async def get_group_by_id(db: AsyncSession, group_id: int) -> Optional[Group]:
    result = await db.execute(
        select(Group)
        .options(selectinload(Group.members))
        .where(Group.id == group_id, Group.is_active == True)
    )
    return result.scalar_one_or_none()


async def get_groups_for_staff(db: AsyncSession, staff_id: int) -> List[Group]:
    result = await db.execute(
        select(Group)
        .join(group_members, Group.id == group_members.c.group_id)
        .where(
            group_members.c.staff_id == staff_id,
            Group.is_active == True,
        )
        .options(selectinload(Group.members))
        .order_by(Group.updated_at.desc())
    )
    return result.scalars().all()


async def is_member(db: AsyncSession, group_id: int, staff_id: int) -> bool:
    result = await db.execute(
        select(group_members).where(
            and_(
                group_members.c.group_id == group_id,
                group_members.c.staff_id == staff_id,
            )
        )
    )
    return result.fetchone() is not None


async def is_group_admin(db: AsyncSession, group_id: int, staff_id: int) -> bool:
    result = await db.execute(
        select(group_members).where(
            and_(
                group_members.c.group_id == group_id,
                group_members.c.staff_id == staff_id,
                group_members.c.is_admin == True,
            )
        )
    )
    return result.fetchone() is not None


async def add_members_to_group(
    db: AsyncSession, group_id: int, staff_ids: List[int]
) -> None:
    for staff_id in staff_ids:
        already = await is_member(db, group_id, staff_id)
        if not already:
            await db.execute(
                group_members.insert().values(
                    group_id=group_id,
                    staff_id=staff_id,
                    is_admin=False,
                )
            )
    await db.flush()


async def remove_member_from_group(
    db: AsyncSession, group_id: int, staff_id: int
) -> None:
    await db.execute(
        delete(group_members).where(
            and_(
                group_members.c.group_id == group_id,
                group_members.c.staff_id == staff_id,
            )
        )
    )
    await db.flush()


async def update_group(
    db: AsyncSession, group: Group, payload: GroupUpdateRequest
) -> Group:
    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(group, field, value)
    await db.flush()
    await db.refresh(group)
    return group


async def deactivate_group(db: AsyncSession, group: Group) -> None:
    group.is_active = False
    await db.flush()


# ─── Message Operations ───────────────────────────────────────────────────────

async def save_message(
    db: AsyncSession,
    group_id: int,
    sender_id: int,
    content: Optional[str],
    message_type: MessageType = MessageType.TEXT,
    file_url: Optional[str] = None,
    file_name: Optional[str] = None,
    reply_to_id: Optional[int] = None,
) -> Message:
    message = Message(
        group_id=group_id,
        sender_id=sender_id,
        content=content,
        message_type=message_type,
        file_url=file_url,
        file_name=file_name,
        reply_to_id=reply_to_id,
    )
    db.add(message)
    await db.flush()
    await db.refresh(message)

    # Eagerly load sender for response
    result = await db.execute(
        select(Message)
        .options(selectinload(Message.sender), selectinload(Message.reply_to))
        .where(Message.id == message.id)
    )
    return result.scalar_one()


async def get_message_history(
    db: AsyncSession, group_id: int, page: int = 1, page_size: int = 50
) -> Tuple[List[Message], int]:
    offset = (page - 1) * page_size

    count_result = await db.execute(
        select(func.count()).where(
            Message.group_id == group_id,
            Message.is_deleted == False,
        )
    )
    total = count_result.scalar_one()

    result = await db.execute(
        select(Message)
        .options(selectinload(Message.sender))
        .where(Message.group_id == group_id, Message.is_deleted == False)
        .order_by(Message.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    messages = result.scalars().all()
    return list(reversed(messages)), total


async def soft_delete_message(
    db: AsyncSession, message_id: int, staff_id: int
) -> Message:
    result = await db.execute(select(Message).where(Message.id == message_id))
    message = result.scalar_one_or_none()

    if not message:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found.")

    if message.sender_id != staff_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only delete your own messages.",
        )

    message.is_deleted = True
    await db.flush()
    return message


async def mark_messages_read(
    db: AsyncSession, group_id: int, staff_id: int
) -> None:
    # Get unread message IDs for this staff in this group
    already_read_subq = (
        select(MessageReadReceipt.message_id)
        .where(MessageReadReceipt.staff_id == staff_id)
        .scalar_subquery()
    )
    unread_result = await db.execute(
        select(Message.id).where(
            Message.group_id == group_id,
            Message.sender_id != staff_id,
            Message.is_deleted == False,
            Message.id.not_in(already_read_subq),
        )
    )
    unread_ids = unread_result.scalars().all()

    for msg_id in unread_ids:
        db.add(MessageReadReceipt(message_id=msg_id, staff_id=staff_id))

    await db.flush()