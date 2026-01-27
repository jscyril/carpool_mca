import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'common_widgets.dart';
import 'otp_verification.dart';
import 'personal_details.dart';
import 'driver_details.dart';
import '../home/home_screen.dart';
import '../../main.dart';

// ============================================================================
// Auth Flow Screen - Main Entry Point
// ============================================================================

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Navigation states
  AuthStep _currentStep = AuthStep.loginSignup;
  bool _isSignUp = false; // false = Login, true = SignUp

  // Phone number data
  String _countryCode = '+91';
  String _phoneNumber = '';

  void _navigateToStep(AuthStep step) {
    setState(() => _currentStep = step);
  }

  void _onPhoneSubmit(String phone, String countryCode, bool isSignUp) {
    setState(() {
      _phoneNumber = phone;
      _countryCode = countryCode;
      _isSignUp = isSignUp;
      _currentStep = AuthStep.otp;
    });
  }

  void _onOtpVerified() {
    if (_isSignUp) {
      _navigateToStep(AuthStep.personalDetails);
    } else {
      // Login complete - navigate to home
      _onAuthComplete();
    }
  }

  void _onPersonalDetailsComplete() {
    _navigateToStep(AuthStep.driverDetails);
  }

  void _onAuthComplete() async {
    // Save login state
    await AuthService.setLoggedIn(true, phone: _phoneNumber);
    
    // Navigate to home screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == AuthStep.loginSignup,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        child: _buildCurrentStep(),
      ),
    );
  }

  void _handleBackNavigation() {
    switch (_currentStep) {
      case AuthStep.otp:
        _navigateToStep(AuthStep.loginSignup);
        break;
      case AuthStep.personalDetails:
        _navigateToStep(AuthStep.otp);
        break;
      case AuthStep.driverDetails:
        _navigateToStep(AuthStep.personalDetails);
        break;
      case AuthStep.loginSignup:
        break;
    }
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case AuthStep.loginSignup:
        return _LoginSignupScreen(
          key: const ValueKey('login_signup'),
          onPhoneSubmit: _onPhoneSubmit,
        );
      case AuthStep.otp:
        return OtpVerificationScreen(
          key: const ValueKey('otp'),
          phoneNumber: _phoneNumber,
          countryCode: _countryCode,
          onVerified: _onOtpVerified,
          onBack: () => _navigateToStep(AuthStep.loginSignup),
        );
      case AuthStep.personalDetails:
        return PersonalDetailsScreen(
          key: const ValueKey('personal_details'),
          onContinue: _onPersonalDetailsComplete,
          onBack: () => _navigateToStep(AuthStep.otp),
        );
      case AuthStep.driverDetails:
        return DriverDetailsScreen(
          key: const ValueKey('driver_details'),
          onComplete: _onAuthComplete,
          onSkip: _onAuthComplete,
          onBack: () => _navigateToStep(AuthStep.personalDetails),
        );
    }
  }
}

enum AuthStep {
  loginSignup,
  otp,
  personalDetails,
  driverDetails,
}

// ============================================================================
// Login / Sign Up Screen
// ============================================================================

class _LoginSignupScreen extends StatefulWidget {
  final void Function(String phone, String countryCode, bool isSignUp) onPhoneSubmit;

  const _LoginSignupScreen({
    super.key,
    required this.onPhoneSubmit,
  });

