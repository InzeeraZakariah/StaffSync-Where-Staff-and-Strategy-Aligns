import os
import uuid
from typing import List, Optional

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, update, or_, func
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, UploadFile, status

from app.models.resource import Resource, Note, NoteEditHistory, ResourceType, ResourceVisibility, ResourceShare
from app.models.group import group_members
from app.schemas.resource import (
    ResourceCreateRequest, ResourceUpdateRequest,
    NoteCreateRequest, NoteUpdateRequest,
)
from app.core.config import settings


# ══════════════════════════════════════════════════════════════════
#   ALLOWED MIME TYPES
# ══════════════════════════════════════════════════════════════════

ALLOWED_MIME_TYPES = {
    "pdf": ["application/pdf"],
    "ppt": [
        "application/vnd.ms-powerpoint",
        "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    ],
    "image": ["image/jpeg", "image/png", "image/webp", "image/gif"],
    "video": ["video/mp4", "video/mpeg", "video/quicktime", "video/webm"],
    "document": [
        "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "text/plain",
    ],
}


# ══════════════════════════════════════════════════════════════════
#   CREATE RESOURCE — LINK
# ══════════════════════════════════════════════════════════════════

async def create_resource_link(
    db: AsyncSession,
    staff_id: int,
    payload: ResourceCreateRequest,
) -> Resource:
    if payload.resource_type != ResourceType.LINK:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Use the upload endpoint for file resources.",
        )
    if not payload.link_url:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="link_url is required for link type resources.",
        )

    resource = Resource(
        uploaded_by=staff_id,
        title=payload.title,
        description=payload.description,
        resource_type=ResourceType.LINK,
        visibility=payload.visibility,
        # ── FIX: normalise department to lowercase to match DB values ──
        department=payload.department.lower().strip() if payload.department else None,
        link_url=str(payload.link_url),
        tags=payload.tags,
    )
    db.add(resource)
    await db.flush()
    await db.refresh(resource)
    return resource


# ══════════════════════════════════════════════════════════════════
#   CREATE RESOURCE — FILE UPLOAD
# ══════════════════════════════════════════════════════════════════

async def upload_resource_file(
    db: AsyncSession,
    staff_id: int,
    payload: ResourceCreateRequest,
    file: UploadFile,
) -> Resource:
    resource_type = payload.resource_type
    if resource_type == ResourceType.LINK:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Use the link endpoint for URL resources.",
        )

    allowed = ALLOWED_MIME_TYPES.get(resource_type.value, [])
    if file.content_type not in allowed:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Invalid file type for {resource_type.value}. Allowed: {allowed}",
        )

    content = await file.read()
    max_bytes = settings.MAX_FILE_SIZE_MB * 1024 * 1024
    if len(content) > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File exceeds {settings.MAX_FILE_SIZE_MB}MB limit.",
        )

    upload_dir = f"uploads/resources/{resource_type.value}"
    os.makedirs(upload_dir, exist_ok=True)
    ext = file.filename.rsplit(".", 1)[-1] if "." in file.filename else "bin"
    filename = f"{staff_id}_{uuid.uuid4().hex}.{ext}"
    filepath = os.path.join(upload_dir, filename)

    with open(filepath, "wb") as f:
        f.write(content)

    file_url = f"/static/resources/{resource_type.value}/{filename}"

    resource = Resource(
        uploaded_by=staff_id,
        title=payload.title,
        description=payload.description,
        resource_type=resource_type,
        visibility=payload.visibility,
        # ── FIX: normalise department ──
        department=payload.department.lower().strip() if payload.department else None,
        file_url=file_url,
        file_name=file.filename,
        file_size_bytes=len(content),
        mime_type=file.content_type,
        tags=payload.tags,
    )
    db.add(resource)
    await db.flush()
    await db.refresh(resource)
    return resource


# ══════════════════════════════════════════════════════════════════
#   GET RESOURCES — visible to current staff
#
#   FIX: case-insensitive department comparison using func.lower()
#   FIX: uploader always sees their own resources regardless of dept
# ══════════════════════════════════════════════════════════════════

