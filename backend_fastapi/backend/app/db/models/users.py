import uuid
from sqlalchemy import String, Boolean, TIMESTAMP, Enum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from db.base import Base
from db.enums import GenderEnum
from sqlalchemy.orm import relationship


class User(Base):
    """
    User model - passwordless authentication via OTP.
    Supports tiered verification: unverified → identity verified → driver verified.
    """
    __tablename__ = "users"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    full_name: Mapped[str] = mapped_column(String(100), nullable=False)
    email: Mapped[str | None] = mapped_column(String(150), unique=True, nullable=True)
    phone_number: Mapped[str] = mapped_column(String(15), unique=True, nullable=False)
    college_id: Mapped[str | None] = mapped_column(String(50), unique=True, nullable=True)
    gender: Mapped[GenderEnum] = mapped_column(Enum(GenderEnum), nullable=False)
    community: Mapped[str | None] = mapped_column(String(50))
    profile_photo_url: Mapped[str | None] = mapped_column(String)
    
    # Verification status
    is_phone_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    is_email_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    is_identity_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    is_driver_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    
    # Admin role
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    
    # Account status
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    
    # Push notification token
    fcm_token: Mapped[str | None] = mapped_column(String(255), nullable=True)
    
    # Timestamps
    created_at: Mapped[str] = mapped_column(
        TIMESTAMP(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[str | None] = mapped_column(
        TIMESTAMP(timezone=True), onupdate=func.now()
    )

    # Relationships
    driven_rides = relationship(
        "Ride",
        back_populates="driver"
    )

    vehicles = relationship(
        "Vehicle",
        back_populates="owner"
    )

    ride_requests = relationship(
        "RideRequest",
        back_populates="passenger"
    )

    ride_participations = relationship(
        "RideParticipant",
        back_populates="user"
    )