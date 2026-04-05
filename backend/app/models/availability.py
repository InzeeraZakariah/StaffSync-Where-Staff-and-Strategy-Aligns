from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Enum, Text, Date, Time
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum

from app.db.session import Base


class AvailabilityType(str, enum.Enum):
    TIME_SLOT = "time_slot"      # e.g. 12 PM to 3 PM
    FULL_DAY = "full_day"        # entire day unavailable
    MULTI_DAY = "multi_day"      # multiple consecutive days


class AvailabilityStatus(str, enum.Enum):
    AVAILABLE = "available"
    UNAVAILABLE = "unavailable"
    BUSY = "busy"


class Availability(Base):
    __tablename__ = "availability"

    id = Column(Integer, primary_key=True, index=True)
    staff_id = Column(Integer, ForeignKey("staff.id", ondelete="CASCADE"), nullable=False, index=True)

    availability_type = Column(Enum(AvailabilityType), nullable=False)
    status = Column(Enum(AvailabilityStatus), nullable=False, default=AvailabilityStatus.UNAVAILABLE)

    # For TIME_SLOT: specific date + start/end time
    date = Column(Date, nullable=True)
    start_time = Column(Time, nullable=True)
    end_time = Column(Time, nullable=True)

    # For MULTI_DAY: date range
    start_date = Column(Date, nullable=True)
    end_date = Column(Date, nullable=True)

    reason = Column(Text, nullable=True)
    is_recurring = Column(Boolean, default=False)   # weekly recurring slot

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    staff = relationship("Staff", foreign_keys=[staff_id])