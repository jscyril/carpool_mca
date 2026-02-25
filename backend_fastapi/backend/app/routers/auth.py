"""
Authentication Router - Passwordless OTP-based authentication.

Registration Flow (Phone-Only):
1. POST /auth/phone/send-otp → Send OTP to phone
2. POST /auth/phone/verify-otp → Verify phone → Get phone_verified_token
3. POST /auth/register → Create account with phone_verified_token only

Login Flow:
1. POST /auth/login/send-otp → Send OTP to registered phone
2. POST /auth/login/verify-otp → Verify OTP → Get access_token

Email verification is now a separate post-registration step in the verification router.
"""
import uuid
from fastapi import APIRouter, HTTPException, status, Request
from sqlalchemy import select

from core.deps import DBSession, get_client_ip
from core.security import (
    create_phone_session_token,
    create_phone_verified_token,
    create_access_token,
    decode_token,
    TokenType
)
from core.config import get_settings
from db.models.users import User
from db.models.otp_sessions import OTPSession, IdentifierType
from services.otp_service import OTPService, OTPError
from services.sms_service import SMSService
from schemas.auth import (
    PhoneSendOTPRequest, PhoneSendOTPResponse,
    PhoneVerifyOTPRequest, PhoneVerifyOTPResponse,
    RegisterRequest, RegisterResponse,
    LoginSendOTPRequest, LoginSendOTPResponse,
    LoginVerifyOTPRequest, LoginResponse,
    UserResponse, ErrorResponse
)

router = APIRouter(prefix="/auth", tags=["Authentication"])
settings = get_settings()


# =============================================================================
# PHONE OTP ENDPOINTS (Registration)
# =============================================================================

@router.post(
    "/phone/send-otp",
    response_model=PhoneSendOTPResponse,
    responses={429: {"model": ErrorResponse}}
)
async def send_phone_otp(
    request: PhoneSendOTPRequest,
    req: Request,
    db: DBSession
):
    """
    Step 1: Send OTP to phone number for registration.
    
    - Checks phone is not already registered
    - Rate limited to 5 requests per hour per phone number
    - 60 second cooldown between requests
    - OTP expires in 5 minutes
    """
    # Check if phone already registered
    existing = await db.execute(
        select(User).where(User.phone_number == request.phone)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number already registered. Please login instead."
        )
    
    otp_service = OTPService(db)
    sms_service = SMSService()
    
    try:
        # Create OTP session
        session, plain_otp = await otp_service.create_otp_session(
            identifier=request.phone,
            identifier_type=IdentifierType.phone,
            ip_address=get_client_ip(req)
        )
        
        # Send SMS
        sent = await sms_service.send_otp(request.phone, plain_otp)
        if not sent:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to send OTP. Please try again."
            )
        
        # Create session token
        session_token = create_phone_session_token(
            str(session.session_id),
            request.phone
        )
        
        return PhoneSendOTPResponse(
            session_token=session_token,
            expires_at=session.expires_at
        )
    
    except OTPError as e:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=e.message
        )


@router.post(
    "/phone/verify-otp",
    response_model=PhoneVerifyOTPResponse,
    responses={400: {"model": ErrorResponse}}
)
async def verify_phone_otp(
    request: PhoneVerifyOTPRequest,
    db: DBSession
):
    """
    Step 2: Verify phone OTP and get verification token.
    
    - Max 3 attempts per session
    - Returns phone_verified_token on success (valid for 30 min)
    """
    # Decode session token
    payload = decode_token(request.session_token, TokenType.PHONE_SESSION)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired session token"
        )
    
    session_id = payload.get("session_id")
    phone = payload.get("phone")
    
    otp_service = OTPService(db)
    
    try:
        # Verify OTP
        session = await otp_service.verify_otp_session(
            uuid.UUID(session_id),
            request.otp
        )
        
        # Create verified token
        verified_token = create_phone_verified_token(phone)
        
        return PhoneVerifyOTPResponse(
            phone_verified_token=verified_token,
            phone=phone
        )
    
    except OTPError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=e.message
        )


# =============================================================================
# REGISTRATION ENDPOINT (Phone-Only)
# =============================================================================

