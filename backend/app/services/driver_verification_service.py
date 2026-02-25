"""
Driver & Vehicle Verification Service — Pluggable providers.

Providers:
- ConsoleVerificationProvider: Auto-approves everything for dev/demo
- SurepassProvider: Stub for Surepass.io API (production use)
"""
import logging
from abc import ABC, abstractmethod

from core.config import get_settings

logger = logging.getLogger(__name__)


class VerificationProvider(ABC):
    """Abstract base class for driver/vehicle verification providers."""
    
    @abstractmethod
    async def verify_license(self, license_number: str, license_image_url: str) -> dict:
        """
        Verify a driving license.
        
        Returns:
            dict with keys: valid (bool), name (str), license_type (str),
            expiry (str), details (dict), reason (str if invalid)
        """
        pass
    
    @abstractmethod
    async def verify_vehicle_registration(self, reg_number: str, reg_image_url: str) -> dict:
        """
        Verify a vehicle registration.
        
        Returns:
            dict with keys: valid (bool), owner_name (str), vehicle_type (str),
            details (dict), reason (str if invalid)
        """
        pass


class ConsoleVerificationProvider(VerificationProvider):
    """
    Mock verification provider for development and demo.
    Auto-approves all verifications and logs the action.
    """
    
    async def verify_license(self, license_number: str, license_image_url: str) -> dict:
        logger.info(f"[ConsoleVerification] Verifying license: {license_number}")
        return {
            "valid": True,
            "name": "Demo Driver",
            "license_type": "LMV",
            "expiry": "2030-12-31",
            "details": {"provider": "console", "auto_approved": True}
        }
    
    async def verify_vehicle_registration(self, reg_number: str, reg_image_url: str) -> dict:
        logger.info(f"[ConsoleVerification] Verifying vehicle: {reg_number}")
        return {
            "valid": True,
            "owner_name": "Demo Driver",
            "vehicle_type": "4_wheeler",
            "details": {"provider": "console", "auto_approved": True}
        }


class SurepassProvider(VerificationProvider):
    """
    Surepass.io API for production license and RC verification.
    Requires: VERIFICATION_API_KEY in settings.
    Stub — implement when ready for production.
    """
    
    async def verify_license(self, license_number: str, license_image_url: str) -> dict:
        raise NotImplementedError(
            "SurepassProvider not yet implemented. "
            "Set VERIFICATION_PROVIDER=console for development. "
            "To implement: https://docs.surepass.io/api/driving-license"
        )
    
    async def verify_vehicle_registration(self, reg_number: str, reg_image_url: str) -> dict:
        raise NotImplementedError(
            "SurepassProvider not yet implemented. "
            "Set VERIFICATION_PROVIDER=console for development. "
            "To implement: https://docs.surepass.io/api/rc-verification"
        )


# =============================================================================
# Factory
# =============================================================================

_providers = {
    "console": ConsoleVerificationProvider,
    "surepass": SurepassProvider,
}


def get_verification_provider() -> VerificationProvider:
    """Get the configured verification provider instance."""
    settings = get_settings()
    provider_name = getattr(settings, 'VERIFICATION_PROVIDER', 'console')
    
    provider_class = _providers.get(provider_name)
    if not provider_class:
        raise ValueError(
            f"Unknown VERIFICATION_PROVIDER: {provider_name}. "
            f"Options: {', '.join(_providers.keys())}"
        )
    
    logger.info(f"Using verification provider: {provider_name}")
    return provider_class()
