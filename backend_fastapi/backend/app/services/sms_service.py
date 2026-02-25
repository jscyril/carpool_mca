"""
SMS Service - handles sending OTP via SMS.
Supports multiple providers: Console (dev), MSG91, Twilio
"""
import httpx
from abc import ABC, abstractmethod
from core.config import get_settings

settings = get_settings()


class SMSProvider(ABC):
    """Abstract base class for SMS providers."""
    
    @abstractmethod
    async def send_otp(self, phone: str, otp: str) -> bool:
        """Send OTP to phone number."""
        pass


class ConsoleSMSProvider(SMSProvider):
    """Development provider that prints to console."""
    
    async def send_otp(self, phone: str, otp: str) -> bool:
        print(f"\n{'='*50}")
        print(f"📱 SMS OTP for {phone}")
        print(f"   OTP: {otp}")
        print(f"   (This is printed because SMS_PROVIDER=console)")
        print(f"{'='*50}\n")
        return True


class MSG91Provider(SMSProvider):
    """MSG91 SMS provider for production."""
    
    BASE_URL = "https://api.msg91.com/api/v5/otp"
    
    async def send_otp(self, phone: str, otp: str) -> bool:
        # Remove + prefix for MSG91
        phone_clean = phone.lstrip("+")
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.BASE_URL}",
                headers={
                    "authkey": settings.SMS_API_KEY,
                    "Content-Type": "application/json"
                },
                json={
                    "mobile": phone_clean,
                    "otp": otp,
                    "sender": settings.SMS_SENDER_ID,
                    "message": f"Your College Carpool verification code is {otp}. Valid for 5 minutes.",
                }
            )
            return response.status_code == 200


class TwilioProvider(SMSProvider):
    """Twilio SMS provider for production."""
    
    async def send_otp(self, phone: str, otp: str) -> bool:
        # Twilio implementation would go here
        # For now, fallback to console
        print(f"[Twilio] Would send OTP {otp} to {phone}")
        return True


def get_sms_provider() -> SMSProvider:
    """Factory function to get the configured SMS provider."""
    providers = {
        "console": ConsoleSMSProvider,
        "msg91": MSG91Provider,
        "twilio": TwilioProvider,
    }
    
    provider_class = providers.get(settings.SMS_PROVIDER.lower(), ConsoleSMSProvider)
    return provider_class()


class SMSService:
    """High-level SMS service."""
    
    def __init__(self):
        self.provider = get_sms_provider()
    
    async def send_otp(self, phone: str, otp: str) -> bool:
        """
        Send OTP to phone number.
        
        Args:
            phone: Phone number with country code
            otp: The OTP to send
        
        Returns:
            True if sent successfully
        """
        return await self.provider.send_otp(phone, otp)
