"""
OTP Service - handles OTP generation, storage, validation, and rate limiting.
"""
import uuid
from datetime import datetime, timedelta, timezone
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from core.config import get_settings
from core.security import generate_otp, hash_otp, verify_otp
from db.models.otp_sessions import OTPSession, IdentifierType

settings = get_settings()


class OTPError(Exception):
    """Base exception for OTP operations."""
    def __init__(self, message: str, error_code: str):
        self.message = message
        self.error_code = error_code
        super().__init__(message)


class RateLimitExceeded(OTPError):
    """Raised when too many OTP requests are made."""
    pass


class OTPExpired(OTPError):
    """Raised when OTP has expired."""
    pass


class MaxAttemptsExceeded(OTPError):
    """Raised when max verification attempts exceeded."""
    pass


class InvalidOTP(OTPError):
    """Raised when OTP is incorrect."""
    pass


class SessionNotFound(OTPError):
    """Raised when OTP session doesn't exist."""
    pass


class OTPService:
    """Service for OTP operations with security features."""
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def check_rate_limit(
        self,
        identifier: str,
        identifier_type: IdentifierType,
        ip_address: str | None = None
    ) -> None:
        """
        Check if identifier has exceeded rate limit.
        
        Raises:
            RateLimitExceeded: If too many requests in the time window
        """
        one_hour_ago = datetime.now(timezone.utc) - timedelta(hours=1)
        
        query = select(func.count()).where(
            and_(
                OTPSession.identifier == identifier,
                OTPSession.identifier_type == identifier_type,
                OTPSession.created_at >= one_hour_ago
            )
        )
        
        result = await self.db.execute(query)
        count = result.scalar()
        
        if count >= settings.OTP_RATE_LIMIT_PER_HOUR:
            raise RateLimitExceeded(
                f"Too many OTP requests. Try again in 1 hour.",
                "RATE_LIMIT_EXCEEDED"
            )
    
    async def check_cooldown(
        self,
        identifier: str,
        identifier_type: IdentifierType
    ) -> int | None:
        """
        Check if resend cooldown is active.
        
        Returns:
            Seconds remaining in cooldown, or None if no cooldown
        """
        cooldown_start = datetime.now(timezone.utc) - timedelta(
            seconds=settings.OTP_RESEND_COOLDOWN_SECONDS
        )
        
        query = select(OTPSession).where(
            and_(
                OTPSession.identifier == identifier,
                OTPSession.identifier_type == identifier_type,
                OTPSession.created_at >= cooldown_start,
                OTPSession.is_verified == False
            )
        ).order_by(OTPSession.created_at.desc()).limit(1)
        
        result = await self.db.execute(query)
        session = result.scalar_one_or_none()
        
        if session:
            elapsed = (datetime.now(timezone.utc) - session.created_at.replace(tzinfo=timezone.utc)).total_seconds()
            remaining = settings.OTP_RESEND_COOLDOWN_SECONDS - int(elapsed)
            if remaining > 0:
                return remaining
        
        return None
    
    async def create_otp_session(
        self,
        identifier: str,
        identifier_type: IdentifierType,
        ip_address: str | None = None
    ) -> tuple[OTPSession, str]:
        """
        Create a new OTP session.
        
        Args:
            identifier: Phone or email
            identifier_type: Type of identifier
            ip_address: Client IP for tracking
        
        Returns:
            Tuple of (OTPSession, plain_otp)
        
        Raises:
            RateLimitExceeded: If rate limit exceeded
        """
        # Check rate limit
        await self.check_rate_limit(identifier, identifier_type, ip_address)
        
        # Check cooldown
        cooldown = await self.check_cooldown(identifier, identifier_type)
        if cooldown:
            raise RateLimitExceeded(
                f"Please wait {cooldown} seconds before requesting another OTP",
                "COOLDOWN_ACTIVE"
            )
        
        # Generate OTP
        plain_otp = generate_otp()
        otp_hashed = hash_otp(plain_otp)
        
        # Calculate expiry
        expires_at = datetime.now(timezone.utc) + timedelta(
            minutes=settings.OTP_EXPIRE_MINUTES
        )
        
        # Create session
        session = OTPSession(
            session_id=uuid.uuid4(),
            identifier=identifier,
            identifier_type=identifier_type,
            otp_hash=otp_hashed,
            attempts=0,
            is_verified=False,
            is_expired=False,
            expires_at=expires_at,
            ip_address=ip_address
        )
        
        self.db.add(session)
        await self.db.flush()
        
        return session, plain_otp
    
    async def get_session(self, session_id: uuid.UUID) -> OTPSession | None:
        """Get OTP session by ID."""
        query = select(OTPSession).where(OTPSession.session_id == session_id)
        result = await self.db.execute(query)
        return result.scalar_one_or_none()
    
    async def verify_otp_session(
        self,
        session_id: uuid.UUID,
        plain_otp: str
    ) -> OTPSession:
        """
        Verify OTP for a session.
        
        Args:
            session_id: Session UUID
            plain_otp: User-provided OTP
        
        Returns:
            Verified OTPSession
        
        Raises:
            SessionNotFound: Session doesn't exist
            OTPExpired: OTP has expired
            MaxAttemptsExceeded: Too many wrong attempts
            InvalidOTP: OTP doesn't match
        """
        session = await self.get_session(session_id)
        
        if not session:
            raise SessionNotFound(
                "OTP session not found or expired",
                "SESSION_NOT_FOUND"
            )
        
        # Check if already verified
        if session.is_verified:
            raise OTPError(
                "This OTP has already been used",
                "ALREADY_VERIFIED"
            )
        
        # Check expiry
        if datetime.now(timezone.utc) > session.expires_at.replace(tzinfo=timezone.utc):
            session.is_expired = True
            await self.db.flush()
            raise OTPExpired(
                "OTP has expired. Please request a new one.",
                "OTP_EXPIRED"
            )
        
        # Check attempts
        if session.attempts >= settings.OTP_MAX_ATTEMPTS:
            session.is_expired = True
            await self.db.flush()
            raise MaxAttemptsExceeded(
                "Too many failed attempts. Please request a new OTP.",
                "MAX_ATTEMPTS_EXCEEDED"
            )
        
        # Verify OTP
        if not verify_otp(plain_otp, session.otp_hash):
            session.attempts += 1
            remaining = settings.OTP_MAX_ATTEMPTS - session.attempts
            await self.db.flush()
            raise InvalidOTP(
                f"Invalid OTP. {remaining} attempts remaining.",
                "INVALID_OTP"
            )
        
        # Mark as verified
        session.is_verified = True
        session.verified_at = datetime.now(timezone.utc)
        await self.db.flush()
        
        return session
