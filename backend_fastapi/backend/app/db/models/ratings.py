import uuid
from sqlalchemy import Integer, TIMESTAMP, ForeignKey, CheckConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from db.base import Base

class Rating(Base):
    __tablename__ = "ratings"
    __table_args__ = (
        CheckConstraint("rating_value BETWEEN 1 AND 5"),
        CheckConstraint("rater_id <> rated_user_id"),
    )

    rating_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    ride_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("rides.ride_id")
    )
    rater_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.user_id")
    )
    rated_user_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.user_id")
    )
    rating_value: Mapped[int] = mapped_column(Integer)
    comment: Mapped[str | None]
    created_at: Mapped[str] = mapped_column(
        TIMESTAMP(timezone=True), server_default=func.now()
    )
