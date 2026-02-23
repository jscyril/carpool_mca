"""
Driver verification model.
Stores driver license verification requests.
"""
import uuid
from sqlalchemy import String, TIMESTAMP, Enum, Text, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from db.base import Base
from db.enums import VerificationStatusEnum


class DriverVerification(Base):
    __tablename__ = "driver_verifications"

    verification_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False
    )
    license_number: Mapped[str | None] = mapped_column(String(50))
    license_document_url: Mapped[str | None] = mapped_column(String)
    status: Mapped[VerificationStatusEnum] = mapped_column(
        Enum(VerificationStatusEnum), default=VerificationStatusEnum.pending
    )
    reviewer_notes: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[str] = mapped_column(
        TIMESTAMP(timezone=True), server_default=func.now()
    )
    reviewed_at: Mapped[str | None] = mapped_column(TIMESTAMP(timezone=True))
