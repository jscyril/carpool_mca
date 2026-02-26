"""
Authentication Router - Passwordless OTP-based authentication.

Registration Flow (Phone-Only):
1. POST /auth/phone/send-otp  → Send OTP to phone
2. POST /auth/phone/verify-otp → Verify phone → Get phone_verified_token
3. POST /auth/register         → Create account → access_token + refresh_token

Login Flow:
1. POST /auth/login/send-otp   → Send OTP to registered phone
2. POST /auth/login/verify-otp → Verify OTP → access_token + refresh_token

Persistent Session:
- POST /auth/refresh  → Exchange refresh_token for new access_token + rotated refresh_token
- POST /auth/logout   → Revoke refresh_token
"""
import hashlib
import uuid
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, HTTPException, status, Request
from sqlalchemy import select
from pydantic import BaseModel

from core.deps import DBSession, get_client_ip, CurrentUser
from core.security import (
    create_phone_session_token,
    create_phone_verified_token,
    create_access_token,
    decode_token,
    generate_refresh_token,
    hash_refresh_token,
    TokenType
)
from core.config import get_settings
from db.models.users import User
from db.models.otp_sessions import OTPSession, IdentifierType
from db.models.refresh_tokens import RefreshToken
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
# HELPERS
# =============================================================================

async def _create_refresh_token_record(db, user_id: uuid.UUID) -> str:
    """Generate, hash, store, and return a plain refresh token."""
    plain = generate_refresh_token()
    token_hash = hash_refresh_token(plain)
    expires_at = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    record = RefreshToken(
        token_id=uuid.uuid4(),
        user_id=user_id,
        token_hash=token_hash,
        expires_at=expires_at,
    )
    db.add(record)
    await db.flush()
    return plain


def _user_to_response(user: User) -> UserResponse:
    return UserResponse(
        user_id=str(user.user_id),
        full_name=user.full_name,
        email=user.email,
        phone_number=user.phone_number,
        college_id=user.college_id,
        gender=user.gender.value if hasattr(user.gender, "value") else user.gender,
        is_phone_verified=user.is_phone_verified,
        is_email_verified=user.is_email_verified,
        is_identity_verified=user.is_identity_verified,
        is_driver_verified=user.is_driver_verified,
    )


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
    existing = await db.execute(
        select(User).where(User.phone_number == request.phone)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number already registered. Please login instead.",
        )

    otp_service = OTPService(db)
    sms_service = SMSService()

    try:
        session, plain_otp = await otp_service.create_otp_session(
            identifier=request.phone,
            identifier_type=IdentifierType.phone,
            ip_address=get_client_ip(req)
        )
        sent = await sms_service.send_otp(request.phone, plain_otp)
        if not sent:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to send OTP. Please try again.",
            )
        session_token = create_phone_session_token(str(session.session_id), request.phone)
        return PhoneSendOTPResponse(session_token=session_token, expires_at=session.expires_at)

    except OTPError as e:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=e.message)


@router.post(
    "/phone/verify-otp",
    response_model=PhoneVerifyOTPResponse,
    responses={400: {"model": ErrorResponse}}
)
async def verify_phone_otp(request: PhoneVerifyOTPRequest, db: DBSession):
    """
    Step 2: Verify phone OTP and get phone_verified_token.
    - Max 3 attempts per session
    - Returns phone_verified_token on success (valid for 30 min)
    """
    payload = decode_token(request.session_token, TokenType.PHONE_SESSION)
    if not payload:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired session token")

    session_id = payload.get("session_id")
    phone = payload.get("phone")

    otp_service = OTPService(db)
    try:
        await otp_service.verify_otp_session(uuid.UUID(session_id), request.otp)
        verified_token = create_phone_verified_token(phone)
        return PhoneVerifyOTPResponse(phone_verified_token=verified_token, phone=phone)
    except OTPError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


# =============================================================================
# REGISTRATION
# =============================================================================

