import uuid
from sqlalchemy import String, Enum, TIMESTAMP, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from db.base import Base
from db.enums import VerificationStatusEnum


class IdentityVerification(Base):
    """
    Tracks college identity verification requests.
    Student uploads college ID → OCR extracts details → cross-verified against college DB.
    """
    __tablename__ = "identity_verifications"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False
    )
    
    # Uploaded image
    college_id_image_url: Mapped[str] = mapped_column(String, nullable=False)
    
    # OCR extraction results
    extracted_name: Mapped[str | None] = mapped_column(String(100))
    extracted_register_number: Mapped[str | None] = mapped_column(String(50))
    
    # Match against college_students table
    matched_student_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("college_students.id"), nullable=True
    )
    
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
    user = relationship("User", backref="identity_verifications")
    matched_student = relationship("CollegeStudent", backref="verifications")
