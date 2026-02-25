"""
Email Service - handles sending OTP via email.
Supports Console (dev) and SMTP (production).
"""
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from abc import ABC, abstractmethod
from core.config import get_settings

settings = get_settings()


class EmailProvider(ABC):
    """Abstract base class for email providers."""
    
    @abstractmethod
    async def send_otp(self, email: str, otp: str) -> bool:
        """Send OTP to email address."""
        pass


class ConsoleEmailProvider(EmailProvider):
    """Development provider that prints to console."""
    
    async def send_otp(self, email: str, otp: str) -> bool:
        print(f"\n{'='*50}")
        print(f"📧 EMAIL OTP for {email}")
        print(f"   OTP: {otp}")
        print(f"   (This is printed because EMAIL_PROVIDER=console)")
        print(f"{'='*50}\n")
        return True


class SMTPEmailProvider(EmailProvider):
    """SMTP email provider for production."""
    
    async def send_otp(self, email: str, otp: str) -> bool:
        try:
            msg = MIMEMultipart("alternative")
            msg["Subject"] = "College Carpool - Email Verification"
            msg["From"] = settings.EMAIL_FROM
            msg["To"] = email
            
            # Plain text version
            text = f"""
College Carpool - Email Verification

Your verification code is: {otp}

This code will expire in 5 minutes.

If you didn't request this code, please ignore this email.
            """
            
            # HTML version
            html = f"""
<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: Arial, sans-serif; background-color: #f4f4f4; padding: 20px; }}
        .container {{ max-width: 500px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; }}
        .otp {{ font-size: 32px; font-weight: bold; color: #4F46E5; letter-spacing: 5px; text-align: center; padding: 20px; background: #F3F4F6; border-radius: 8px; margin: 20px 0; }}
        .footer {{ color: #6B7280; font-size: 12px; margin-top: 20px; }}
    </style>
</head>
<body>
    <div class="container">
        <h2>Email Verification</h2>
        <p>Use the following code to verify your college email:</p>
        <div class="otp">{otp}</div>
        <p>This code will expire in <strong>5 minutes</strong>.</p>
        <p class="footer">If you didn't request this code, please ignore this email.</p>
    </div>
</body>
</html>
            """
            
            msg.attach(MIMEText(text, "plain"))
            msg.attach(MIMEText(html, "html"))
            
            # Send email
            with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
                server.starttls()
                server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
                server.sendmail(settings.EMAIL_FROM, email, msg.as_string())
            
            return True
        except Exception as e:
            print(f"Email send error: {e}")
            return False


def get_email_provider() -> EmailProvider:
    """Factory function to get the configured email provider."""
    if settings.EMAIL_PROVIDER.lower() == "smtp":
        return SMTPEmailProvider()
    return ConsoleEmailProvider()


class EmailService:
    """High-level email service."""
    
    def __init__(self):
        self.provider = get_email_provider()
    
    async def send_otp(self, email: str, otp: str) -> bool:
        """
        Send OTP to email address.
        
        Args:
            email: Email address
            otp: The OTP to send
        
        Returns:
            True if sent successfully
        """
        return await self.provider.send_otp(email, otp)
