from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, Form, status
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.security import get_current_staff
from app.models.staff import Staff
from app.models.resource import ResourceType, ResourceVisibility
from app.schemas.resource import (
    ResourceCreateRequest,
    ResourceUpdateRequest,
    ResourceResponse,
    NoteCreateRequest,
    NoteUpdateRequest,
    NoteResponse,
    NoteEditHistoryResponse,
    MessageResponse,
    ShareToStaffRequest,
    ShareToGroupRequest,
    ResourceShareResponse,
)
from app.services.resource_service import (
    create_resource_link,
    upload_resource_file,
    get_resources,
    get_resource_by_id,
    increment_download_count,
    update_resource,
    delete_resource,
    create_note,
    get_notes_for_department,
    get_note_by_id,
    update_note,
    delete_note,
    get_note_edit_history,
    share_resource_to_staff,
    share_resource_to_groups,
    get_resources_shared_to_me,
    get_resource_shares,
    revoke_resource_share,
    get_resource_file_path,
)

router = APIRouter(prefix="/resources", tags=["Resource Sharing & Notes"])


# ── Static routes first ──────────────────────────────────────────

@router.post("/link", response_model=ResourceResponse, status_code=status.HTTP_201_CREATED)
async def share_link(
    payload: ResourceCreateRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    return await create_resource_link(db, current_staff.id, payload)


@router.post("/upload", response_model=ResourceResponse, status_code=status.HTTP_201_CREATED)
async def upload_file_resource(
    file: UploadFile = File(...),
    title: str = Form(...),
    description: Optional[str] = Form(None),
    resource_type: ResourceType = Form(...),
    visibility: ResourceVisibility = Form(ResourceVisibility.DEPARTMENT),
    department: Optional[str] = Form(None),
    tags: Optional[str] = Form(None),
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    staff_dept = (
        current_staff.department.value
        if hasattr(current_staff.department, 'value')
        else str(current_staff.department)
    )
    payload = ResourceCreateRequest(
        title=title,
        description=description,
        resource_type=resource_type,
        visibility=visibility,
        department=department or staff_dept,
        tags=tags,
    )
    return await upload_resource_file(db, current_staff.id, payload, file)


@router.get("/", response_model=List[ResourceResponse])
async def list_resources(
    resource_type: Optional[ResourceType] = Query(None),
    search: Optional[str] = Query(None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=50),
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    dept = (
        current_staff.department.value
        if hasattr(current_staff.department, 'value')
        else str(current_staff.department)
    )
    return await get_resources(
        db,
        staff_id=current_staff.id,
        staff_department=dept,
        resource_type=resource_type,
        search=search,
        page=page,
        page_size=page_size,
    )


@router.get("/shared-with-me", response_model=List[ResourceResponse])
async def get_shared_with_me(
    resource_type: Optional[ResourceType] = Query(None),
    search: Optional[str] = Query(None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=50),
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    return await get_resources_shared_to_me(
        db,
        staff_id=current_staff.id,
        resource_type=resource_type,
        search=search,
        page=page,
        page_size=page_size,
    )


@router.delete("/shares/{share_id}", response_model=MessageResponse)
async def revoke_share(
    share_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    await revoke_resource_share(db, share_id=share_id, requester_id=current_staff.id)
    return MessageResponse(message="Share revoked successfully.")


# ── Notes routes ─────────────────────────────────────────────────

@router.post("/notes", response_model=NoteResponse, status_code=status.HTTP_201_CREATED)
async def create_shared_note(
    payload: NoteCreateRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    # Always use the logged-in staff's department — ignore what frontend sends
    dept = (
        current_staff.department.value
        if hasattr(current_staff.department, 'value')
        else str(current_staff.department)
    )
    payload.department = dept
    return await create_note(db, current_staff.id, payload)


@router.get("/notes", response_model=List[NoteResponse])
async def list_department_notes(
    department: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    pinned_first: bool = Query(default=True),
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    dept = (
        current_staff.department.value
        if hasattr(current_staff.department, 'value')
        else str(current_staff.department)
    )
    target_dept = department or dept
    return await get_notes_for_department(db, target_dept, search, pinned_first)


@router.get("/notes/{note_id}", response_model=NoteResponse)
async def get_note(
    note_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    note = await get_note_by_id(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found.")
    return note


@router.patch("/notes/{note_id}", response_model=NoteResponse)
async def edit_note(
    note_id: int,
    payload: NoteUpdateRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    note = await get_note_by_id(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found.")
    dept = (
        current_staff.department.value
        if hasattr(current_staff.department, 'value')
        else str(current_staff.department)
    )
    if note.department.lower() != dept.lower() and not current_staff.is_admin:
        raise HTTPException(status_code=403, detail="You can only edit notes from your department.")
    return await update_note(db, note, current_staff.id, payload)


@router.delete("/notes/{note_id}", response_model=MessageResponse)
async def delete_shared_note(
    note_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    note = await get_note_by_id(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found.")
    if note.created_by != current_staff.id and not current_staff.is_admin:
        raise HTTPException(status_code=403, detail="Only the note creator can delete it.")
    await delete_note(db, note)
    return MessageResponse(message="Note deleted successfully.")


@router.get("/notes/{note_id}/history", response_model=List[NoteEditHistoryResponse])
async def get_note_history(
    note_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    note = await get_note_by_id(db, note_id)
    if not note:
        raise HTTPException(status_code=404, detail="Note not found.")
    return await get_note_edit_history(db, note_id)


# ── Parameterised routes last ─────────────────────────────────────

@router.get("/{resource_id}", response_model=ResourceResponse)
async def get_resource(
    resource_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    resource = await get_resource_by_id(db, resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found.")
    return resource


@router.patch("/{resource_id}", response_model=ResourceResponse)
async def update_resource_info(
    resource_id: int,
    payload: ResourceUpdateRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    resource = await get_resource_by_id(db, resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found.")
    if resource.uploaded_by != current_staff.id and not current_staff.is_admin:
        raise HTTPException(status_code=403, detail="Only the uploader can edit this resource.")
    return await update_resource(db, resource, payload)


@router.delete("/{resource_id}", response_model=MessageResponse)
async def remove_resource(
    resource_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    resource = await get_resource_by_id(db, resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found.")
    if resource.uploaded_by != current_staff.id and not current_staff.is_admin:
        raise HTTPException(status_code=403, detail="Only the uploader can delete this resource.")
    await delete_resource(db, resource)
    return MessageResponse(message="Resource removed successfully.")


@router.post("/{resource_id}/download", response_model=MessageResponse)
async def track_download(
    resource_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    resource = await get_resource_by_id(db, resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found.")
    await increment_download_count(db, resource_id)
    return MessageResponse(message="Download tracked.")


@router.get("/{resource_id}/download/file")
async def download_resource_file(
    resource_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    file_path, filename = await get_resource_file_path(
        db,
        resource_id=resource_id,
        requester_staff_id=current_staff.id,
        requester_department=(
            current_staff.department.value
            if hasattr(current_staff.department, 'value')
            else str(current_staff.department)
        ),
    )
    return FileResponse(path=file_path, filename=filename, media_type="application/octet-stream")


@router.post("/{resource_id}/share/staff", response_model=List[ResourceShareResponse], status_code=status.HTTP_201_CREATED)
async def share_to_staff(
    resource_id: int,
    payload: ShareToStaffRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    shares = await share_resource_to_staff(
        db, resource_id=resource_id,
        sharer_id=current_staff.id, staff_ids=payload.staff_ids,
    )
    # Notify each staff member
    from sqlalchemy import select as sql_select
    from app.models.staff import Staff as StaffModel
    from app.services.fcm_service import send_multicast_notification
    resource = await get_resource_by_id(db, resource_id)
    tokens_result = await db.execute(
        sql_select(StaffModel.fcm_token).where(
            StaffModel.id.in_(payload.staff_ids),
            StaffModel.fcm_token.isnot(None),
            StaffModel.push_notifications_enabled == True,
        )
    )
    tokens = [r[0] for r in tokens_result.fetchall()]
    if tokens:
        await send_multicast_notification(
            fcm_tokens=tokens,
            title=f"📎 New Resource: {resource.title}",
            body=f"{current_staff.full_name} shared a resource with you.",
            data={"type": "resource_shared", "resource_id": str(resource_id)},
        )
    return shares


@router.post("/{resource_id}/share/groups", response_model=List[ResourceShareResponse], status_code=status.HTTP_201_CREATED)
async def share_to_groups(
    resource_id: int,
    payload: ShareToGroupRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    shares = await share_resource_to_groups(
        db, resource_id=resource_id,
        sharer_id=current_staff.id, group_ids=payload.group_ids,
    )
    resource = await get_resource_by_id(db, resource_id)
    from sqlalchemy import select as sql_select
    from app.models.group import group_members
    from app.models.staff import Staff as StaffModel
    from app.services.fcm_service import send_multicast_notification
    for group_id in payload.group_ids:
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
                await send_multicast_notification(
                    fcm_tokens=tokens,
                    title=f"📎 New Resource: {resource.title}",
                    body=f"{current_staff.full_name} shared a resource with your group.",
                    data={"type": "resource_shared", "resource_id": str(resource_id)},
                )
    return shares


@router.get("/{resource_id}/shares", response_model=List[ResourceShareResponse])
async def list_resource_shares(
    resource_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    resource = await get_resource_by_id(db, resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found.")
    if resource.uploaded_by != current_staff.id and not current_staff.is_admin:
        raise HTTPException(status_code=403, detail="Only the uploader can view share details.")
    return await get_resource_shares(db, resource_id)