from pydantic import BaseModel, Field, model_validator
from typing import Optional, List
import datetime
from app.models.availability import AvailabilityType, AvailabilityStatus

# ─── Create ───────────────────────────────────────────────────────────────────

class AvailabilityCreateRequest(BaseModel):
    availability_type: AvailabilityType
    status: AvailabilityStatus = AvailabilityStatus.UNAVAILABLE

    # For TIME_SLOT
    date: Optional[datetime.date] = None
    start_time: Optional[datetime.time] = None
    end_time: Optional[datetime.time] = None

    # For MULTI_DAY / FULL_DAY
    start_date: Optional[datetime.date] = None
    end_date: Optional[datetime.date] = None

    reason: Optional[str] = Field(None, max_length=300)
    is_recurring: bool = False

    @model_validator(mode="after")
    def validate_fields(self):
        if self.availability_type == AvailabilityType.TIME_SLOT:
            if not self.date:
                raise ValueError("date is required for time_slot availability.")
            if not self.start_time or not self.end_time:
                raise ValueError("start_time and end_time are required for time_slot.")
            if self.start_time >= self.end_time:
                raise ValueError("start_time must be before end_time.")

        if self.availability_type == AvailabilityType.FULL_DAY:
            if not self.date:
                raise ValueError("date is required for full_day availability.")

        if self.availability_type == AvailabilityType.MULTI_DAY:
            if not self.start_date or not self.end_date:
                raise ValueError("start_date and end_date are required for multi_day.")
            if self.start_date > self.end_date:
                raise ValueError("start_date must be before or equal to end_date.")

        return self


# ─── Update ───────────────────────────────────────────────────────────────────

class AvailabilityUpdateRequest(BaseModel):
    status: Optional[AvailabilityStatus] = None
    date: Optional[datetime.date] = None
    start_time: Optional[datetime.time] = None
    end_time: Optional[datetime.time] = None
    start_date: Optional[datetime.date] = None
    end_date: Optional[datetime.date] = None
    reason: Optional[str] = Field(None, max_length=300)
    is_recurring: Optional[bool] = None


# ─── Response ─────────────────────────────────────────────────────────────────

class AvailabilityResponse(BaseModel):
    id: int
    staff_id: int
    availability_type: AvailabilityType
    status: AvailabilityStatus
    date: Optional[datetime.date]
    start_time: Optional[datetime.time]
    end_time: Optional[datetime.time]
    start_date: Optional[datetime.date]
    end_date: Optional[datetime.date]
    reason: Optional[str]
    is_recurring: bool
    created_at: datetime.datetime
    updated_at: datetime.datetime

    model_config = {"from_attributes": True}


# ─── Staff Availability Check (used by Meeting AI) ────────────────────────────

class StaffAvailabilityCheckRequest(BaseModel):
    staff_id: int
    check_date: datetime.date
    check_time: Optional[datetime.time] = None


class StaffAvailabilityCheckResponse(BaseModel):
    staff_id: int
    is_available: bool
    conflicting_slots: List[AvailabilityResponse]


# ─── Bulk Check (used by Meeting AI to check multiple staff) ─────────────────

class BulkAvailabilityCheckRequest(BaseModel):
    staff_ids: List[int] = Field(..., min_length=1)
    check_date: datetime.date
    check_time: Optional[datetime.time] = None


class StaffAvailabilitySummary(BaseModel):
    staff_id: int
    full_name: str
    is_available: bool


class BulkAvailabilityCheckResponse(BaseModel):
    check_date: datetime.date
    check_time: Optional[datetime.time]
    results: List[StaffAvailabilitySummary]


class MessageResponse(BaseModel):
    message: str