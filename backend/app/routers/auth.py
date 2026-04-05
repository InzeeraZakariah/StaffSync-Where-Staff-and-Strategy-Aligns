import os
import uuid
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    get_current_staff,
)
from app.core.config import settings
from app.schemas.staff import (
    StaffRegisterRequest,
    StaffLoginRequest,
    TokenResponse,
    RefreshTokenRequest,
    StaffProfileResponse,
    StaffUpdateProfileRequest,
    AccountSettingsUpdateRequest,
    ChangePasswordRequest,
    MessageResponse,
)
from app.services.auth_service import (
    register_staff,
    authenticate_staff,
    update_staff_profile,
    update_staff_avatar,
    update_account_settings,
    change_password,
    get_staff_by_id,
)
from app.models.staff import Staff

router = APIRouter(prefix="/auth", tags=["Authentication & Profile"])


# ─── Register ────────────────────────────────────────────────────────────────

@router.post("/register", response_model=StaffProfileResponse, status_code=status.HTTP_201_CREATED)
async def register(payload: StaffRegisterRequest, db: AsyncSession = Depends(get_db)):
    """Register a new staff member."""
    staff = await register_staff(db, payload)
    return staff


# ─── Login ────────────────────────────────────────────────────────────────────

@router.post("/login", response_model=TokenResponse)
async def login(payload: StaffLoginRequest, db: AsyncSession = Depends(get_db)):
    """Login with email and password. Returns access & refresh tokens."""
    staff = await authenticate_staff(db, payload.email, payload.password)

    access_token = create_access_token(
        data={"sub": str(staff.id)},
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
    )
    refresh_token = create_refresh_token(data={"sub": str(staff.id)})

    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


# ─── Refresh Token ────────────────────────────────────────────────────────────

@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(payload: RefreshTokenRequest, db: AsyncSession = Depends(get_db)):
    """Get a new access token using a valid refresh token."""
    token_data = decode_token(payload.refresh_token)

    if token_data.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type. Provide a refresh token.",
        )

    staff_id = token_data.get("sub")
    staff = await get_staff_by_id(db, int(staff_id))

    if not staff or not staff.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Staff not found or inactive.",
        )

    new_access_token = create_access_token(data={"sub": str(staff.id)})
    new_refresh_token = create_refresh_token(data={"sub": str(staff.id)})

    return TokenResponse(access_token=new_access_token, refresh_token=new_refresh_token)


# ─── Get My Profile ───────────────────────────────────────────────────────────

@router.get("/me", response_model=StaffProfileResponse)
async def get_my_profile(current_staff: Staff = Depends(get_current_staff)):
    """Get the logged-in staff's full profile."""
    return current_staff


# ─── Update Profile ───────────────────────────────────────────────────────────

@router.patch("/me", response_model=StaffProfileResponse)
async def update_my_profile(
    payload: StaffUpdateProfileRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Update profile fields (partial update supported)."""
    updated_staff = await update_staff_profile(db, current_staff, payload)
    return updated_staff


# ─── Upload Avatar ────────────────────────────────────────────────────────────

@router.post("/me/avatar", response_model=StaffProfileResponse)
async def upload_avatar(
    file: UploadFile = File(...),
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Upload a profile avatar image (JPEG/PNG, max 10MB)."""
    allowed_types = {"image/jpeg", "image/png", "image/webp"}
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Only JPEG, PNG, and WEBP images are allowed.",
        )

    content = await file.read()
    max_bytes = settings.MAX_FILE_SIZE_MB * 1024 * 1024
    if len(content) > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File size exceeds the {settings.MAX_FILE_SIZE_MB}MB limit.",
        )

    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    ext = file.filename.rsplit(".", 1)[-1]
    filename = f"{current_staff.id}_{uuid.uuid4().hex}.{ext}"
    filepath = os.path.join(settings.UPLOAD_DIR, filename)

    with open(filepath, "wb") as f:
        f.write(content)

    avatar_url = f"/static/avatars/{filename}"
    updated_staff = await update_staff_avatar(db, current_staff, avatar_url)
    return updated_staff


# ─── Account Settings ─────────────────────────────────────────────────────────

@router.patch("/me/settings", response_model=StaffProfileResponse)
async def update_settings(
    payload: AccountSettingsUpdateRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Update account settings like notification preferences."""
    updated_staff = await update_account_settings(db, current_staff, payload)
    return updated_staff


# ─── Change Password ──────────────────────────────────────────────────────────

@router.post("/me/change-password", response_model=MessageResponse)
async def change_my_password(
    payload: ChangePasswordRequest,
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Change password by providing current and new password."""
    await change_password(db, current_staff, payload)
    return MessageResponse(message="Password updated successfully.")