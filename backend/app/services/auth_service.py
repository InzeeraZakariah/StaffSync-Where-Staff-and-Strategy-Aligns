from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from fastapi import HTTPException, status

from app.models.staff import Staff
from app.schemas.staff import (
    StaffRegisterRequest,
    StaffUpdateProfileRequest,
    AccountSettingsUpdateRequest,
    ChangePasswordRequest,
)
from app.core.security import hash_password, verify_password


# ─── Fetch helpers ────────────────────────────────────────────────────────────

async def get_staff_by_id(db: AsyncSession, staff_id: int) -> Optional[Staff]:
    result = await db.execute(select(Staff).where(Staff.id == staff_id))
    return result.scalar_one_or_none()


async def get_staff_by_email(db: AsyncSession, email: str) -> Optional[Staff]:
    result = await db.execute(select(Staff).where(Staff.email == email.lower()))
    return result.scalar_one_or_none()


async def get_staff_by_employee_id(db: AsyncSession, employee_id: str) -> Optional[Staff]:
    result = await db.execute(select(Staff).where(Staff.employee_id == employee_id))
    return result.scalar_one_or_none()


# ─── Register ────────────────────────────────────────────────────────────────

async def register_staff(db: AsyncSession, payload: StaffRegisterRequest) -> Staff:
    existing = await get_staff_by_email(db, payload.email)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A staff account with this email already exists.",
        )

    if payload.employee_id:
        existing_emp = await get_staff_by_employee_id(db, payload.employee_id)
        if existing_emp:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Employee ID is already registered.",
            )

    staff = Staff(
        full_name=payload.full_name,
        email=payload.email.lower(),
        hashed_password=hash_password(payload.password),
        phone=payload.phone,
        department=payload.department,
        designation=payload.designation,
        employee_id=payload.employee_id,
    )

    db.add(staff)
    await db.flush()
    await db.refresh(staff)
    return staff


# ─── Login ────────────────────────────────────────────────────────────────────

async def authenticate_staff(db: AsyncSession, email: str, password: str) -> Staff:
    staff = await get_staff_by_email(db, email)

    if not staff or not verify_password(password, staff.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password.",
        )

    if not staff.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account has been deactivated. Please contact admin.",
        )

    # Update last login timestamp
    staff.last_login_at = datetime.now(timezone.utc)
    await db.flush()
    return staff


# ─── Update Profile ───────────────────────────────────────────────────────────

async def update_staff_profile(
    db: AsyncSession, staff: Staff, payload: StaffUpdateProfileRequest
) -> Staff:
    update_data = payload.model_dump(exclude_unset=True)

    for field, value in update_data.items():
        setattr(staff, field, value)

    await db.flush()
    await db.refresh(staff)
    return staff


# ─── Update Avatar ────────────────────────────────────────────────────────────

async def update_staff_avatar(db: AsyncSession, staff: Staff, avatar_url: str) -> Staff:
    staff.avatar_url = avatar_url
    await db.flush()
    await db.refresh(staff)
    return staff


# ─── Account Settings ─────────────────────────────────────────────────────────

async def update_account_settings(
    db: AsyncSession, staff: Staff, payload: AccountSettingsUpdateRequest
) -> Staff:
    update_data = payload.model_dump(exclude_unset=True)

    for field, value in update_data.items():
        setattr(staff, field, value)

    await db.flush()
    await db.refresh(staff)
    return staff


# ─── Change Password ──────────────────────────────────────────────────────────

async def change_password(
    db: AsyncSession, staff: Staff, payload: ChangePasswordRequest
) -> None:
    if not verify_password(payload.current_password, staff.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect.",
        )

    if payload.current_password == payload.new_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be different from the current password.",
        )

    staff.hashed_password = hash_password(payload.new_password)
    await db.flush()