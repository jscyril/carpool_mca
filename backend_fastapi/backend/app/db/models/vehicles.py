import uuid
from sqlalchemy import String, Enum, TIMESTAMP, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from db.base import Base
from db.enums import VehicleTypeEnum
from sqlalchemy.orm import relationship

class Vehicle(Base):
    __tablename__ = "vehicles"

    vehicle_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.user_id")
    )
    vehicle_type: Mapped[VehicleTypeEnum] = mapped_column(
        Enum(VehicleTypeEnum), nullable=False
    )
    vehicle_number: Mapped[str] = mapped_column(String(20), unique=True)
    created_at: Mapped[str] = mapped_column(
        TIMESTAMP(timezone=True), server_default=func.now()
    )

    owner = relationship(
        "User",
        back_populates="vehicles"
    )

    rides = relationship(
        "Ride",
        back_populates="vehicle"
    )