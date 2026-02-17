import uuid
from sqlalchemy import (
    Integer, Date, Time, Enum, DECIMAL, TIMESTAMP, ForeignKey, String
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from geoalchemy2 import Geography
from db.base import Base
from db.enums import RideStatusEnum, AllowedGenderEnum
from sqlalchemy.orm import relationship


class Ride(Base):
    __tablename__ = "rides"

    ride_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    driver_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.user_id")
    )
    vehicle_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("vehicles.vehicle_id")
    )

    start_location = mapped_column(Geography(geometry_type="POINT", srid=4326))
    end_location = mapped_column(Geography(geometry_type="POINT", srid=4326))

    start_address: Mapped[str] = mapped_column(String)
    end_address: Mapped[str] = mapped_column(String)

    ride_date: Mapped[str] = mapped_column(Date)
    ride_time: Mapped[str] = mapped_column(Time)

    available_seats: Mapped[int] = mapped_column(Integer)
    allowed_gender: Mapped[AllowedGenderEnum] = mapped_column(
        Enum(AllowedGenderEnum)
    )
    allowed_community: Mapped[str | None] = mapped_column(String(50))

    estimated_fare: Mapped[float | None] = mapped_column(DECIMAL(6, 2))
    status: Mapped[RideStatusEnum] = mapped_column(
        Enum(RideStatusEnum), default=RideStatusEnum.open
    )

    created_at: Mapped[str] = mapped_column(
        TIMESTAMP(timezone=True), server_default=func.now()
    )

    # Driver (User)
    driver = relationship(
        "User",
        back_populates="driven_rides",
        foreign_keys=[driver_id]
    )

    # Vehicle used
    vehicle = relationship(
        "Vehicle",
        back_populates="rides"
    )

    # Incoming join requests
    ride_requests = relationship(
        "RideRequest",
        back_populates="ride",
        cascade="all, delete-orphan"
    )

    # Confirmed participants
    participants = relationship(
        "RideParticipant",
        back_populates="ride",
        cascade="all, delete-orphan"
    )