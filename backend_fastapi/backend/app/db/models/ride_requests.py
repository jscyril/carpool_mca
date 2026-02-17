import uuid
from sqlalchemy import Enum, TIMESTAMP, ForeignKey, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from db.base import Base
from db.enums import RideRequestStatusEnum
from sqlalchemy.orm import relationship

class RideRequest(Base):
    __tablename__ = "ride_requests"
    __table_args__ = (
        UniqueConstraint("ride_id", "passenger_id"),
    )

    request_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    ride_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("rides.ride_id")
    )
    passenger_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.user_id")
    )
    request_status: Mapped[RideRequestStatusEnum] = mapped_column(
        Enum(RideRequestStatusEnum), default=RideRequestStatusEnum.pending
    )
    requested_at: Mapped[str] = mapped_column(
        TIMESTAMP(timezone=True), server_default=func.now()
    )

    ride = relationship(
        "Ride",
        back_populates="ride_requests"
    )

    passenger = relationship(
        "User",
        back_populates="ride_requests"
    )