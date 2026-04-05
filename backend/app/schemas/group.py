from pydantic import BaseModel
from typing import Optional, List, Dict, Any


class GroupCreateRequest(BaseModel):
    name: str
    description: Optional[str] = None
    department: Optional[str] = None
    member_ids: List[int] = []


class GroupUpdateRequest(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None


class StaffProfileResponse(BaseModel):
    id: int
    staff_id: int
    headline: Optional[str]
    about: Optional[str]
    linkedin_url: Optional[str]
    personal_website: Optional[str]
    office_location: Optional[str]
    achievements: List[Dict[str, Any]] = []
    publications: List[Dict[str, Any]] = []
    skills: List[str] = []
    education: List[Dict[str, Any]] = []
    experience: List[Dict[str, Any]] = []
    awards: List[Dict[str, Any]] = []

    model_config = {"from_attributes": True}


class StaffProfileUpdate(BaseModel):
    headline: Optional[str] = None
    about: Optional[str] = None
    linkedin_url: Optional[str] = None
    personal_website: Optional[str] = None
    office_location: Optional[str] = None
    skills: Optional[List[str]] = None
    education: Optional[List[Dict[str, Any]]] = None
    experience: Optional[List[Dict[str, Any]]] = None
    awards: Optional[List[Dict[str, Any]]] = None