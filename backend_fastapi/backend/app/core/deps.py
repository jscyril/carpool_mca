"""
Dependency injection for FastAPI.
"""
from typing import Annotated
from fastapi import Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from db.session import AsyncSessionLocal
from db.models.users import User
from core.security import decode_token, TokenType

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login", auto_error=False)


async def get_db() -> AsyncSession:
    """Provide database session."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


async def get_current_user(
    token: Annotated[str | None, Depends(oauth2_scheme)],
    db: Annotated[AsyncSession, Depends(get_db)]
) -> User:
    """
    Get current authenticated user from JWT token.
    
    Raises:
        HTTPException: If token is invalid or user not found
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    if not token:
        raise credentials_exception
    
    payload = decode_token(token, expected_type=TokenType.ACCESS)
    if not payload:
        raise credentials_exception
    
    user_id = payload.get("sub")
    if not user_id:
        raise credentials_exception
    
    result = await db.execute(
        select(User).where(User.user_id == user_id)
    )
    user = result.scalar_one_or_none()
    
    if not user:
        raise credentials_exception
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is deactivated"
        )
    
    return user


async def get_current_active_user(
    current_user: Annotated[User, Depends(get_current_user)]
) -> User:
    """Get current user and ensure they're active."""
    return current_user


# =============================================================================
# VERIFICATION-BASED DEPENDENCIES
# Tiered access control: unverified → verified → driver → admin
# =============================================================================

async def get_verified_user(
    user: Annotated[User, Depends(get_current_active_user)]
) -> User:
    """
    Require identity-verified user.
    Used for: searching rides, viewing ride details.
    """
    if not user.is_identity_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Identity verification required to access this feature. "
                   "Please verify your college ID at POST /verification/identity"
        )
    return user


async def get_verified_driver(
    user: Annotated[User, Depends(get_verified_user)]
) -> User:
    """
    Require driver-verified user (also implies identity-verified).
    Used for: creating rides, managing vehicles.
    """
    if not user.is_driver_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Driver verification required to offer rides. "
                   "Please verify your license at POST /verification/driver"
        )
    return user


async def get_admin_user(
    user: Annotated[User, Depends(get_current_active_user)]
) -> User:
    """
    Require admin user.
    Used for: admin panel, managing verifications, viewing reports.
    """
    if not user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    return user


def get_client_ip(request: Request) -> str:
    """Extract client IP from request."""
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


# Type aliases for cleaner dependency injection
DBSession = Annotated[AsyncSession, Depends(get_db)]
CurrentUser = Annotated[User, Depends(get_current_user)]
VerifiedUser = Annotated[User, Depends(get_verified_user)]
VerifiedDriver = Annotated[User, Depends(get_verified_driver)]
AdminUser = Annotated[User, Depends(get_admin_user)]
