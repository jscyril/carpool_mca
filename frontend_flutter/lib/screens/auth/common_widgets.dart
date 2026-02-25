import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// Common Auth Theme Constants
// ============================================================================

const Color kPrimary = Color(0xFF14B08A);
const Color kMuted = Color(0xFF6B7280);
const Color kCardBorder = Color(0xFFE6EAF0);
const Color kBackground = Color(0xFFF6F7FB);

// ============================================================================
// Phone Number Input Field with Country Code
// ============================================================================

class PhoneNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;

  const PhoneNumberField({super.key, required this.controller, this.errorText});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: errorText != null ? Colors.red.shade300 : kCardBorder,
            ),
            color: Colors.white,
          ),
          child: Row(
            children: [
              // Fixed India country code
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: kCardBorder)),
                ),
                child: const Text(
                  '🇮🇳 +91',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Phone number input
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    hintText: '000 000 0000',
                    hintStyle: TextStyle(color: kMuted.withValues(alpha: 0.5)),
                    prefixIcon: Icon(Icons.phone_outlined, color: kMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: TextStyle(color: Colors.red.shade400, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// Step Progress Indicator
// ============================================================================

class AuthStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String? stepLabel;

  const AuthStepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
    this.stepLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'STEP $currentStep OF $totalSteps',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: kMuted,
            letterSpacing: 1,
          ),
        ),
        const Spacer(),
        if (stepLabel != null)
          Text(
            stepLabel!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kPrimary,
            ),
          ),
      ],
    );
  }
}

class StepProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepProgressBar({
    super.key,
    required this.currentStep,
    this.totalSteps = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isCompleted = index < currentStep;
        final isCurrent = index == currentStep - 1;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index < totalSteps - 1 ? 8 : 0),
            decoration: BoxDecoration(
              color: isCompleted || isCurrent ? kPrimary : kCardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

// ============================================================================
// Document Upload Card
// ============================================================================

class DocumentUploadCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isRequired;
  final String? imagePath;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const DocumentUploadCard({
    super.key,
    required this.title,
    this.subtitle,
    this.isRequired = false,
    this.imagePath,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF374151),
              ),
            ),
            if (isRequired) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Required',
                  style: TextStyle(
                    color: kPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kCardBorder, style: BorderStyle.solid),
            ),
            child: imagePath != null
                ? _buildImagePreview()
                : _buildUploadPlaceholder(),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: kBackground, shape: BoxShape.circle),
          child: Icon(Icons.camera_alt_outlined, color: kMuted, size: 28),
        ),
        const SizedBox(height: 12),
        Text(
          'Tap to upload front of license',
          style: TextStyle(
            color: kMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle ?? 'Supports JPG, PNG (Max 5MB)',
          style: TextStyle(color: kMuted.withValues(alpha: 0.7), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            imagePath!,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.image, size: 60, color: kMuted),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// Primary Auth Button
// ============================================================================

class AuthButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AuthButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? kPrimary,
        foregroundColor: foregroundColor ?? Colors.white,
        disabledBackgroundColor: (backgroundColor ?? kPrimary).withValues(
          alpha: 0.5,
        ),
        minimumSize: const Size.fromHeight(58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label),
                if (icon != null) ...[
                  const SizedBox(width: 10),
                  Icon(icon, size: 20),
                ],
              ],
            ),
    );
  }
}

// ============================================================================
// Outlined Auth Button (for secondary actions)
// ============================================================================

class AuthOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;

  const AuthOutlinedButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: const BorderSide(color: kCardBorder),
        foregroundColor: const Color(0xFF374151),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ============================================================================
// Auth Text Field (styled input field)
// ============================================================================

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final Widget? suffix;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.suffix,
    this.obscure = false,
    this.keyboardType,
    this.errorText,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: kMuted,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: kMuted.withValues(alpha: 0.6)),
            prefixIcon: Icon(prefixIcon, color: kMuted),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: errorText != null ? Colors.red.shade300 : kCardBorder,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: errorText != null ? Colors.red.shade300 : kCardBorder,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: kPrimary, width: 1.5),
            ),
            errorText: errorText,
            errorStyle: TextStyle(color: Colors.red.shade400),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Social Login Buttons Row
// ============================================================================

class SocialLoginButtons extends StatelessWidget {
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  const SocialLoginButtons({super.key, this.onGoogle, this.onApple});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: kCardBorder)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Or continue with',
                style: TextStyle(color: kMuted, fontSize: 13),
              ),
            ),
            Expanded(child: Divider(color: kCardBorder)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AuthOutlinedButton(
                label: 'Google',
                leading: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: onGoogle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AuthOutlinedButton(
                label: 'Apple',
                leading: const Icon(Icons.apple, size: 20),
                onPressed: onApple,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// Top App Bar for Auth Screens
// ============================================================================

class AuthAppBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const AuthAppBar({super.key, required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack ?? () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: kPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
