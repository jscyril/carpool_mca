"""
Verification Router — Identity, Email, and Driver verification endpoints.

All endpoints require authentication (access token).
Identity verification uses OCR + college DB cross-verification.
Email verification uses OTP to college email.
Driver verification uses pluggable document verification providers.
"""
import uuid
from fastapi import APIRouter, HTTPException, status, Request
from sqlalchemy import select

from core.deps import DBSession, CurrentUser, get_client_ip
from core.security import (
    create_email_session_token,
    decode_token,
    TokenType
)
from core.config import get_settings
from db.models.users import User
from db.models.identity_verifications import IdentityVerification
from db.models.driver_verifications import DriverVerification
from db.models.otp_sessions import OTPSession, IdentifierType
from db.enums import VerificationStatusEnum
from services.verification_service import verify_college_identity
from services.otp_service import OTPService, OTPError
from services.email_service import EmailService
from schemas.verification import (
    IdentityVerificationRequest, IdentityVerificationResponse,
    IdentityVerificationStatus,
    DriverVerificationRequest, DriverVerificationResponse,
    DriverVerificationStatus,
    EmailVerificationSendRequest, EmailVerificationSendResponse,
    EmailVerificationVerifyRequest, EmailVerificationVerifyResponse,
)
from schemas.auth import ErrorResponse

router = APIRouter(prefix="/verification", tags=["Verification"])
settings = get_settings()


# =============================================================================
# IDENTITY VERIFICATION (College ID + OCR)
# =============================================================================

@router.post(
    "/identity",
    response_model=IdentityVerificationResponse,
    responses={400: {"model": ErrorResponse}, 409: {"model": ErrorResponse}}
)
async def submit_identity_verification(
    request: IdentityVerificationRequest,
    current_user: CurrentUser,
    db: DBSession
):
    """
    Submit college ID image for identity verification.
    
    Flow:
    1. OCR extracts name + register number from the image
    2. Cross-verifies against college_students database
    3. Auto-approves on strong match, flags for admin on weak match
    
    Cannot resubmit if already verified.
    """
    # Check if already verified
    if current_user.is_identity_verified:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Identity already verified"
        )
    
    # Check for pending verification
    result = await db.execute(
        select(IdentityVerification).where(
            IdentityVerification.user_id == current_user.user_id,
            IdentityVerification.status == VerificationStatusEnum.pending
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You have a pending verification under admin review. Please wait."
        )
    
    # Run verification pipeline
    verification = await verify_college_identity(
        db=db,
        user_id=current_user.user_id,
        image_url=request.college_id_image_url
    )
    
    # Build response message based on status
    messages = {
        VerificationStatusEnum.verified: "Identity verified successfully! You can now access ride features.",
        VerificationStatusEnum.pending: "Verification submitted for admin review. We'll notify you once reviewed.",
        VerificationStatusEnum.rejected: "Verification failed. Please ensure you uploaded a clear image of your college ID.",
    }
    
    return IdentityVerificationResponse(
        id=verification.id,
        status=verification.status.value,
        extracted_name=verification.extracted_name,
        extracted_register_number=verification.extracted_register_number,
        message=messages.get(verification.status, "Verification submitted")
    )


@router.get(
    "/identity/status",
    response_model=IdentityVerificationStatus | None
)
async def get_identity_verification_status(
    current_user: CurrentUser,
    db: DBSession
):
    """
    Get current identity verification status.
    Returns the most recent verification record, or null if none exists.
    """
    result = await db.execute(
        select(IdentityVerification)
        .where(IdentityVerification.user_id == current_user.user_id)
        .order_by(IdentityVerification.submitted_at.desc())
        .limit(1)
    )
    verification = result.scalar_one_or_none()
    
    if not verification:
        return None
    
    return IdentityVerificationStatus(
        id=verification.id,
        status=verification.status.value,
        extracted_name=verification.extracted_name,
        extracted_register_number=verification.extracted_register_number,
        admin_notes=verification.admin_notes,
        submitted_at=verification.submitted_at,
        reviewed_at=verification.reviewed_at
    )


# =============================================================================
# EMAIL VERIFICATION (Post-Registration College Email)
# =============================================================================

@router.post(
    "/email/send-otp",
    response_model=EmailVerificationSendResponse,
    responses={400: {"model": ErrorResponse}, 409: {"model": ErrorResponse}, 429: {"model": ErrorResponse}}
)
async def send_email_verification_otp(
    request: EmailVerificationSendRequest,
    req: Request,
    current_user: CurrentUser,
    db: DBSession
):
    """
    Send OTP to college email for verification.
    
    - Requires authentication (user must be registered)
    - Only accepts *@*christuniversity.in emails
    - Rate limited
    """
    # Check if email already verified
    if current_user.is_email_verified and current_user.email:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already verified"
        )
    
    # Check if email already taken by another user
    existing = await db.execute(
        select(User).where(
            User.email == request.email,
            User.user_id != current_user.user_id
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered by another user"
        )
    
    otp_service = OTPService(db)
    email_service = EmailService()
    
    try:
        # Create OTP session
        session, plain_otp = await otp_service.create_otp_session(
            identifier=request.email,
            identifier_type=IdentifierType.email,
            ip_address=get_client_ip(req)
        )
        
        # Send email
        sent = await email_service.send_otp(request.email, plain_otp)
        if not sent:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to send OTP. Please try again."
            )
        
        # Create session token
        session_token = create_email_session_token(
            str(session.session_id),
            request.email
        )
        
        return EmailVerificationSendResponse(
            email_session_token=session_token,
            expires_at=session.expires_at
        )
    
    except OTPError as e:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=e.message
        )


