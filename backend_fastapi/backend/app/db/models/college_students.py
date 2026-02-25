"""
College student model.
Stores college-specific information for verified students.
"""
import uuid
from sqlalchemy import String, TIMESTAMP, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from db.base import Base


class CollegeStudent(Base):
    __tablename__ = "college_students"

    student_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.user_id"), unique=True, nullable=False
    )
    college_email: Mapped[str] = mapped_column(String(150), unique=True, nullable=False)
    college_id_number: Mapped[str | None] = mapped_column(String(50))
    department: Mapped[str | None] = mapped_column(String(100))
    program: Mapped[str | None] = mapped_column(String(100))
    verified_at: Mapped[str | None] = mapped_column(TIMESTAMP(timezone=True))
    created_at: Mapped[str] = mapped_column(
        TIMESTAMP(timezone=True), server_default=func.now()
    )
