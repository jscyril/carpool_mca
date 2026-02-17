"""
Pydantic schemas for authentication endpoints.
Passwordless OTP-based authentication.
"""
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, EmailStr, field_validator
import re


# =============================================================================
# PHONE OTP SCHEMAS
# =============================================================================

class PhoneSendOTPRequest(BaseModel):
    """Request to send OTP to phone number."""
    phone: str = Field(..., description="Phone number with country code (e.g., +919876543210)")
    
    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        # Indian phone number validation
        pattern = r"^\+91[6-9]\d{9}$"
        if not re.match(pattern, v):
            raise ValueError("Invalid Indian phone number. Format: +91XXXXXXXXXX")
        return v


class PhoneSendOTPResponse(BaseModel):
    """Response after sending phone OTP."""
    session_token: str
    expires_at: datetime
    message: str = "OTP sent successfully"


class PhoneVerifyOTPRequest(BaseModel):
    """Request to verify phone OTP."""
    session_token: str
    otp: str = Field(..., min_length=6, max_length=6)
    
    @field_validator("otp")
    @classmethod
    def validate_otp(cls, v: str) -> str:
        if not v.isdigit():
            raise ValueError("OTP must contain only digits")
        return v


class PhoneVerifyOTPResponse(BaseModel):
    """Response after verifying phone OTP."""
    phone_verified_token: str
    phone: str
    message: str = "Phone verified successfully"


# =============================================================================
# EMAIL VERIFICATION SCHEMAS (Post-Registration)
# Email verification is a separate step after account creation.
# User must be authenticated to verify their college email.
# =============================================================================

class EmailSendOTPRequest(BaseModel):
    """Request to send OTP to college email. Requires authentication."""
    email: EmailStr
    
    @field_validator("email")
    @classmethod
    def validate_college_email(cls, v: str) -> str:
        # Pattern: *****@***christuniversity.in
        pattern = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]*christuniversity\.in$"
        if not re.match(pattern, v.lower()):
            raise ValueError("Email must be a valid Christ University email (*@*christuniversity.in)")
        return v.lower()


class EmailSendOTPResponse(BaseModel):
    """Response after sending email OTP."""
    email_session_token: str
    expires_at: datetime
    message: str = "OTP sent to your college email"


class EmailVerifyOTPRequest(BaseModel):
    """Request to verify email OTP."""
    email_session_token: str
    otp: str = Field(..., min_length=6, max_length=6)


class EmailVerifyOTPResponse(BaseModel):
    """Response after verifying email OTP."""
    email: str
    message: str = "Email verified successfully"


# =============================================================================
# REGISTRATION SCHEMAS (Phone-Only)
# Registration only requires a verified phone number.
# College email and identity verification happen separately after registration.
# =============================================================================

class RegisterRequest(BaseModel):
    """Registration request after phone verification only."""
    phone_verified_token: str
    
    # User details (no password, no email required)
    full_name: str = Field(..., min_length=2, max_length=100)
    gender: str = Field(..., pattern="^(male|female|other)$")
    community: Optional[str] = Field(None, max_length=50)


class RegisterResponse(BaseModel):
    """Response after successful registration."""
    access_token: str
    token_type: str = "bearer"
    user: "UserResponse"


class UserResponse(BaseModel):
    """User data returned in auth responses."""
    user_id: str
    full_name: str
    email: Optional[str] = None
    phone_number: str
    college_id: Optional[str] = None
    gender: str
    is_phone_verified: bool
    is_email_verified: bool
    is_identity_verified: bool
    is_driver_verified: bool
    
    class Config:
        from_attributes = True


# =============================================================================
# LOGIN SCHEMAS (OTP-based, unchanged)
# =============================================================================

class LoginSendOTPRequest(BaseModel):
    """Request OTP for login."""
    phone: str = Field(..., description="Registered phone number")
    
    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        pattern = r"^\+91[6-9]\d{9}$"
        if not re.match(pattern, v):
            raise ValueError("Invalid Indian phone number. Format: +91XXXXXXXXXX")
        return v


class LoginSendOTPResponse(BaseModel):
    """Response after sending login OTP."""
    session_token: str
    expires_at: datetime
    message: str = "OTP sent to your registered phone"


class LoginVerifyOTPRequest(BaseModel):
    """Verify OTP for login."""
    session_token: str
    otp: str = Field(..., min_length=6, max_length=6)


class LoginResponse(BaseModel):
    """Response after successful login."""
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


# =============================================================================
# ERROR SCHEMAS
# =============================================================================

class ErrorResponse(BaseModel):
    """Standard error response."""
    detail: str
    error_code: Optional[str] = None
