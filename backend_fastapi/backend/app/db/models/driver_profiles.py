from sqlalchemy import Boolean, Integer, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from db.base import Base
from sqlalchemy.orm import relationship

class DriverProfile(Base):
    __tablename__ = "driver_profiles"

    user_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id"),
        primary_key=True
    )
    vehicle_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("vehicles.vehicle_id")
    )
    daily_seat_limit: Mapped[int] = mapped_column(Integer, nullable=False)
    is_driver_active: Mapped[bool] = mapped_column(Boolean, default=True)

    user = relationship(
        "User",
        uselist=False
    )

    vehicle = relationship(
        "Vehicle",
        uselist=False
    )
