"""
Seed Data Script — Populates the database with test data for development.

Seeds:
- College students database (for identity verification testing)
- Test users (for API testing)

Usage: python seed_data.py
"""
import asyncio
import os
import ssl
import sys
from pathlib import Path
from uuid import uuid4

from dotenv import load_dotenv

# Setup paths
backend_dir = Path(__file__).parent
app_dir = backend_dir / "app"
sys.path.insert(0, str(app_dir))

# Load Env
load_dotenv(backend_dir / ".env", override=True)

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import select

from db.base import Base
from db.models.college_students import CollegeStudent
from db.models.users import User
from db.enums import GenderEnum
from core.security import create_access_token


# =============================================================================
# COLLEGE STUDENTS DATA
# =============================================================================

COLLEGE_STUDENTS = [
    # MCA Students
    {"register_number": "2341001", "full_name": "Samuel Shine", "department": "Computer Science", "program": "MCA", "role": "student"},
    {"register_number": "2341002", "full_name": "Ananya Sharma", "department": "Computer Science", "program": "MCA", "role": "student"},
    {"register_number": "2341003", "full_name": "Rahul Kumar", "department": "Computer Science", "program": "MCA", "role": "student"},
    {"register_number": "2341004", "full_name": "Priya Nair", "department": "Computer Science", "program": "MCA", "role": "student"},
    {"register_number": "2341005", "full_name": "Aditya Menon", "department": "Computer Science", "program": "MCA", "role": "student"},
    # BCA Students
    {"register_number": "2342001", "full_name": "Kavya Reddy", "department": "Computer Science", "program": "BCA", "role": "student"},
    {"register_number": "2342002", "full_name": "Arjun Patel", "department": "Computer Science", "program": "BCA", "role": "student"},
    {"register_number": "2342003", "full_name": "Sneha Thomas", "department": "Computer Science", "program": "BCA", "role": "student"},
    {"register_number": "2342004", "full_name": "Vikram Singh", "department": "Computer Science", "program": "BCA", "role": "student"},
    {"register_number": "2342005", "full_name": "Deepika Joshi", "department": "Computer Science", "program": "BCA", "role": "student"},
    # B.Tech Students
    {"register_number": "2343001", "full_name": "Rohan Verma", "department": "Electrical Engineering", "program": "B.Tech", "role": "student"},
    {"register_number": "2343002", "full_name": "Meera Iyer", "department": "Electrical Engineering", "program": "B.Tech", "role": "student"},
    {"register_number": "2343003", "full_name": "Karthik Nag", "department": "Mechanical Engineering", "program": "B.Tech", "role": "student"},
    {"register_number": "2343004", "full_name": "Swathi Rao", "department": "Civil Engineering", "program": "B.Tech", "role": "student"},
    {"register_number": "2343005", "full_name": "Ajay Gupta", "department": "Electrical Engineering", "program": "B.Tech", "role": "student"},
    # MBA Students
    {"register_number": "2344001", "full_name": "Neha Kapoor", "department": "Business Administration", "program": "MBA", "role": "student"},
    {"register_number": "2344002", "full_name": "Siddharth Malhotra", "department": "Business Administration", "program": "MBA", "role": "student"},
    {"register_number": "2344003", "full_name": "Riya Desai", "department": "Business Administration", "program": "MBA", "role": "student"},
    # Commerce Students
    {"register_number": "2345001", "full_name": "Akash Pillai", "department": "Commerce", "program": "B.Com", "role": "student"},
    {"register_number": "2345002", "full_name": "Divya Krishnan", "department": "Commerce", "program": "B.Com", "role": "student"},
    # Faculty
    {"register_number": "FAC001", "full_name": "Dr. Ramesh Kumar", "department": "Computer Science", "program": "Faculty", "role": "faculty"},
    {"register_number": "FAC002", "full_name": "Dr. Lakshmi Priya", "department": "Computer Science", "program": "Faculty", "role": "faculty"},
    {"register_number": "FAC003", "full_name": "Prof. Sunil Mathew", "department": "Electrical Engineering", "program": "Faculty", "role": "faculty"},
]


async def seed_college_students(session: AsyncSession):
    """Seed college students (idempotent — skips existing records)."""
    print("\n📚 Seeding College Students Database...")
    added = 0
    skipped = 0
    
    for student_data in COLLEGE_STUDENTS:
        # Check if already exists
        result = await session.execute(
            select(CollegeStudent).where(
                CollegeStudent.register_number == student_data["register_number"]
            )
        )
        if result.scalar_one_or_none():
            skipped += 1
            continue
        
        student = CollegeStudent(
            id=uuid4(),
            **student_data
        )
        session.add(student)
        added += 1
    
    await session.flush()
    print(f"   ✅ Added {added} students, skipped {skipped} existing")


async def create_test_user(session: AsyncSession) -> str:
    """Create a test user and return access token."""
    print("\n🔑 Creating Test User...")
    
    PHONE = "+919876543210"
    
    result = await session.execute(
        select(User).where(User.phone_number == PHONE)
    )
    user = result.scalar_one_or_none()
    
    if not user:
        user = User(
            user_id=uuid4(),
            full_name="Samuel Shine",
            email=None,
            phone_number=PHONE,
            college_id=None,
            gender=GenderEnum.male,
            is_phone_verified=True,
            is_email_verified=False,
            is_identity_verified=False,
            is_driver_verified=False,
            is_admin=False,
            is_active=True
        )
        session.add(user)
        await session.flush()
        print(f"   ✅ Created user: {user.full_name} ({user.phone_number})")
    else:
        print(f"   User already exists: {user.full_name}")
    
    token = create_access_token(str(user.user_id))
    print(f"   🔑 Token: {token[:30]}...")
    return token


async def main():
    """Run all seed operations."""
    print("=" * 50)
    print("  College Carpool - Seed Data")
    print("=" * 50)
    
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        print("❌ DATABASE_URL not set")
        return
    
    ssl_context = ssl.create_default_context()
    ssl_context.check_hostname = False
    ssl_context.verify_mode = ssl.CERT_NONE
    
    engine = create_async_engine(
        db_url,
        connect_args={"ssl": ssl_context}
    )
    
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    async with async_session() as session:
        try:
            await seed_college_students(session)
            token = await create_test_user(session)
            await session.commit()
            
            print("\n" + "=" * 50)
            print("  ✅ Seeding Complete!")
            print(f"  📋 College students: {len(COLLEGE_STUDENTS)}")
            print(f"  🔑 Test token available for API testing")
            print("=" * 50)
        except Exception as e:
            await session.rollback()
            print(f"\n❌ Error: {e}")
            import traceback
            traceback.print_exc()
    
    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
