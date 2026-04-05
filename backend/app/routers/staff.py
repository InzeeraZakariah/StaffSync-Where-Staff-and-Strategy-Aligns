# app/routers/staff.py
# FIXES:
#   1. get_all_staff now returns department, avatar_url, designation
#      (share picker needs full_name + department + avatar_url)
#   2. Added require auth so only logged-in staff can list other staff
#   3. get_staff_by_id endpoint added for profile screen

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List

from app.db.session import get_db
from app.models.staff import Staff
from app.core.security import get_current_staff

router = APIRouter(prefix="/staff", tags=["Staff"])


@router.get("/", response_model=List[dict])
async def get_all_staff(
    current_staff: Staff = Depends(get_current_staff),   # ← auth required
    db: AsyncSession = Depends(get_db),
):
    """
    Return all active staff members.
    Used by the share picker in the resource screen.
    """
    result = await db.execute(
        select(Staff).where(Staff.is_active == True).order_by(Staff.full_name)
    )
    staff_list = result.scalars().all()

    return [
        {
            "id":          s.id,
            "full_name":   s.full_name,
            "email":       s.email,
            # FIX: department is an enum — always return the .value string
            "department":  s.department.value
                           if hasattr(s.department, "value")
                           else str(s.department),
            "designation": s.designation.value
                           if hasattr(s.designation, "value")
                           else str(s.designation),
            "avatar_url":  s.avatar_url,
            "employee_id": s.employee_id,
        }
        for s in staff_list
    ]


@router.get("/{staff_id}", response_model=dict)
async def get_staff_by_id(
    staff_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Get a specific staff member's basic info."""
    from fastapi import HTTPException, status
    result = await db.execute(select(Staff).where(Staff.id == staff_id))
    s = result.scalar_one_or_none()
    if not s:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                            detail="Staff not found.")
    return {
        "id":          s.id,
        "full_name":   s.full_name,
        "email":       s.email,
        "department":  s.department.value if hasattr(s.department, "value") else str(s.department),
        "designation": s.designation.value if hasattr(s.designation, "value") else str(s.designation),
        "avatar_url":  s.avatar_url,
        "employee_id": s.employee_id,
        "bio":         s.bio,
        "is_admin":    s.is_admin,
    }