  @override
  State<_LoginSignupScreen> createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends State<_LoginSignupScreen> {
  int _tabIndex = 0; // 0 = Log In, 1 = Sign Up
  String _countryCode = '+91';
  final _phoneCtrl = TextEditingController();
  bool _agree = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool get _isPhoneValid => _phoneCtrl.text.length >= 10;

  void _onSubmit() {
    if (!_isPhoneValid) return;
    
    HapticFeedback.lightImpact();
    widget.onPhoneSubmit(
      _phoneCtrl.text,
      _countryCode,
      _tabIndex == 1, // isSignUp
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = _tabIndex == 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              AuthAppBar(
                title: 'UNIRIDE',
                onBack: () => Navigator.maybePop(context),
              ),

              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _TopCards(),
              ),

              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _AuthTabs(
                  selectedIndex: _tabIndex,
                  onChanged: (i) => setState(() => _tabIndex = i),
                ),
              ),

              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _ContentCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        isSignUp ? 'Sign Up' : 'Welcome Back',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isSignUp
                            ? 'Enter your mobile number to get started.'
                            : 'Log in using your phone number.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kMuted, fontSize: 14),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Phone Number Label
                      const Text(
                        'PHONE NUMBER',
                        style: TextStyle(
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: kMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      
                      // Phone Number Input
                      PhoneNumberField(
                        controller: _phoneCtrl,
                      ),
                      
                      if (isSignUp) ...[
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _agree,
                              onChanged: (v) => setState(() => _agree = v ?? false),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              side: const BorderSide(color: kCardBorder),
                              activeColor: kPrimary,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Wrap(
                                  children: [
                                    const Text(
                                      'By continuing, you agree to our ',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        // TODO: Open terms
                                      },
                                      child: Text(
                                        'Terms of Service',
                                        style: TextStyle(
                                          color: kPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Text(
                                      ' and ',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        // TODO: Open privacy
                                      },
                                      child: Text(
                                        'Privacy Policy',
                                        style: TextStyle(
                                          color: kPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Text(
                                      '.',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      const SizedBox(height: 20),
                      
                      // Submit Button
                      AuthButton(
                        label: isSignUp ? 'Send OTP' : 'Get OTP',
                        icon: Icons.message_outlined,
                        onPressed: (isSignUp ? (_isPhoneValid && _agree) : _isPhoneValid)
                            ? _onSubmit
                            : null,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Social Login
                      SocialLoginButtons(
                        onGoogle: () {
                          // TODO: Google sign-in
                        },
                        onApple: () {
                          // TODO: Apple sign-in
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Text(
                '© 2023 University Carpool Inc.',
                style: TextStyle(color: kMuted.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Top Hero Cards
// ============================================================================

class _TopCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final leftWidth = (w - 36) * 0.52;
    final rightWidth = (w - 36) * 0.44;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left image card
        SizedBox(
          width: leftWidth,
          height: 190,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/community.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: kPrimary.withValues(alpha: 0.2),
                    child: Icon(Icons.people, size: 60, color: kPrimary),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                const Positioned(
                  left: 14,
                  bottom: 18,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Community',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Join 5k+\nStudents',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 14),

        // Right stacked cards
        SizedBox(
          width: rightWidth,
          child: Column(
            children: [
              Container(
                height: 84,
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: kPrimary.withValues(alpha: 0.08)),
                ),
                child: Center(
                  child: Icon(Icons.directions_car, color: kPrimary, size: 34),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 94,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: kCardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Safe Rides',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Verified campus emails\nonly.',
                      style: TextStyle(color: kMuted, height: 1.25),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}

// ============================================================================
// Auth Tab Switcher
// ============================================================================

class _AuthTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _AuthTabs({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kCardBorder),
      ),
      child: Row(
        children: [
          _TabItem(
            label: 'Log In',
            selected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
          _TabItem(
            label: 'Sign Up',
            selected: selectedIndex == 1,
            trailingDot: true,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool trailingDot;

  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailingDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = selected ? kPrimary : kMuted;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Stack(
          children: [
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: labelColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  if (trailingDot) ...[
                    const SizedBox(width: 10),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5C34B),
                        shape: BoxShape.circle,
                      ),
                    )
                  ],
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 3,
                width: selected ? 140 : 0,
                decoration: BoxDecoration(
                  color: selected ? kPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Content Card Container
// ============================================================================

class _ContentCard extends StatelessWidget {
  final Widget child;

  const _ContentCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kCardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}