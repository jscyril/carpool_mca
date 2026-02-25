"""
Async database session management.
Uses SQLAlchemy 2.0 async engine with asyncpg driver.
"""
import ssl
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from core.config import get_settings

settings = get_settings()

# Create SSL context for Supabase (skip certificate verification)
ssl_context = ssl.create_default_context()
ssl_context.check_hostname = False
ssl_context.verify_mode = ssl.CERT_NONE

# Create async engine with SSL support for Supabase
# Note: asyncpg accepts ssl context directly
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    future=True,
    connect_args={
        "ssl": ssl_context,
        "server_settings": {"application_name": "carpool_backend"}
    }
)

# Session factory
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
    autocommit=False
)


async def get_db() -> AsyncSession:
    """
    Dependency that provides a database session.
    Ensures proper cleanup after request.
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
