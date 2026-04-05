from pydantic import BaseModel, Field, HttpUrl
from typing import Optional, List
from datetime import datetime

from app.models.resource import ResourceType, ResourceVisibility


# ─── Resource Schemas ─────────────────────────────────────────────────────────

class ResourceCreateRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=250)
    description: Optional[str] = Field(None, max_length=1000)
    resource_type: ResourceType
    visibility: ResourceVisibility = ResourceVisibility.DEPARTMENT
    department: Optional[str] = Field(None, max_length=50)
    link_url: Optional[str] = Field(None, max_length=600)   # required if type=LINK
    tags: Optional[str] = Field(None, max_length=500)        # comma-separated


class ResourceUpdateRequest(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=250)
    description: Optional[str] = None
    visibility: Optional[ResourceVisibility] = None
    department: Optional[str] = None
    tags: Optional[str] = None


class UploaderResponse(BaseModel):
    id: int
    full_name: str
    department: str
    avatar_url: Optional[str]

    model_config = {"from_attributes": True}


class ResourceResponse(BaseModel):
    id: int
    uploaded_by: Optional[int]
    title: str
    description: Optional[str]
    resource_type: ResourceType
    visibility: ResourceVisibility
    department: Optional[str]
    file_url: Optional[str]
    file_name: Optional[str]
    file_size_bytes: Optional[int]
    mime_type: Optional[str]
    link_url: Optional[str]
    download_count: int
    tags: Optional[str]
    created_at: datetime
    uploader: Optional[UploaderResponse]

    model_config = {"from_attributes": True}


# ─── Note Schemas ─────────────────────────────────────────────────────────────

class NoteCreateRequest(BaseModel):
    title: str = Field(..., min_length=2, max_length=250)
    content: str = Field(..., min_length=1)
    department: str = Field(..., max_length=50)
    tags: Optional[str] = Field(None, max_length=500)
    is_pinned: bool = False


class NoteUpdateRequest(BaseModel):
    title: Optional[str] = Field(None, min_length=2, max_length=250)
    content: Optional[str] = Field(None, min_length=1)
    tags: Optional[str] = None
    is_pinned: Optional[bool] = None


class NoteEditorResponse(BaseModel):
    id: int
    full_name: str
    avatar_url: Optional[str]

    model_config = {"from_attributes": True}


class NoteResponse(BaseModel):
    id: int
    created_by: Optional[int]
    title: str
    content: str
    department: str
    tags: Optional[str]
    is_pinned: bool
    last_edited_by: Optional[int]
    created_at: datetime
    updated_at: datetime
    creator: Optional[NoteEditorResponse]
    editor: Optional[NoteEditorResponse]

    model_config = {"from_attributes": True}


class NoteEditHistoryResponse(BaseModel):
    id: int
    note_id: int
    edited_by: Optional[int]
    previous_content: str
    edited_at: datetime

    model_config = {"from_attributes": True}


class MessageResponse(BaseModel):
    message: str

class ShareToStaffRequest(BaseModel):
    """Body for POST /{resource_id}/share/staff"""
    staff_ids: List[int] = Field(..., min_length=1, description="Staff IDs to share with")
 
 
class ShareToGroupRequest(BaseModel):
    """Body for POST /{resource_id}/share/groups"""
    group_ids: List[int] = Field(..., min_length=1, description="Group IDs to share with")
  
class ResourceShareResponse(BaseModel):
    id: int
    resource_id: int
    shared_to_staff_id: Optional[int]
    shared_to_group_id: Optional[int]
    shared_by: Optional[int]
    shared_at: datetime

    model_config = {"from_attributes": True}