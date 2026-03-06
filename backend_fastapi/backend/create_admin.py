import asyncio
import sys
from app.db.session import async_session_maker
from app.db.models.users import User
from sqlalchemy import select

async def main():
    phone_number = "+919999999999"
    if len(sys.argv) > 1:
        phone_number = sys.argv[1]
        
    async with async_session_maker() as session:
        result = await session.execute(select(User).where(User.phone_number == phone_number))
        user = result.scalars().first()
        if not user:
            user = User(
                phone_number=phone_number,
                full_name="Super Admin",
                is_admin=True,
                is_identity_verified=True,
                is_driver_verified=True
            )
            session.add(user)
            await session.commit()
            print(f"✅ Created new admin account with phone: {phone_number}")
        else:
            user.is_admin = True
            await session.commit()
            print(f"✅ Updated existing account {phone_number} to be an admin")

if __name__ == "__main__":
    asyncio.run(main())
