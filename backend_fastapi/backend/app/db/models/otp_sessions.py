"""
OTP Session model for tracking verification attempts.
"""
import uuid
import enum
from datetime import datetime
from sqlalchemy import String, Integer, Enum, TIMESTAMP, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from db.base import Base


class IdentifierType(str, enum.Enum):
    """Type of identifier being verified."""
    phone = "phone"
    email = "email"


class OTPSession(Base):
    """
    Tracks OTP verification sessions.
    
    Security features:
    - OTP is stored as a hash
    - Limited attempts (max 3)
    - Short expiry (5 minutes)
    - Tracks verification status
    """
    __tablename__ = "otp_sessions"

    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    
    # The phone number or email being verified
    identifier: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    identifier_type: Mapped[IdentifierType] = mapped_column(
        Enum(IdentifierType), nullable=False
    )
    
    # OTP stored as hash for security
    otp_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    
    # Attempt tracking (max 3)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    
    # Status
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    is_expired: Mapped[bool] = mapped_column(Boolean, default=False)
    
    # Timestamps
    expires_at: Mapped[datetime] = mapped_column(TIMESTAMP(timezone=True), nullable=False)
    verified_at: Mapped[datetime | None] = mapped_column(TIMESTAMP(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        TIMESTAMP(timezone=True), server_default=func.now()
    )
    
    # IP tracking for rate limiting
    ip_address: Mapped[str | None] = mapped_column(String(45))
