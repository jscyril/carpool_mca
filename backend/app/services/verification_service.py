"""
Verification Service - Handles identity and driver verification logic.

Identity verification flow:
1. User uploads college ID image
2. OCR extracts name + register number
3. Cross-verify against college_students table
4. Auto-approve on match, flag for admin review on partial match, reject if not found

Driver verification flow:
1. User uploads license + vehicle registration docs
2. Provider verifies documents
3. Auto-approve (console) or manual review (production)
"""
import logging
from difflib import SequenceMatcher
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from db.models.users import User
from db.models.identity_verifications import IdentityVerification
from db.models.driver_verifications import DriverVerification
from db.models.college_students import CollegeStudent
from db.enums import VerificationStatusEnum
from services.ocr_service import get_ocr_provider

logger = logging.getLogger(__name__)

# Threshold for fuzzy name matching (0.0 to 1.0)
NAME_MATCH_THRESHOLD = 0.75


def _fuzzy_match(a: str, b: str) -> float:
    """Case-insensitive fuzzy string matching ratio."""
    return SequenceMatcher(None, a.lower().strip(), b.lower().strip()).ratio()


async def verify_college_identity(
    db: AsyncSession,
    user_id: UUID,
    image_url: str
) -> IdentityVerification:
    """
    Verify a user's college identity via OCR + DB lookup.
    
    Flow:
    1. OCR extracts name + register_number from the uploaded ID image
    2. Look up register_number in college_students table
    3. If found, fuzzy-match the name
    4. Set verification status based on match results
    """
    ocr_provider = get_ocr_provider()
    
    # Step 1: OCR extraction
    ocr_result = await ocr_provider.extract_text(image_url)
    logger.info(
        f"OCR result for user {user_id}: "
        f"name={ocr_result.name}, reg={ocr_result.register_number}"
    )
    
    # Step 2: DB lookup
    status = VerificationStatusEnum.rejected
    matched_student_id = None
    admin_notes = None
    
    if ocr_result.register_number:
        result = await db.execute(
            select(CollegeStudent).where(
                CollegeStudent.register_number == ocr_result.register_number,
                CollegeStudent.is_active == True
            )
        )
        student = result.scalar_one_or_none()
        
        if student:
            # Step 3: Name matching
            if ocr_result.name:
                match_ratio = _fuzzy_match(ocr_result.name, student.full_name)
                logger.info(
                    f"Name match: OCR='{ocr_result.name}' vs DB='{student.full_name}' "
                    f"→ ratio={match_ratio:.2f}"
                )
                
                if match_ratio >= NAME_MATCH_THRESHOLD:
                    # Strong match — auto-verify
                    status = VerificationStatusEnum.verified
                    matched_student_id = student.id
                    admin_notes = f"Auto-verified: name match {match_ratio:.0%}"
                else:
                    # Weak match — needs admin review
                    status = VerificationStatusEnum.pending
                    matched_student_id = student.id
                    admin_notes = (
                        f"Register number matches but name is weak: "
                        f"OCR='{ocr_result.name}' vs DB='{student.full_name}' "
                        f"(ratio={match_ratio:.0%})"
                    )
            else:
                # No name extracted — needs admin review
                status = VerificationStatusEnum.pending
                matched_student_id = student.id
                admin_notes = "Register number matches but OCR could not extract name"
        else:
            admin_notes = f"Register number '{ocr_result.register_number}' not found in college database"
    else:
        admin_notes = "OCR could not extract register number from image"
    
    # Step 4: Create verification record
    verification = IdentityVerification(
        user_id=user_id,
        college_id_image_url=image_url,
        extracted_name=ocr_result.name,
        extracted_register_number=ocr_result.register_number,
        matched_student_id=matched_student_id,
        status=status,
        admin_notes=admin_notes
    )
    db.add(verification)
    
    # Step 5: Update user if auto-verified
    if status == VerificationStatusEnum.verified and matched_student_id:
        result = await db.execute(
            select(User).where(User.user_id == user_id)
        )
        user = result.scalar_one()
        user.is_identity_verified = True
        
        # Also set college_id from the matched student record
        student_result = await db.execute(
            select(CollegeStudent).where(CollegeStudent.id == matched_student_id)
        )
        matched = student_result.scalar_one()
        user.college_id = matched.register_number
    
    await db.flush()
    
    logger.info(f"Identity verification for user {user_id}: status={status.value}")
    return verification
