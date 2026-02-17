import uuid
from sqlalchemy import TIMESTAMP, ForeignKey, UniqueConstraint, CheckConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from db.base import Base

class Report(Base):
    __tablename__ = "reports"
    __table_args__ = (
        UniqueConstraint("ride_id", "reporter_id", "reported_user_id"),
        CheckConstraint("reporter_id <> reported_user_id"),
    )

    report_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    ride_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("rides.ride_id"), nullable=False
    )
    reporter_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False
    )
    reported_user_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False
    )
    comment: Mapped[str | None]
    created_at: Mapped[str] = mapped_column(
        TIMESTAMP(timezone=True), server_default=func.now()
    )