@router.post(
    "/register",
    response_model=RegisterResponse,
    responses={400: {"model": ErrorResponse}}
)
async def register(
    request: RegisterRequest,
    db: DBSession
):
    """
    Step 3: Complete registration with verified phone only.
    
    - Requires phone_verified_token (from step 2)
    - No email or college ID required at registration
    - Email verification and identity verification happen separately
    - Returns access token for immediate login
    """
    # Verify phone token
    phone_payload = decode_token(request.phone_verified_token, TokenType.PHONE_VERIFIED)
    if not phone_payload or not phone_payload.get("verified"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired phone verification. Please start over."
        )
    phone = phone_payload.get("phone")
    
    # Check for existing user with same phone
    existing = await db.execute(
        select(User).where(User.phone_number == phone)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number already registered"
        )
    
    # Create user (phone-only, no email/college_id yet)
    user = User(
        user_id=uuid.uuid4(),
        full_name=request.full_name,
        email=None,
        phone_number=phone,
        college_id=None,
        gender=request.gender,
        community=request.community,
        is_phone_verified=True,
        is_email_verified=False,
        is_identity_verified=False,
        is_driver_verified=False,
        is_admin=False,
        is_active=True
    )
    
    db.add(user)
    await db.flush()
    
    # Create access token
    access_token = create_access_token(str(user.user_id))
    
    return RegisterResponse(
        access_token=access_token,
        user=UserResponse(
            user_id=str(user.user_id),
            full_name=user.full_name,
            email=user.email,
            phone_number=user.phone_number,
            college_id=user.college_id,
            gender=user.gender.value if hasattr(user.gender, 'value') else user.gender,
            is_phone_verified=user.is_phone_verified,
            is_email_verified=user.is_email_verified,
            is_identity_verified=user.is_identity_verified,
            is_driver_verified=user.is_driver_verified
        )
    )


# =============================================================================
# LOGIN ENDPOINTS (OTP-based, Passwordless) — Unchanged
# =============================================================================

@router.post(
    "/login/send-otp",
    response_model=LoginSendOTPResponse,
    responses={400: {"model": ErrorResponse}, 429: {"model": ErrorResponse}}
)
async def login_send_otp(
    request: LoginSendOTPRequest,
    req: Request,
    db: DBSession
):
    """
    Login Step 1: Send OTP to registered phone number.
    
    - Phone must be registered
    - Rate limited
    """
    # Check if user exists
    result = await db.execute(
        select(User).where(User.phone_number == request.phone)
    )
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number not registered. Please register first."
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated"
        )
    
    otp_service = OTPService(db)
    sms_service = SMSService()
    
    try:
        # Create OTP session
        session, plain_otp = await otp_service.create_otp_session(
            identifier=request.phone,
            identifier_type=IdentifierType.phone,
            ip_address=get_client_ip(req)
        )
        
        # Send SMS
        sent = await sms_service.send_otp(request.phone, plain_otp)
        if not sent:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to send OTP. Please try again."
            )
        
        # Create session token
        session_token = create_phone_session_token(
            str(session.session_id),
            request.phone
        )
        
        return LoginSendOTPResponse(
            session_token=session_token,
            expires_at=session.expires_at
        )
    
    except OTPError as e:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=e.message
        )


@router.post(
    "/login/verify-otp",
    response_model=LoginResponse,
    responses={400: {"model": ErrorResponse}, 401: {"model": ErrorResponse}}
)
async def login_verify_otp(
    request: LoginVerifyOTPRequest,
    db: DBSession
):
    """
    Login Step 2: Verify OTP and get access token.
    
    - Max 3 attempts
    - Returns access token on success
    """
    # Decode session token
    payload = decode_token(request.session_token, TokenType.PHONE_SESSION)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired session token"
        )
    
    session_id = payload.get("session_id")
    phone = payload.get("phone")
    
    otp_service = OTPService(db)
    
    try:
        # Verify OTP
        await otp_service.verify_otp_session(
            uuid.UUID(session_id),
            request.otp
        )
        
        # Get user
        result = await db.execute(
            select(User).where(User.phone_number == phone)
        )
        user = result.scalar_one_or_none()
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found"
            )
        
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is deactivated"
            )
        
        # Create access token
        access_token = create_access_token(str(user.user_id))
        
        return LoginResponse(
            access_token=access_token,
            user=UserResponse(
                user_id=str(user.user_id),
                full_name=user.full_name,
                email=user.email,
                phone_number=user.phone_number,
                college_id=user.college_id,
                gender=user.gender.value if hasattr(user.gender, 'value') else user.gender,
                is_phone_verified=user.is_phone_verified,
                is_email_verified=user.is_email_verified,
                is_identity_verified=user.is_identity_verified,
                is_driver_verified=user.is_driver_verified
            )
        )
    
    except OTPError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=e.message
        )
