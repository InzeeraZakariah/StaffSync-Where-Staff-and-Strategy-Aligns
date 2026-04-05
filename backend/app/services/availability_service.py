from typing import List, Optional, Tuple
from datetime import date, time
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, delete
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, status

from app.models.availability import Availability, AvailabilityType, AvailabilityStatus
from app.models.staff import Staff
from app.schemas.availability import (
    AvailabilityCreateRequest,
    AvailabilityUpdateRequest,
    StaffAvailabilitySummary,
)


# ─── Create ───────────────────────────────────────────────────────────────────

async def create_availability(
    db: AsyncSession, staff_id: int, payload: AvailabilityCreateRequest
) -> Availability:
    # Check for overlapping slots before creating
    conflicts = await _get_conflicts(db, staff_id, payload)
    if conflicts:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This availability slot overlaps with an existing entry.",
        )

    availability = Availability(
        staff_id=staff_id,
        availability_type=payload.availability_type,
        status=payload.status,
        date=payload.date,
        start_time=payload.start_time,
        end_time=payload.end_time,
        start_date=payload.start_date,
        end_date=payload.end_date,
        reason=payload.reason,
        is_recurring=payload.is_recurring,
    )
    db.add(availability)
    await db.flush()
    await db.refresh(availability)
    return availability


# ─── Read ─────────────────────────────────────────────────────────────────────

async def get_availability_by_id(
    db: AsyncSession, availability_id: int
) -> Optional[Availability]:
    result = await db.execute(
        select(Availability).where(Availability.id == availability_id)
    )
    return result.scalar_one_or_none()


async def get_my_availability(
    db: AsyncSession,
    staff_id: int,
    from_date: Optional[date] = None,
    to_date: Optional[date] = None,
) -> List[Availability]:
    conditions = [Availability.staff_id == staff_id]

    if from_date:
        conditions.append(
            or_(
                Availability.date >= from_date,
                Availability.start_date >= from_date,
            )
        )
    if to_date:
        conditions.append(
            or_(
                Availability.date <= to_date,
                Availability.end_date <= to_date,
            )
        )

    result = await db.execute(
        select(Availability)
        .where(and_(*conditions))
        .order_by(Availability.date.asc(), Availability.start_date.asc())
    )
    return result.scalars().all()


async def get_staff_availability_on_date(
    db: AsyncSession, staff_id: int, check_date: date
) -> List[Availability]:
    """Get all availability entries that cover a specific date."""
    result = await db.execute(
        select(Availability).where(
            Availability.staff_id == staff_id,
            or_(
                # TIME_SLOT or FULL_DAY on the exact date
                Availability.date == check_date,
                # MULTI_DAY covering the date
                and_(
                    Availability.start_date <= check_date,
                    Availability.end_date >= check_date,
                ),
            ),
        )
    )
    return result.scalars().all()


# ─── Update ───────────────────────────────────────────────────────────────────

async def update_availability(
    db: AsyncSession, availability: Availability, payload: AvailabilityUpdateRequest
) -> Availability:
    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(availability, field, value)
    await db.flush()
    await db.refresh(availability)
    return availability


# ─── Delete ───────────────────────────────────────────────────────────────────

async def delete_availability(db: AsyncSession, availability: Availability) -> None:
    await db.delete(availability)
    await db.flush()


# ─── Availability Check Logic ─────────────────────────────────────────────────

async def check_staff_availability(
    db: AsyncSession,
    staff_id: int,
    check_date: date,
    check_time: Optional[time] = None,
) -> Tuple[bool, List[Availability]]:
    """
    Returns (is_available, conflicting_slots).
    A staff is considered UNAVAILABLE if any of their entries
    mark them as UNAVAILABLE or BUSY for the given date/time.
    """
    entries = await get_staff_availability_on_date(db, staff_id, check_date)

    conflicting = []
    for entry in entries:
        if entry.status == AvailabilityStatus.AVAILABLE:
            continue  # explicitly marked available — no conflict

        if entry.availability_type == AvailabilityType.FULL_DAY:
            conflicting.append(entry)

        elif entry.availability_type == AvailabilityType.MULTI_DAY:
            conflicting.append(entry)

        elif entry.availability_type == AvailabilityType.TIME_SLOT:
            if check_time is None:
                conflicting.append(entry)
            elif entry.start_time <= check_time <= entry.end_time:
                conflicting.append(entry)

    is_available = len(conflicting) == 0
    return is_available, conflicting


async def bulk_check_availability(
    db: AsyncSession,
    staff_ids: List[int],
    check_date: date,
    check_time: Optional[time] = None,
) -> List[StaffAvailabilitySummary]:
    """Check availability for multiple staff members at once (used by Meeting AI)."""
    results = []
    for staff_id in staff_ids:
        staff_result = await db.execute(
            select(Staff).where(Staff.id == staff_id)
        )
        staff = staff_result.scalar_one_or_none()
        if not staff:
            continue

        is_available, _ = await check_staff_availability(
            db, staff_id, check_date, check_time
        )
        results.append(
            StaffAvailabilitySummary(
                staff_id=staff_id,
                full_name=staff.full_name,
                is_available=is_available,
            )
        )
    return results


# ─── Internal conflict checker ────────────────────────────────────────────────

async def _get_conflicts(
    db: AsyncSession, staff_id: int, payload: AvailabilityCreateRequest
) -> List[Availability]:
    """Check if a new availability entry conflicts with existing ones."""
    if payload.availability_type == AvailabilityType.TIME_SLOT:
        result = await db.execute(
            select(Availability).where(
                Availability.staff_id == staff_id,
                Availability.date == payload.date,
                Availability.availability_type == AvailabilityType.TIME_SLOT,
                or_(
                    and_(
                        Availability.start_time <= payload.start_time,
                        Availability.end_time > payload.start_time,
                    ),
                    and_(
                        Availability.start_time < payload.end_time,
                        Availability.end_time >= payload.end_time,
                    ),
                ),
            )
        )
        return result.scalars().all()

    if payload.availability_type == AvailabilityType.FULL_DAY:
        result = await db.execute(
            select(Availability).where(
                Availability.staff_id == staff_id,
                Availability.date == payload.date,
                Availability.availability_type == AvailabilityType.FULL_DAY,
            )
        )
        return result.scalars().all()

    if payload.availability_type == AvailabilityType.MULTI_DAY:
        result = await db.execute(
            select(Availability).where(
                Availability.staff_id == staff_id,
                Availability.availability_type == AvailabilityType.MULTI_DAY,
                Availability.start_date <= payload.end_date,
                Availability.end_date >= payload.start_date,
            )
        )
        return result.scalars().all()

    return []