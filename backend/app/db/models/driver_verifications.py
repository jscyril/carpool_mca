import uuid
from sqlalchemy import String, Enum, TIMESTAMP, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from db.base import Base
from db.enums import VerificationStatusEnum


class DriverVerification(Base):
    """
    Tracks driver verification requests.
    User uploads driver's license + vehicle registration → verified via provider.
    """
    __tablename__ = "driver_verifications"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False
    )
    
    # Driver's license
    license_number: Mapped[str] = mapped_column(String(50), nullable=False)
    license_image_url: Mapped[str] = mapped_column(String, nullable=False)
    
    # Vehicle registration
    vehicle_registration_number: Mapped[str] = mapped_column(String(50), nullable=False)
    registration_image_url: Mapped[str] = mapped_column(String, nullable=False)
    
    # Verification status
    status: Mapped[VerificationStatusEnum] = mapped_column(
        Enum(VerificationStatusEnum), default=VerificationStatusEnum.submitted
    )
    admin_notes: Mapped[str | None] = mapped_column(String)
    
    # Timestamps
    submitted_at: Mapped[str] = mapped_column(
        TIMESTAMP(timezone=True), server_default=func.now()
    )
    reviewed_at: Mapped[str | None] = mapped_column(
        TIMESTAMP(timezone=True), nullable=True
    )

    # Relationships
    user = relationship("User", backref="driver_verifications")
