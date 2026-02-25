import uuid
from sqlalchemy import String, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from db.base import Base


class CollegeStudent(Base):
    """
    Pre-loaded college database of valid students and faculty.
    Used to cross-verify identity during college ID verification.
    """
    __tablename__ = "college_students"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    register_number: Mapped[str] = mapped_column(
        String(50), unique=True, nullable=False, index=True
    )
    full_name: Mapped[str] = mapped_column(String(100), nullable=False)
    department: Mapped[str | None] = mapped_column(String(100))
    program: Mapped[str | None] = mapped_column(String(50))  # e.g., "MCA", "BCA"
    role: Mapped[str] = mapped_column(String(20), default="student")  # student or faculty
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
