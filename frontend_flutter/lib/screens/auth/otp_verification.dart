import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'common_widgets.dart';
import '../../services/api_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String countryCode;
  final String sessionToken;
  final bool isSignUp;
  final void Function({
    String? phoneVerifiedToken,
    String? accessToken,
    Map<String, dynamic>? userData,
  })?
  onVerified;
  final Future<bool> Function()? onResendOtp;
  final VoidCallback? onBack;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.countryCode = '+91',
    required this.sessionToken,
    this.isSignUp = true,
    this.onVerified,
    this.onResendOtp,
    this.onBack,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _resendSeconds = 30;
  Timer? _timer;
  bool _isLoading = false;
  bool _canResend = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendSeconds = 30;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds <= 0) {
        timer.cancel();
        setState(() => _canResend = true);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onOtpChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    // Auto-verify when all 6 digits are entered
    if (_otp.length == 6) {
      _verifyOtp();
    }

    setState(() => _errorText = null);
  }

  void _onKeyPressed(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    if (_isLoading) return;

    final otp = _otp;
    if (otp.length != 6) {
      setState(() => _errorText = 'Please enter all 6 digits');
      return;
    }

    setState(() => _isLoading = true);

    // Call the appropriate API endpoint
    final ApiResponse response;
    if (widget.isSignUp) {
      response = await AuthApiService.verifyPhoneOtp(widget.sessionToken, otp);
    } else {
      response = await AuthApiService.loginVerifyOtp(widget.sessionToken, otp);
    }

    if (!mounted) return;

    if (response.success && response.data != null) {
      if (widget.isSignUp) {
        // Signup: pass phoneVerifiedToken to next screen
        widget.onVerified?.call(
          phoneVerifiedToken: response.data!['phone_verified_token'],
        );
      } else {
        // Login: pass accessToken and user data
        final userData = response.data!['user'] as Map<String, dynamic>?;
        widget.onVerified?.call(
          accessToken: response.data!['access_token'],
          userData: userData,
        );
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorText = response.error ?? 'Invalid OTP. Please try again.';
        for (var c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      });
    }
  }

  void _resendOtp() async {
    if (!_canResend) return;

    HapticFeedback.lightImpact();

    // Call parent's resend callback to get a fresh session token
    final success = await widget.onResendOtp?.call() ?? false;

    if (!mounted) return;

    _startResendTimer();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'OTP sent to ${widget.countryCode} ${widget.phoneNumber}'
              : 'Failed to resend OTP. Please try again.',
        ),
        backgroundColor: success ? kPrimary : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            AuthAppBar(title: 'UNIRIDE', onBack: widget.onBack),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Lock icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        color: kPrimary,
                        size: 40,
                      ),
                    ),

                    const SizedBox(height: 28),

                    const Text(
                      'Verify Your Number',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'We sent a verification code to',
                      style: TextStyle(color: kMuted, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.countryCode} ${widget.phoneNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // OTP Input Fields
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        return Container(
                          width: 48,
                          height: 56,
                          margin: EdgeInsets.only(
                            right: index < 5 ? 8 : 0,
                            left: index == 3 ? 8 : 0, // Extra gap in middle
                          ),
                          child: KeyboardListener(
                            focusNode: FocusNode(),
                            onKeyEvent: (event) => _onKeyPressed(index, event),
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: _controllers[index].text.isNotEmpty
                                    ? kPrimary.withValues(alpha: 0.08)
                                    : kBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: _errorText != null
                                        ? Colors.red.shade300
                                        : kCardBorder,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: _errorText != null
                                        ? Colors.red.shade300
                                        : kCardBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: kPrimary,
                                    width: 2,
                                  ),
                                ),
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (v) => _onOtpChanged(index, v),
                            ),
                          ),
                        );
                      }),
                    ),

                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorText!,
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontSize: 13,
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Resend OTP
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Didn't receive the code? ",
                          style: TextStyle(color: kMuted),
                        ),
                        GestureDetector(
                          onTap: _canResend ? _resendOtp : null,
                          child: Text(
                            _canResend
                                ? 'Resend OTP'
                                : 'Resend in ${_resendSeconds}s',
                            style: TextStyle(
                              color: _canResend ? kPrimary : kMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 36),

                    // Verify Button
                    AuthButton(
                      label: 'Verify & Continue',
                      icon: Icons.arrow_forward,
                      isLoading: _isLoading,
                      onPressed: _otp.length == 6 ? _verifyOtp : null,
                    ),

                    const SizedBox(height: 20),

                    // Change number link
                    TextButton(
                      onPressed: widget.onBack,
                      child: Text(
                        'Change phone number',
                        style: TextStyle(
                          color: kMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
