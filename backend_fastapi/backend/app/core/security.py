"""
Security utilities for authentication.
Includes JWT handling and OTP generation (passwordless system).
"""
import secrets
import hashlib
from datetime import datetime, timedelta, timezone
from typing import Any

from jose import jwt, JWTError

from core.config import get_settings

settings = get_settings()


# =============================================================================
# OTP UTILITIES
# =============================================================================

def generate_otp(length: int = None) -> str:
    """Generate a random numeric OTP."""
    length = length or settings.OTP_LENGTH
    return "".join(secrets.choice("0123456789") for _ in range(length))


def hash_otp(otp: str) -> str:
    """Hash OTP using SHA256 for secure storage."""
    return hashlib.sha256(otp.encode()).hexdigest()


def verify_otp(plain_otp: str, hashed_otp: str) -> bool:
    """Verify an OTP against its hash."""
    return hash_otp(plain_otp) == hashed_otp


# =============================================================================
# JWT UTILITIES
# =============================================================================

class TokenType:
    """Token type constants for JWT purpose claims."""
    ACCESS = "access"
    PHONE_SESSION = "phone_session"
    PHONE_VERIFIED = "phone_verified"
    EMAIL_SESSION = "email_session"
    EMAIL_VERIFIED = "email_verified"


def create_token(
    data: dict[str, Any],
    token_type: str,
    expires_delta: timedelta | None = None
) -> str:
    """
    Create a JWT token with specified type and expiry.
    
    Args:
        data: Payload data to encode
        token_type: Type of token (access, phone_session, etc.)
        expires_delta: Optional custom expiry duration
    
    Returns:
        Encoded JWT string
    """
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    
    to_encode.update({
        "exp": expire,
        "iat": datetime.now(timezone.utc),
        "type": token_type
    })
    
    return jwt.encode(
        to_encode,
        settings.JWT_SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM
    )


def decode_token(token: str, expected_type: str | None = None) -> dict[str, Any] | None:
    """
    Decode and validate a JWT token.
    
    Args:
        token: JWT string to decode
        expected_type: If provided, validates the token type matches
    
    Returns:
        Decoded payload or None if invalid
    """
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM]
        )
        
        # Validate token type if specified
        if expected_type and payload.get("type") != expected_type:
            return None
        
        return payload
    except JWTError:
        return None


def create_access_token(user_id: str) -> str:
    """Create an access token for authenticated user."""
    return create_token(
        data={"sub": user_id},
        token_type=TokenType.ACCESS,
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )


def create_phone_session_token(session_id: str, phone: str) -> str:
    """Create a session token for phone OTP verification flow."""
    return create_token(
        data={"session_id": session_id, "phone": phone},
        token_type=TokenType.PHONE_SESSION,
        expires_delta=timedelta(minutes=settings.OTP_EXPIRE_MINUTES)
    )


def create_phone_verified_token(phone: str) -> str:
    """Create a token indicating phone is verified (used for registration)."""
    return create_token(
        data={"phone": phone, "verified": True},
        token_type=TokenType.PHONE_VERIFIED,
        expires_delta=timedelta(minutes=settings.PHONE_VERIFIED_TOKEN_EXPIRE_MINUTES)
    )


def create_email_session_token(session_id: str, email: str) -> str:
    """Create a session token for email OTP verification flow."""
    return create_token(
        data={"session_id": session_id, "email": email},
        token_type=TokenType.EMAIL_SESSION,
        expires_delta=timedelta(minutes=settings.OTP_EXPIRE_MINUTES)
    )


def create_email_verified_token(email: str, phone: str) -> str:
    """Create a token indicating email is verified (used for registration)."""
    return create_token(
        data={"email": email, "phone": phone, "verified": True},
        token_type=TokenType.EMAIL_VERIFIED,
        expires_delta=timedelta(minutes=settings.EMAIL_VERIFIED_TOKEN_EXPIRE_MINUTES)
    )
