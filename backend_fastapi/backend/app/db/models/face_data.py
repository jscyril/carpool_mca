from sqlalchemy import ForeignKey, TIMESTAMP
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func
from db.base import Base

class FaceData(Base):
    __tablename__ = "face_data"

    user_id: Mapped[UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.user_id"),
        primary_key=True
    )
    face_embedding: Mapped[list[float]] = mapped_column(ARRAY(float), nullable=False)
    last_verified_at: Mapped[str | None] = mapped_column(TIMESTAMP)