async def get_resources(
    db: AsyncSession,
    staff_id: int,
    staff_department: str,
    resource_type: Optional[ResourceType] = None,
    search: Optional[str] = None,
    page: int = 1,
    page_size: int = 20,
) -> List[Resource]:
    # Normalise the department string for comparison
    dept_lower = staff_department.lower().strip()

    conditions = [
        Resource.is_active == True,
        (
            # All-staff resources
            (Resource.visibility == ResourceVisibility.ALL_STAFF) |
            # Department resources — case-insensitive match
            (
                (Resource.visibility == ResourceVisibility.DEPARTMENT) &
                (func.lower(Resource.department) == dept_lower)
            ) |
            # Uploader always sees their own resources
            (Resource.uploaded_by == staff_id)
        ),
    ]

    if resource_type:
        conditions.append(Resource.resource_type == resource_type)

    if search:
        conditions.append(
            Resource.title.ilike(f"%{search}%") |
            Resource.description.ilike(f"%{search}%") |
            Resource.tags.ilike(f"%{search}%")
        )

    result = await db.execute(
        select(Resource)
        .options(selectinload(Resource.uploader))
        .where(and_(*conditions))
        .order_by(Resource.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return result.scalars().all()


async def get_resource_by_id(db: AsyncSession, resource_id: int) -> Optional[Resource]:
    result = await db.execute(
        select(Resource)
        .options(selectinload(Resource.uploader))
        .where(Resource.id == resource_id, Resource.is_active == True)
    )
    return result.scalar_one_or_none()


async def increment_download_count(db: AsyncSession, resource_id: int) -> None:
    await db.execute(
        update(Resource)
        .where(Resource.id == resource_id)
        .values(download_count=Resource.download_count + 1)
    )
    await db.flush()


async def update_resource(
    db: AsyncSession, resource: Resource, payload: ResourceUpdateRequest
) -> Resource:
    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(resource, field, value)
    await db.flush()
    await db.refresh(resource)
    return resource


async def delete_resource(db: AsyncSession, resource: Resource) -> None:
    resource.is_active = False
    await db.flush()


# ══════════════════════════════════════════════════════════════════
#   NOTES
# ══════════════════════════════════════════════════════════════════

async def create_note(
    db: AsyncSession, staff_id: int, payload: NoteCreateRequest
) -> Note:
    note = Note(
        created_by=staff_id,
        title=payload.title,
        content=payload.content,
        # Normalise department
        department=payload.department.lower().strip(),
        tags=payload.tags,
        is_pinned=payload.is_pinned,
        last_edited_by=staff_id,
    )
    db.add(note)
    await db.flush()
    await db.refresh(note)
    return note


async def get_notes_for_department(
    db: AsyncSession,
    department: str,
    search: Optional[str] = None,
    pinned_first: bool = True,
) -> List[Note]:
    dept_lower = department.lower().strip()

    # FIX: case-insensitive department match
    conditions = [
        func.lower(Note.department) == dept_lower,
        Note.is_active == True,
    ]

    if search:
        conditions.append(
            Note.title.ilike(f"%{search}%") |
            Note.content.ilike(f"%{search}%") |
            Note.tags.ilike(f"%{search}%")
        )

    query = (
        select(Note)
        .options(selectinload(Note.creator), selectinload(Note.editor))
        .where(and_(*conditions))
    )

    if pinned_first:
        query = query.order_by(Note.is_pinned.desc(), Note.updated_at.desc())
    else:
        query = query.order_by(Note.updated_at.desc())

    result = await db.execute(query)
    return result.scalars().all()


async def get_note_by_id(db: AsyncSession, note_id: int) -> Optional[Note]:
    result = await db.execute(
        select(Note)
        .options(selectinload(Note.creator), selectinload(Note.editor))
        .where(Note.id == note_id, Note.is_active == True)
    )
    return result.scalar_one_or_none()


async def update_note(
    db: AsyncSession, note: Note, staff_id: int, payload: NoteUpdateRequest
) -> Note:
    if payload.content and payload.content != note.content:
        history = NoteEditHistory(
            note_id=note.id,
            edited_by=staff_id,
            previous_content=note.content,
        )
        db.add(history)

    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(note, field, value)

    note.last_edited_by = staff_id
    await db.flush()
    await db.refresh(note)
    return note


async def delete_note(db: AsyncSession, note: Note) -> None:
    note.is_active = False
    await db.flush()


async def get_note_edit_history(
    db: AsyncSession, note_id: int
) -> List[NoteEditHistory]:
    result = await db.execute(
        select(NoteEditHistory)
        .where(NoteEditHistory.note_id == note_id)
        .order_by(NoteEditHistory.edited_at.desc())
    )
    return result.scalars().all()


# ══════════════════════════════════════════════════════════════════
#   SHARING
# ══════════════════════════════════════════════════════════════════

async def share_resource_to_staff(
    db: AsyncSession,
    resource_id: int,
    sharer_id: int,
    staff_ids: List[int],
) -> List[ResourceShare]:
    resource = await get_resource_by_id(db, resource_id)
    if not resource:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Resource not found.")

    created = []
    for staff_id in staff_ids:
        existing = await db.execute(
            select(ResourceShare).where(
                and_(
                    ResourceShare.resource_id == resource_id,
                    ResourceShare.shared_to_staff_id == staff_id,
                )
            )
        )
        if existing.scalar_one_or_none():
            continue
        share = ResourceShare(
            resource_id=resource_id,
            shared_to_staff_id=staff_id,
            shared_by=sharer_id,
        )
        db.add(share)
        created.append(share)

    await db.flush()
    for s in created:
        await db.refresh(s)
    return created


async def share_resource_to_groups(
    db: AsyncSession,
    resource_id: int,
    sharer_id: int,
    group_ids: List[int],
) -> List[ResourceShare]:
    resource = await get_resource_by_id(db, resource_id)
    if not resource:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Resource not found.")

    created = []
    for group_id in group_ids:
        existing = await db.execute(
            select(ResourceShare).where(
                and_(
                    ResourceShare.resource_id == resource_id,
                    ResourceShare.shared_to_group_id == group_id,
                )
            )
        )
        if existing.scalar_one_or_none():
            continue
        share = ResourceShare(
            resource_id=resource_id,
            shared_to_group_id=group_id,
            shared_by=sharer_id,
        )
        db.add(share)
        created.append(share)

    await db.flush()
    for s in created:
        await db.refresh(s)
    return created


async def get_resources_shared_to_me(
    db: AsyncSession,
    staff_id: int,
    resource_type: Optional[ResourceType] = None,
    search: Optional[str] = None,
    page: int = 1,
    page_size: int = 20,
) -> List[Resource]:
    group_result = await db.execute(
        select(group_members.c.group_id).where(
            group_members.c.staff_id == staff_id
        )
    )
    my_group_ids = [row[0] for row in group_result.fetchall()]

    share_conditions = [ResourceShare.shared_to_staff_id == staff_id]
    if my_group_ids:
        share_conditions.append(ResourceShare.shared_to_group_id.in_(my_group_ids))

    shared_resource_ids_subq = (
        select(ResourceShare.resource_id)
        .where(or_(*share_conditions))
        .scalar_subquery()
    )

    conditions = [
        Resource.is_active == True,
        Resource.id.in_(shared_resource_ids_subq),
    ]

    if resource_type:
        conditions.append(Resource.resource_type == resource_type)

    if search:
        conditions.append(
            Resource.title.ilike(f"%{search}%") |
            Resource.description.ilike(f"%{search}%") |
            Resource.tags.ilike(f"%{search}%")
        )

    result = await db.execute(
        select(Resource)
        .options(selectinload(Resource.uploader))
        .where(and_(*conditions))
        .order_by(Resource.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return result.scalars().all()


async def get_resource_shares(
    db: AsyncSession,
    resource_id: int,
) -> List[ResourceShare]:
    result = await db.execute(
        select(ResourceShare)
        .where(ResourceShare.resource_id == resource_id)
        .order_by(ResourceShare.shared_at.desc())
    )
    return result.scalars().all()


async def revoke_resource_share(
    db: AsyncSession,
    share_id: int,
    requester_id: int,
) -> None:
    result = await db.execute(
        select(ResourceShare).where(ResourceShare.id == share_id)
    )
    share = result.scalar_one_or_none()
    if not share:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Share record not found.")
    if share.shared_by != requester_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the original sharer can revoke this share.",
        )
    await db.delete(share)
    await db.flush()


def resolve_file_path(file_url: str) -> str:
    relative = file_url.lstrip("/")
    parts = relative.split("/", 1)
    if len(parts) == 2:
        return os.path.join("uploads", parts[1])
    return relative


async def get_resource_file_path(
    db: AsyncSession,
    resource_id: int,
    requester_staff_id: int,
    requester_department: str,
) -> tuple[str, str]:
    resource = await get_resource_by_id(db, resource_id)
    if not resource:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Resource not found.")

    if not resource.file_url:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This resource is a link — open it using link_url.",
        )

    has_access = False

    if resource.visibility == ResourceVisibility.ALL_STAFF:
        has_access = True
    elif resource.visibility == ResourceVisibility.DEPARTMENT:
        # FIX: case-insensitive department check
        has_access = (
            resource.department is not None and
            resource.department.lower().strip() ==
            requester_department.lower().strip()
        )
    elif resource.visibility == ResourceVisibility.PRIVATE:
        if resource.uploaded_by == requester_staff_id:
            has_access = True
        else:
            group_result = await db.execute(
                select(group_members.c.group_id).where(
                    group_members.c.staff_id == requester_staff_id
                )
            )
            my_group_ids = [row[0] for row in group_result.fetchall()]
            share_conditions = [ResourceShare.shared_to_staff_id == requester_staff_id]
            if my_group_ids:
                share_conditions.append(ResourceShare.shared_to_group_id.in_(my_group_ids))
            share_result = await db.execute(
                select(ResourceShare).where(
                    and_(
                        ResourceShare.resource_id == resource_id,
                        or_(*share_conditions),
                    )
                )
            )
            has_access = share_result.scalar_one_or_none() is not None

    # Uploader always has access
    if resource.uploaded_by == requester_staff_id:
        has_access = True

    if not has_access:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to download this resource.",
        )

    file_path = resolve_file_path(resource.file_url)
    if not os.path.exists(file_path):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="File not found on server.",
        )

    filename = resource.file_name or os.path.basename(file_path)
    await increment_download_count(db, resource_id)
    return file_path, filename