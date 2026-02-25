import uuid
from sqlalchemy import Boolean, TIMESTAMP, ForeignKey, String, Float
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from db.base import Base
from sqlalchemy.orm import relationship

class RideParticipant(Base):
    __tablename__ = "ride_participants"

    participant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    ride_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("rides.ride_id"), nullable=False
    )
    user_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False
    )

    # Per-rider pickup location (copied from request on accept)
    pickup_lat: Mapped[float | None] = mapped_column(Float, nullable=True)
    pickup_lng: Mapped[float | None] = mapped_column(Float, nullable=True)
    pickup_address: Mapped[str | None] = mapped_column(String, nullable=True)

    # Per-rider OTP & pickup status
    pickup_otp: Mapped[str | None] = mapped_column(String(4), nullable=True)
    is_picked_up: Mapped[bool] = mapped_column(Boolean, default=False)

    joined_at: Mapped[str] = mapped_column(
        TIMESTAMP(timezone=True), server_default=func.now()
    )

    ride = relationship(
        "Ride",
        back_populates="participants"
    )

    user = relationship(
        "User",
        back_populates="ride_participations"
    )
