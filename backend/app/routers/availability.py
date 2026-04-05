from typing import List, Optional
from datetime import date, time

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.security import get_current_staff
from app.models.staff import Staff
from app.schemas.availability import (
    AvailabilityCreateRequest,
    AvailabilityUpdateRequest,
    AvailabilityResponse,
    StaffAvailabilityCheckRequest,
    StaffAvailabilityCheckResponse,
    BulkAvailabilityCheckRequest,
    BulkAvailabilityCheckResponse,
    MessageResponse,
)
from app.services.availability_service import (
    create_availability,
    get_availability_by_id,
    get_my_availability,
    get_staff_availability_on_date,
    update_availability,
    delete_availability,
    check_staff_availability,
    bulk_check_availability,
)

router = APIRouter(prefix="/availability", tags=["Availability"])


# ─── Create Availability ──────────────────────────────────────────────────────

@router.post("/", response_model=AvailabilityResponse, status_code=status.HTTP_201_CREATED)
async def set_availability(
    payload: AvailabilityCreateRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """
    Set your availability.
    - TIME_SLOT: specific date + start/end time (e.g. 25th Nov, 12 PM – 3 PM)
    - FULL_DAY: entire day unavailable
    - MULTI_DAY: range of days (e.g. 25th Nov – 27th Nov)
    """
    availability = await create_availability(db, current_staff.id, payload)
    return availability


# ─── Get My Availability ──────────────────────────────────────────────────────

@router.get("/me", response_model=List[AvailabilityResponse])
async def get_my_availability_slots(
    from_date: Optional[date] = Query(None, description="Filter from this date"),
    to_date: Optional[date] = Query(None, description="Filter up to this date"),
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Get all your availability entries, optionally filtered by date range."""
    slots = await get_my_availability(db, current_staff.id, from_date, to_date)
    return slots


# ─── Get Another Staff's Availability ────────────────────────────────────────

@router.get("/staff/{staff_id}", response_model=List[AvailabilityResponse])
async def get_staff_availability(
    staff_id: int,
    check_date: date = Query(..., description="The date to check"),
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """
    View another staff member's availability on a specific date.
    Respects the staff's privacy setting (show_availability_to_others).
    """
    from app.services.auth_service import get_staff_by_id
    target_staff = await get_staff_by_id(db, staff_id)

    if not target_staff:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Staff not found.")

    if not target_staff.show_availability_to_others and not current_staff.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This staff member has set their availability to private.",
        )

    slots = await get_staff_availability_on_date(db, staff_id, check_date)
    return slots


# ─── Update Availability ──────────────────────────────────────────────────────

@router.patch("/{availability_id}", response_model=AvailabilityResponse)
async def update_my_availability(
    availability_id: int,
    payload: AvailabilityUpdateRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Update an existing availability entry."""
    availability = await get_availability_by_id(db, availability_id)

    if not availability:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Availability entry not found.")

    if availability.staff_id != current_staff.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You can only update your own availability.")

    updated = await update_availability(db, availability, payload)
    return updated


# ─── Delete Availability ──────────────────────────────────────────────────────

@router.delete("/{availability_id}", response_model=MessageResponse)
async def delete_my_availability(
    availability_id: int,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Delete an availability entry."""
    availability = await get_availability_by_id(db, availability_id)

    if not availability:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Availability entry not found.")

    if availability.staff_id != current_staff.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You can only delete your own availability.")

    await delete_availability(db, availability)
    return MessageResponse(message="Availability entry deleted successfully.")


# ─── Check Single Staff Availability ─────────────────────────────────────────

@router.post("/check", response_model=StaffAvailabilityCheckResponse)
async def check_availability(
    payload: StaffAvailabilityCheckRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """
    Check if a specific staff member is available on a given date/time.
    Used internally by the Meeting AI before scheduling.
    """
    is_available, conflicts = await check_staff_availability(
        db, payload.staff_id, payload.check_date, payload.check_time
    )
    return StaffAvailabilityCheckResponse(
        staff_id=payload.staff_id,
        is_available=is_available,
        conflicting_slots=conflicts,
    )


# ─── Bulk Availability Check ──────────────────────────────────────────────────

@router.post("/check/bulk", response_model=BulkAvailabilityCheckResponse)
async def bulk_check(
    payload: BulkAvailabilityCheckRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """
    Check availability for multiple staff members at once.
    The Meeting AI uses this to determine who needs a bot to attend on their behalf.
    """
    results = await bulk_check_availability(
        db, payload.staff_ids, payload.check_date, payload.check_time
    )
    return BulkAvailabilityCheckResponse(
        check_date=payload.check_date,
        check_time=payload.check_time,
        results=results,
    )