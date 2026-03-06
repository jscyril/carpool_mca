import asyncio
from db.session import AsyncSessionLocal
from db.models.refresh_tokens import RefreshToken
from db.base import Base
from core.config import get_settings
from sqlalchemy.ext.asyncio import create_async_engine

async def main():
    settings = get_settings()
    engine = create_async_engine(str(settings.DATABASE_URL))
    
    async with engine.begin() as conn:
        # Create only the refresh_tokens table explicitly
        await conn.run_sync(Base.metadata.create_all, tables=[RefreshToken.__table__])
        
    print("✅ Created refresh_tokens table successfully.")

if __name__ == "__main__":
    asyncio.run(main())