@router.post(
    "/register",
    response_model=RegisterResponse,
    responses={400: {"model": ErrorResponse}}
)
async def register(request: RegisterRequest, db: DBSession):
    """
    Step 3: Complete registration with verified phone only.
    Returns both access_token (1h) and refresh_token (30 days).
    """
    phone_payload = decode_token(request.phone_verified_token, TokenType.PHONE_VERIFIED)
    if not phone_payload or not phone_payload.get("verified"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired phone verification. Please start over.",
        )
    phone = phone_payload.get("phone")

    existing = await db.execute(select(User).where(User.phone_number == phone))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Phone number already registered")

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
        is_active=True,
    )
    db.add(user)
    await db.flush()

    access_token = create_access_token(str(user.user_id))
    refresh_token = await _create_refresh_token_record(db, user.user_id)

    return RegisterResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=_user_to_response(user),
    )


# =============================================================================
# LOGIN ENDPOINTS
# =============================================================================

@router.post(
    "/login/send-otp",
    response_model=LoginSendOTPResponse,
    responses={400: {"model": ErrorResponse}, 429: {"model": ErrorResponse}}
)
async def login_send_otp(request: LoginSendOTPRequest, req: Request, db: DBSession):
    """Login Step 1: Send OTP to registered phone number."""
    result = await db.execute(select(User).where(User.phone_number == request.phone))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Phone number not registered. Please register first.")
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is deactivated")

    otp_service = OTPService(db)
    sms_service = SMSService()
    try:
        session, plain_otp = await otp_service.create_otp_session(
            identifier=request.phone,
            identifier_type=IdentifierType.phone,
            ip_address=get_client_ip(req)
        )
        sent = await sms_service.send_otp(request.phone, plain_otp)
        if not sent:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to send OTP. Please try again.")
        session_token = create_phone_session_token(str(session.session_id), request.phone)
        return LoginSendOTPResponse(session_token=session_token, expires_at=session.expires_at)
    except OTPError as e:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=e.message)


@router.post(
    "/login/verify-otp",
    response_model=LoginResponse,
    responses={400: {"model": ErrorResponse}, 401: {"model": ErrorResponse}}
)
async def login_verify_otp(request: LoginVerifyOTPRequest, db: DBSession):
    """
    Login Step 2: Verify OTP and get access + refresh tokens.
    """
    payload = decode_token(request.session_token, TokenType.PHONE_SESSION)
    if not payload:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired session token")

    session_id = payload.get("session_id")
    phone = payload.get("phone")

    otp_service = OTPService(db)
    try:
        await otp_service.verify_otp_session(uuid.UUID(session_id), request.otp)
    except OTPError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)

    result = await db.execute(select(User).where(User.phone_number == phone))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account is deactivated")

    access_token = create_access_token(str(user.user_id))
    refresh_token = await _create_refresh_token_record(db, user.user_id)

    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=_user_to_response(user),
    )


# =============================================================================
# REFRESH TOKEN ENDPOINT
# =============================================================================

class RefreshRequest(BaseModel):
    refresh_token: str


class RefreshResponse(BaseModel):
    access_token: str
    refresh_token: str


@router.post("/refresh", response_model=RefreshResponse)
async def refresh_tokens(request: RefreshRequest, db: DBSession):
    """
    Exchange a valid refresh token for a new access token and rotated refresh token.
    The old refresh token is revoked immediately (rotation).
    """
    token_hash = hash_refresh_token(request.refresh_token)
    result = await db.execute(
        select(RefreshToken).where(
            RefreshToken.token_hash == token_hash,
            RefreshToken.is_revoked == False,
        )
    )
    record = result.scalar_one_or_none()

    if not record:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or revoked refresh token")

    if record.expires_at < datetime.now(timezone.utc):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token has expired. Please log in again.")

    # Revoke old token (rotation)
    record.is_revoked = True
    await db.flush()

    # Issue new tokens
    access_token = create_access_token(str(record.user_id))
    new_refresh_token = await _create_refresh_token_record(db, record.user_id)

    return RefreshResponse(access_token=access_token, refresh_token=new_refresh_token)


# =============================================================================
# LOGOUT ENDPOINT
# =============================================================================

class LogoutRequest(BaseModel):
    refresh_token: str


@router.post("/logout", status_code=status.HTTP_200_OK)
async def logout(request: LogoutRequest, db: DBSession):
    """Revoke the refresh token (logout). Access token will expire naturally."""
    token_hash = hash_refresh_token(request.refresh_token)
    result = await db.execute(
        select(RefreshToken).where(RefreshToken.token_hash == token_hash)
    )
    record = result.scalar_one_or_none()
    if record and not record.is_revoked:
        record.is_revoked = True
        await db.flush()
    return {"message": "Logged out successfully"}
