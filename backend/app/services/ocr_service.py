"""
OCR Service - Pluggable providers for extracting text from college ID images.

Providers:
- ConsoleOCRProvider: Mock OCR for dev/demo (always returns sample data)
- TesseractOCRProvider: Local OCR using pytesseract (free but less accurate)
- GoogleVisionOCRProvider: Cloud OCR via Google Vision API (production quality)
"""
import logging
import re
from abc import ABC, abstractmethod
from dataclasses import dataclass

from core.config import get_settings

logger = logging.getLogger(__name__)


@dataclass
class OCRResult:
    """Standardized OCR extraction result."""
    name: str | None = None
    register_number: str | None = None
    raw_text: str = ""
    confidence: float = 0.0


class OCRProvider(ABC):
    """Abstract base class for OCR providers."""
    
    @abstractmethod
    async def extract_text(self, image_url: str) -> OCRResult:
        """
        Extract name and register number from a college ID image.
        
        Args:
            image_url: URL or path to the uploaded college ID image
            
        Returns:
            OCRResult with extracted name, register_number, and raw_text
        """
        pass


class ConsoleOCRProvider(OCRProvider):
    """
    Mock OCR provider for development and demo.
    Returns simulated extraction results and logs actions.
    """
    
    async def extract_text(self, image_url: str) -> OCRResult:
        logger.info(f"[ConsoleOCR] Processing image: {image_url}")
        
        # Try to extract register number from URL/filename for demo convenience
        # e.g., if image is named "REG2341001_JohnDoe.jpg"
        reg_match = re.search(r'(REG\d{7}|\d{7,10})', image_url)
        name_match = re.search(r'_([A-Za-z]+(?:_[A-Za-z]+)*)\.\w+$', image_url)
        
        register_number = reg_match.group(0) if reg_match else "REG2341001"
        name = name_match.group(1).replace('_', ' ') if name_match else "Demo Student"
        
        result = OCRResult(
            name=name,
            register_number=register_number,
            raw_text=f"CHRIST UNIVERSITY\nStudent ID Card\nName: {name}\nRegister No: {register_number}\nDepartment: Computer Science\nProgram: MCA",
            confidence=0.95
        )
        
        logger.info(f"[ConsoleOCR] Extracted — Name: {result.name}, Reg: {result.register_number}")
        return result


class TesseractOCRProvider(OCRProvider):
    """
    Local OCR using Tesseract (pytesseract).
    Requires: pip install pytesseract Pillow, and tesseract-ocr system binary.
    """
    
    async def extract_text(self, image_url: str) -> OCRResult:
        try:
            import pytesseract
            from PIL import Image
            import httpx
        except ImportError:
            raise RuntimeError(
                "TesseractOCR requires: pip install pytesseract Pillow httpx\n"
                "Also install tesseract-ocr: brew install tesseract (macOS)"
            )
        
        # Download image if URL, or open local file
        if image_url.startswith(("http://", "https://")):
            async with httpx.AsyncClient() as client:
                response = await client.get(image_url)
                response.raise_for_status()
                import io
                image = Image.open(io.BytesIO(response.content))
        else:
            image = Image.open(image_url)
        
        # Extract text
        raw_text = pytesseract.image_to_string(image)
        
        logger.info(f"[TesseractOCR] Raw text extracted ({len(raw_text)} chars)")
        
        # Parse register number — common patterns for Indian university IDs
        register_number = None
        reg_patterns = [
            r'REG\s*\.?\s*(?:No|Number|#)?\s*[:\-]?\s*(\w{7,15})',
            r'Register\s*(?:No|Number|#)?\s*[:\-]?\s*(\w{7,15})',
            r'Roll\s*(?:No|Number|#)?\s*[:\-]?\s*(\w{7,15})',
            r'\b(\d{7,10})\b',  # Fallback: any 7-10 digit number
        ]
        for pattern in reg_patterns:
            match = re.search(pattern, raw_text, re.IGNORECASE)
            if match:
                register_number = match.group(1).strip()
                break
        
        # Parse name
        name = None
        name_patterns = [
            r'Name\s*[:\-]\s*([A-Za-z\s\.]+)',
            r'Student\s*Name\s*[:\-]\s*([A-Za-z\s\.]+)',
        ]
        for pattern in name_patterns:
            match = re.search(pattern, raw_text, re.IGNORECASE)
            if match:
                name = match.group(1).strip()
                break
        
        return OCRResult(
            name=name,
            register_number=register_number,
            raw_text=raw_text,
            confidence=0.7  # Tesseract typical accuracy
        )


class GoogleVisionOCRProvider(OCRProvider):
    """
    Google Cloud Vision API for production OCR.
    Requires: GOOGLE_VISION_API_KEY in settings.
    Stub implementation — activate when ready for production.
    """
    
    async def extract_text(self, image_url: str) -> OCRResult:
        raise NotImplementedError(
            "GoogleVisionOCR is not yet implemented. "
            "Set OCR_PROVIDER=console or OCR_PROVIDER=tesseract for now. "
            "To implement: pip install google-cloud-vision, configure service account."
        )


# =============================================================================
# Factory
# =============================================================================

_providers = {
    "console": ConsoleOCRProvider,
    "tesseract": TesseractOCRProvider,
    "google_vision": GoogleVisionOCRProvider,
}


def get_ocr_provider() -> OCRProvider:
    """Get the configured OCR provider instance."""
    settings = get_settings()
    provider_name = getattr(settings, 'OCR_PROVIDER', 'console')
    
    provider_class = _providers.get(provider_name)
    if not provider_class:
        raise ValueError(
            f"Unknown OCR_PROVIDER: {provider_name}. "
            f"Options: {', '.join(_providers.keys())}"
        )
    
    logger.info(f"Using OCR provider: {provider_name}")
    return provider_class()
