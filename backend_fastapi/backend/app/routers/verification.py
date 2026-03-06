"""
Verification Router — Tiered identity verification for UniRide.

Endpoints:
  POST /verification/email/send-otp      — Send OTP to college email (auth required)
  POST /verification/email/verify-otp   — Verify email OTP → is_email_verified = True
  POST /verification/identity/submit     — Upload college ID doc → status = submitted
  GET  /verification/identity/status     — Get identity verification status
  POST /verification/driver/submit       — Upload licence doc → status = submitted
  GET  /verification/driver/status       — Get driver verification status
"""
import uuid
from typing import Optional
from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from pydantic import BaseModel, field_validator
import re

from core.deps import DBSession, CurrentUser
from core.security import (
    create_email_session_token,
    decode_token,
    TokenType,
)
from core.config import get_settings
from db.models.users import User
from db.models.otp_sessions import OTPSession, IdentifierType
from db.models.identity_verifications import IdentityVerification
from db.models.driver_verifications import DriverVerification
from db.enums import VerificationStatusEnum
from services.otp_service import OTPService, OTPError
from services.email_service import EmailService

router = APIRouter(prefix="/verification", tags=["Verification"])
settings = get_settings()


# =============================================================================
# EMAIL VERIFICATION
# =============================================================================

class EmailSendOTPRequest(BaseModel):
    email: str

    @field_validator("email")
    @classmethod
    def validate_college_email(cls, v: str) -> str:
        pattern = r"^[a-zA-Z0-9._%+-]+@([a-zA-Z0-9-]+\.)*christuniversity\.in$"
        if not re.match(pattern, v.lower()):
            raise ValueError("Must be a Christ University email (@christuniversity.in or @*.christuniversity.in)")
        return v.lower()


class EmailSendOTPResponse(BaseModel):
    email_session_token: str
    message: str


class EmailVerifyOTPRequest(BaseModel):
    email_session_token: str
    otp: str


@router.post("/email/send-otp", response_model=EmailSendOTPResponse)
async def send_email_otp(
    payload: EmailSendOTPRequest,
    user: CurrentUser,
    db: DBSession,
):
    """
    Send OTP to a college email address for verification.
    Requires authenticated user. Email must be @christuniversity.in or subdomain.
    """
    if user.is_email_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email is already verified.",
        )

    # Check email isn't already taken by another user
    existing = await db.execute(
        select(User).where(User.email == payload.email, User.user_id != user.user_id)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This email is already linked to another account.",
        )

    otp_service = OTPService(db)
    email_service = EmailService()

    try:
        session, plain_otp = await otp_service.create_otp_session(
            identifier=payload.email,
            identifier_type=IdentifierType.email,
            ip_address=None,
        )
        sent = await email_service.send_otp(payload.email, plain_otp)
        if not sent:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to send email OTP. Please try again.",
            )

        session_token = create_email_session_token(str(session.session_id), payload.email)
        return EmailSendOTPResponse(
            email_session_token=session_token,
            message=f"OTP sent to {payload.email}",
        )
    except OTPError as e:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=e.message)


@router.post("/email/verify-otp")
async def verify_email_otp(
    payload: EmailVerifyOTPRequest,
    user: CurrentUser,
    db: DBSession,
):
    """
    Verify the college email OTP. Sets is_email_verified = True and links email to account.
    """
    token_payload = decode_token(payload.email_session_token, TokenType.EMAIL_SESSION)
    if not token_payload:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired session token. Please request a new OTP.",
        )

    session_id = token_payload.get("session_id")
    email = token_payload.get("email")

    otp_service = OTPService(db)
    try:
        await otp_service.verify_otp_session(uuid.UUID(session_id), payload.otp)
    except OTPError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)

    # Link email and mark verified
    user.email = email
    user.is_email_verified = True
    await db.flush()

    return {"message": "Email verified successfully", "email": email}


# =============================================================================
# IDENTITY VERIFICATION (College ID upload)
# =============================================================================

class IdentitySubmitRequest(BaseModel):
    college_id_number: Optional[str] = None
    document_url: str  # URL or base64 string of the ID document image


