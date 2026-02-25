"""
Application configuration settings.
Uses pydantic-settings for environment variable management.
"""
from pydantic_settings import BaseSettings
from functools import lru_cache
import re


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # App
    APP_NAME: str = "College Carpool API"
    DEBUG: bool = False
    
    # Database
    DATABASE_URL: str = "postgresql+asyncpg://user:password@localhost/carpool_db"
    
    # JWT
    JWT_SECRET_KEY: str = "your-super-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # OTP Settings
    OTP_LENGTH: int = 6
    OTP_EXPIRE_MINUTES: int = 5
    OTP_MAX_ATTEMPTS: int = 3
    OTP_RESEND_COOLDOWN_SECONDS: int = 60
    OTP_RATE_LIMIT_PER_HOUR: int = 5
    
    # Verification Token Settings
    PHONE_VERIFIED_TOKEN_EXPIRE_MINUTES: int = 30
    EMAIL_VERIFIED_TOKEN_EXPIRE_MINUTES: int = 30
    
    # College Email Pattern (regex)
    # Pattern: *****@***christuniversity.in
    COLLEGE_EMAIL_PATTERN: str = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]*christuniversity\.in$"
    
    # SMS Service (MSG91 / Twilio)
    SMS_PROVIDER: str = "console"  # "console" | "msg91" | "twilio"
    SMS_API_KEY: str = ""
    SMS_SENDER_ID: str = "CARPOOL"
    
    # Email Service
    EMAIL_PROVIDER: str = "console"  # "console" | "smtp"
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    EMAIL_FROM: str = "noreply@christuniversity.in"
    
    # Rate Limiting
    RATE_LIMIT_ENABLED: bool = True
    
    # OCR Service
    OCR_PROVIDER: str = "console"  # "console" | "tesseract" | "google_vision"
    
    # Driver/Vehicle Verification Service
    VERIFICATION_PROVIDER: str = "console"  # "console" | "surepass"
    VERIFICATION_API_KEY: str = ""
    
    def is_valid_college_email(self, email: str) -> bool:
        """Check if email matches college email pattern."""
        return bool(re.match(self.COLLEGE_EMAIL_PATTERN, email.lower()))
    
    class Config:
        env_file = (".env", "../.env")
        env_file_encoding = "utf-8"
        case_sensitive = True
        extra = "ignore"


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
