"""
Database initialization script.
Creates all tables in the Supabase PostgreSQL database.
"""
import asyncio
import os
import ssl
from pathlib import Path

# Load .env FIRST before any other imports
from dotenv import load_dotenv

app_dir = Path(__file__).parent
backend_dir = app_dir.parent
env_path = backend_dir / ".env"
print(f"Loading .env from: {env_path}")
load_dotenv(env_path, override=True)

# Verify the DATABASE_URL is loaded
db_url = os.getenv("DATABASE_URL")
print(f"DATABASE_URL: {db_url[:80] if db_url else 'NOT SET'}...")

if not db_url:
    print("❌ ERROR: DATABASE_URL not set in .env")
    exit(1)

import sys
sys.path.insert(0, str(app_dir))

from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text

# Import Base and ALL models so they are registered
from db.base import Base
from db.models.users import User
from db.models.vehicles import Vehicle
from db.models.rides import Ride
from db.models.ride_requests import RideRequest
from db.models.ride_participants import RideParticipant
from db.models.ride_history import RideHistory
from db.models.otp_sessions import OTPSession
from db.models.driver_profiles import DriverProfile
from db.models.emergency_contacts import EmergencyContact
from db.models.sos_alerts import SOSAlert
from db.models.ratings import Rating
from db.models.reports import Report
from db.models.fare_estimates import FareEstimate

# New models for verification system
from db.models.identity_verifications import IdentityVerification
from db.models.driver_verifications import DriverVerification
from db.models.saved_addresses import SavedAddress
from db.models.college_students import CollegeStudent


async def init_database():
    """Create all database tables."""
    
    print(f"\n🔌 Connecting to Supabase database...")
    
    # Create SSL context that doesn't verify certificates
    # Required for Supabase which uses self-signed certs in the chain
    ssl_context = ssl.create_default_context()
    ssl_context.check_hostname = False
    ssl_context.verify_mode = ssl.CERT_NONE
    
    # Pass SSL context to asyncpg
    connect_args = {
        "ssl": ssl_context,
    }
    
    engine = create_async_engine(
        db_url,
        echo=True,  # Show SQL statements
        connect_args=connect_args,
        pool_pre_ping=True
    )
    
    try:
        async with engine.begin() as conn:
            # Enable PostGIS extension first (required for geography types)
            print("\n🌍 Enabling PostGIS extension...")
            await conn.execute(text("CREATE EXTENSION IF NOT EXISTS postgis"))
            print("   PostGIS enabled!")
            
            # FRESH RESET: Drop all existing tables first
            # Remove this block after initial setup is complete
            print("\n🗑️  Dropping existing tables (fresh reset)...")
            await conn.run_sync(Base.metadata.drop_all)
            print("   Tables dropped!")
            
            print("\n📦 Creating tables...")
            # Create all tables
            await conn.run_sync(Base.metadata.create_all)
            
        print("\n✅ Database initialized successfully!")
        print("\n📋 Created tables:")
        for table in Base.metadata.sorted_tables:
            print(f"   - {table.name}")
            
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        raise
    finally:
        await engine.dispose()


if __name__ == "__main__":
    print("=" * 50)
    print("  College Carpool - Database Initialization")
    print("=" * 50)
    asyncio.run(init_database())