class VerificationStatusResponse(BaseModel):
    status: str
    reviewer_notes: Optional[str] = None
    submitted_at: Optional[str] = None
    reviewed_at: Optional[str] = None


@router.post("/identity/submit", status_code=200)
async def submit_identity_verification(
    payload: IdentitySubmitRequest,
    user: CurrentUser,
    db: DBSession,
):
    """
    Submit college ID document for identity verification.
    Creates or updates the verification record with status = submitted.
    Admin must approve to set is_identity_verified = True.
    """
    if user.is_identity_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Identity is already verified.",
        )

    # Upsert verification record
    result = await db.execute(
        select(IdentityVerification).where(IdentityVerification.user_id == user.user_id)
    )
    record = result.scalar_one_or_none()

    if record:
        if record.status == VerificationStatusEnum.verified:
            raise HTTPException(status_code=400, detail="Already verified.")
        record.document_url = payload.document_url
        record.college_id_number = payload.college_id_number
        record.status = VerificationStatusEnum.submitted
    else:
        record = IdentityVerification(
            verification_id=uuid.uuid4(),
            user_id=user.user_id,
            college_id_number=payload.college_id_number,
            document_url=payload.document_url,
            status=VerificationStatusEnum.submitted,
        )
        db.add(record)

    await db.flush()
    return {"message": "Identity verification submitted. Pending admin review.", "status": "submitted"}


@router.get("/identity/status", response_model=VerificationStatusResponse)
async def get_identity_status(user: CurrentUser, db: DBSession):
    """Get the current identity verification status for the authenticated user."""
    result = await db.execute(
        select(IdentityVerification).where(IdentityVerification.user_id == user.user_id)
    )
    record = result.scalar_one_or_none()
    if not record:
        return VerificationStatusResponse(status="not_submitted")

    return VerificationStatusResponse(
        status=record.status.value,
        reviewer_notes=record.reviewer_notes,
        submitted_at=str(record.created_at) if record.created_at else None,
        reviewed_at=str(record.reviewed_at) if record.reviewed_at else None,
    )


# =============================================================================
# DRIVER VERIFICATION (Licence / RC upload)
# =============================================================================

class DriverVerificationSubmitRequest(BaseModel):
    license_number: Optional[str] = None
    license_document_url: str  # URL or base64 string of the licence document


@router.post("/driver/submit", status_code=200)
async def submit_driver_verification(
    payload: DriverVerificationSubmitRequest,
    user: CurrentUser,
    db: DBSession,
):
    """
    Submit driving licence for driver verification.
    Requires identity verification first.
    Admin must approve to set is_driver_verified = True.
    """
    if not user.is_identity_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Identity must be verified before submitting driver documents.",
        )
    if user.is_driver_verified:
        raise HTTPException(status_code=400, detail="Driver is already verified.")

    result = await db.execute(
        select(DriverVerification).where(DriverVerification.user_id == user.user_id)
    )
    record = result.scalar_one_or_none()

    if record:
        if record.status == VerificationStatusEnum.verified:
            raise HTTPException(status_code=400, detail="Already verified.")
        record.license_number = payload.license_number
        record.license_document_url = payload.license_document_url
        record.status = VerificationStatusEnum.submitted
    else:
        record = DriverVerification(
            verification_id=uuid.uuid4(),
            user_id=user.user_id,
            license_number=payload.license_number,
            license_document_url=payload.license_document_url,
            status=VerificationStatusEnum.submitted,
        )
        db.add(record)

    await db.flush()
    return {"message": "Driver verification submitted. Pending admin review.", "status": "submitted"}


@router.get("/driver/status", response_model=VerificationStatusResponse)
async def get_driver_status(user: CurrentUser, db: DBSession):
    """Get the current driver verification status for the authenticated user."""
    result = await db.execute(
        select(DriverVerification).where(DriverVerification.user_id == user.user_id)
    )
    record = result.scalar_one_or_none()
    if not record:
        return VerificationStatusResponse(status="not_submitted")

    return VerificationStatusResponse(
        status=record.status.value,
        reviewer_notes=record.reviewer_notes,
        submitted_at=str(record.created_at) if record.created_at else None,
        reviewed_at=str(record.reviewed_at) if record.reviewed_at else None,
    )
