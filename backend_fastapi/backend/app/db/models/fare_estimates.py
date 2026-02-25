import uuid
from sqlalchemy import DECIMAL, TIMESTAMP, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from db.base import Base

class FareEstimate(Base):
    __tablename__ = "fare_estimates"

    estimate_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    ride_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("rides.ride_id"), unique=True, nullable=False
    )
    distance_km: Mapped[float] = mapped_column(DECIMAL(5, 2), nullable=False)
    estimated_fare: Mapped[float] = mapped_column(DECIMAL(6, 2), nullable=False)
    calculated_at: Mapped[str] = mapped_column(
        TIMESTAMP(timezone=True), server_default=func.now()
    )