@router.post(
    "/email/verify-otp",
    response_model=EmailVerificationVerifyResponse,
    responses={400: {"model": ErrorResponse}}
)
async def verify_email_verification_otp(
    request: EmailVerificationVerifyRequest,
    current_user: CurrentUser,
    db: DBSession
):
    """
    Verify email OTP and update user's email.
    
    On success, sets user.email and user.is_email_verified = True.
    """
    # Decode session token
    payload = decode_token(request.email_session_token, TokenType.EMAIL_SESSION)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired session token"
        )
    
    session_id = payload.get("session_id")
    email = payload.get("email")
    
    otp_service = OTPService(db)
    
    try:
        # Verify OTP
        await otp_service.verify_otp_session(
            uuid.UUID(session_id),
            request.otp
        )
        
        # Update user
        current_user.email = email
        current_user.is_email_verified = True
        await db.flush()
        
        return EmailVerificationVerifyResponse(
            email=email
        )
    
    except OTPError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=e.message
        )


# =============================================================================
# DRIVER VERIFICATION
# =============================================================================

@router.post(
    "/driver",
    response_model=DriverVerificationResponse,
    responses={400: {"model": ErrorResponse}, 403: {"model": ErrorResponse}, 409: {"model": ErrorResponse}}
)
async def submit_driver_verification(
    request: DriverVerificationRequest,
    current_user: CurrentUser,
    db: DBSession
):
    """
    Submit driver verification documents (license + vehicle registration).
    
    Requirements:
    - User must be identity-verified first
    - Cannot resubmit if already verified
    
    Uses pluggable verification provider (console auto-approves for demo).
    """
    # Must be identity-verified first
    if not current_user.is_identity_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Identity verification required before driver verification"
        )
    
    # Check if already driver-verified
    if current_user.is_driver_verified:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Driver already verified"
        )
    
    # Check for pending verification
    result = await db.execute(
        select(DriverVerification).where(
            DriverVerification.user_id == current_user.user_id,
            DriverVerification.status == VerificationStatusEnum.pending
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You have a pending driver verification under review"
        )
    
    # Import driver verification service
    from services.driver_verification_service import get_verification_provider
    
    provider = get_verification_provider()
    
    # Verify license
    license_result = await provider.verify_license(
        request.license_number,
        request.license_image_url
    )
    
    # Verify vehicle registration
    vehicle_result = await provider.verify_vehicle_registration(
        request.vehicle_registration_number,
        request.registration_image_url
    )
    
    # Determine status
    if license_result["valid"] and vehicle_result["valid"]:
        ver_status = VerificationStatusEnum.verified
        admin_notes = "Auto-verified by provider"
        # Update user
        current_user.is_driver_verified = True
    else:
        ver_status = VerificationStatusEnum.rejected
        reasons = []
        if not license_result["valid"]:
            reasons.append(f"License: {license_result.get('reason', 'invalid')}")
        if not vehicle_result["valid"]:
            reasons.append(f"Vehicle: {vehicle_result.get('reason', 'invalid')}")
        admin_notes = "; ".join(reasons)
    
    # Create verification record
    verification = DriverVerification(
        user_id=current_user.user_id,
        license_number=request.license_number,
        license_image_url=request.license_image_url,
        vehicle_registration_number=request.vehicle_registration_number,
        registration_image_url=request.registration_image_url,
        status=ver_status,
        admin_notes=admin_notes
    )
    db.add(verification)
    await db.flush()
    
    messages = {
        VerificationStatusEnum.verified: "Driver verification successful! You can now create rides.",
        VerificationStatusEnum.rejected: "Driver verification failed. Please check your documents and try again.",
    }
    
    return DriverVerificationResponse(
        id=verification.id,
        status=ver_status.value,
        message=messages.get(ver_status, "Verification submitted")
    )


@router.get(
    "/driver/status",
    response_model=DriverVerificationStatus | None
)
async def get_driver_verification_status(
    current_user: CurrentUser,
    db: DBSession
):
    """
    Get current driver verification status.
    Returns the most recent driver verification record, or null if none exists.
    """
    result = await db.execute(
        select(DriverVerification)
        .where(DriverVerification.user_id == current_user.user_id)
        .order_by(DriverVerification.submitted_at.desc())
        .limit(1)
    )
    verification = result.scalar_one_or_none()
    
    if not verification:
        return None
    
    return DriverVerificationStatus(
        id=verification.id,
        status=verification.status.value,
        license_number=verification.license_number,
        vehicle_registration_number=verification.vehicle_registration_number,
        admin_notes=verification.admin_notes,
        submitted_at=verification.submitted_at,
        reviewed_at=verification.reviewed_at
    )
