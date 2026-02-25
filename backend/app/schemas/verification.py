"""
Pydantic schemas for verification endpoints.
Covers identity verification, driver verification, and email verification.
"""
from datetime import datetime
from typing import Optional
from uuid import UUID
from pydantic import BaseModel, Field, EmailStr, field_validator
import re


# =============================================================================
# IDENTITY VERIFICATION SCHEMAS
# =============================================================================

class IdentityVerificationRequest(BaseModel):
    """Request to submit college ID for verification."""
    college_id_image_url: str = Field(
        ..., description="URL of the uploaded college ID image"
    )


class IdentityVerificationResponse(BaseModel):
    """Response after submitting identity verification."""
    id: UUID
    status: str
    extracted_name: Optional[str] = None
    extracted_register_number: Optional[str] = None
    message: str
    
    class Config:
        from_attributes = True


class IdentityVerificationStatus(BaseModel):
    """Current status of identity verification."""
    id: UUID
    status: str
    extracted_name: Optional[str] = None
    extracted_register_number: Optional[str] = None
    admin_notes: Optional[str] = None
    submitted_at: datetime
    reviewed_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


# =============================================================================
# DRIVER VERIFICATION SCHEMAS
# =============================================================================

class DriverVerificationRequest(BaseModel):
    """Request to submit driver verification documents."""
    license_number: str = Field(..., min_length=5, max_length=50)
    license_image_url: str = Field(
        ..., description="URL of the uploaded license image"
    )
    vehicle_registration_number: str = Field(..., min_length=5, max_length=50)
    registration_image_url: str = Field(
        ..., description="URL of the uploaded vehicle registration image"
    )


class DriverVerificationResponse(BaseModel):
    """Response after submitting driver verification."""
    id: UUID
    status: str
    message: str
    
    class Config:
        from_attributes = True


class DriverVerificationStatus(BaseModel):
    """Current status of driver verification."""
    id: UUID
    status: str
    license_number: str
    vehicle_registration_number: str
    admin_notes: Optional[str] = None
    submitted_at: datetime
    reviewed_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


# =============================================================================
# EMAIL VERIFICATION SCHEMAS (Post-Registration)
# =============================================================================

class EmailVerificationSendRequest(BaseModel):
    """Request to send verification OTP to college email."""
    email: EmailStr
    
    @field_validator("email")
    @classmethod
    def validate_college_email(cls, v: str) -> str:
        pattern = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]*christuniversity\.in$"
        if not re.match(pattern, v.lower()):
            raise ValueError("Must be a valid Christ University email (*@*christuniversity.in)")
        return v.lower()


class EmailVerificationSendResponse(BaseModel):
    """Response after sending email verification OTP."""
    email_session_token: str
    expires_at: datetime
    message: str = "OTP sent to your college email"


class EmailVerificationVerifyRequest(BaseModel):
    """Request to verify email OTP."""
    email_session_token: str
    otp: str = Field(..., min_length=6, max_length=6)


class EmailVerificationVerifyResponse(BaseModel):
    """Response after successful email verification."""
    email: str
    message: str = "College email verified successfully"
