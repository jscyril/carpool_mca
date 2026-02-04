import 'package:flutter/material.dart';
import 'common_widgets.dart';
import '../../main.dart';

class PersonalDetailsScreen extends StatefulWidget {
  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  const PersonalDetailsScreen({super.key, this.onContinue, this.onBack});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  DateTime? _dateOfBirth;
  bool _isLoading = false;
  String? _emailError;
  bool _isGettingLocation = false;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  bool get _isEmailValid {
    final email = _emailCtrl.text.trim().toLowerCase();
    return email.isNotEmpty && email.endsWith('@christuniversity.in');
  }

  bool get _isFormValid {
    return _fullNameCtrl.text.trim().isNotEmpty &&
        _isEmailValid &&
        _dateOfBirth != null;
    // Address is optional
  }

  void _validateEmail() {
    final email = _emailCtrl.text.trim().toLowerCase();
    setState(() {
      if (email.isEmpty) {
        _emailError = null;
      } else if (!email.endsWith('@christuniversity.in')) {
        _emailError = 'Email must end with @christuniversity.in';
      } else {
        _emailError = null;
      }
    });
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initialDate = _dateOfBirth ?? DateTime(now.year - 20);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 16), // Must be at least 16 years old
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kPrimary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  String get _formattedDob {
    if (_dateOfBirth == null) return '';
    return '${_dateOfBirth!.day.toString().padLeft(2, '0')}/'
        '${_dateOfBirth!.month.toString().padLeft(2, '0')}/'
        '${_dateOfBirth!.year}';
  }

  int? get _age {
    if (_dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - _dateOfBirth!.year;
    if (now.month < _dateOfBirth!.month ||
        (now.month == _dateOfBirth!.month && now.day < _dateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    // Simulate getting location
    // TODO: Integrate with geolocator package for real location
    await Future.delayed(const Duration(milliseconds: 1500));

    // Simulate a location result
    setState(() {
      _addressCtrl.text = 'Christ University, Hosur Road, Bangalore';
      _isGettingLocation = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Location detected successfully'),
          backgroundColor: kPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _onContinue() async {
    if (!_isFormValid) return;

    setState(() => _isLoading = true);

    // Save user profile data to SharedPreferences
    await AuthService.saveUserProfile(
      name: _fullNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      dob: _formattedDob,
      address: _addressCtrl.text.trim(),
    );

    setState(() => _isLoading = false);
    widget.onContinue?.call();
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
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Step indicator
                      const AuthStepIndicator(
                        currentStep: 2,
                        totalSteps: 3,
                        stepLabel: 'Personal Details',
                      ),
                      const SizedBox(height: 8),
                      const StepProgressBar(currentStep: 2, totalSteps: 3),

                      const SizedBox(height: 28),

                      // User avatar icon
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: kPrimary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_outline,
                            color: kPrimary,
                            size: 32,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Center(
                        child: Text(
                          'Tell us about yourself',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Center(
                        child: Text(
                          'We need a few details to set up your rider profile.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: kMuted, fontSize: 14),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Full Name
                      AuthTextField(
                        controller: _fullNameCtrl,
                        label: 'FULL NAME *',
                        hint: 'Ex. Alex Taylor',
                        prefixIcon: Icons.person_outline,
                        keyboardType: TextInputType.name,
                      ),

                      const SizedBox(height: 20),

                      // University Email
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'UNIVERSITY EMAIL *',
                            style: TextStyle(
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: kMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (_) => _validateEmail(),
                            decoration: InputDecoration(
                              hintText: 'yourname@christuniversity.in',
                              hintStyle: TextStyle(
                                color: kMuted.withValues(alpha: 0.6),
                              ),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: kMuted,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: _emailError != null
                                      ? Colors.red.shade300
                                      : kCardBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: _emailError != null
                                      ? Colors.red.shade300
                                      : kCardBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: kPrimary,
                                  width: 1.5,
                                ),
                              ),
                              errorText: _emailError,
                              errorStyle: TextStyle(color: Colors.red.shade400),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Date of Birth
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DATE OF BIRTH *',
                            style: TextStyle(
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: kMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _pickDateOfBirth,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: kCardBorder),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.cake_outlined, color: kMuted),
                                  const SizedBox(width: 12),
                                  Text(
                                    _dateOfBirth != null
                                        ? '$_formattedDob (${_age} years)'
                                        : 'Tap to select date',
                                    style: TextStyle(
                                      color: _dateOfBirth != null
                                          ? Colors.black87
                                          : kMuted.withValues(alpha: 0.6),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    color: kPrimary,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Home Address (Optional)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'HOME ADDRESS',
                                style: TextStyle(
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: kMuted,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: kBackground,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Optional',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: kMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _addressCtrl,
                            keyboardType: TextInputType.streetAddress,
                            decoration: InputDecoration(
                              hintText: '123 Campus Drive',
                              hintStyle: TextStyle(
                                color: kMuted.withValues(alpha: 0.6),
                              ),
                              prefixIcon: Icon(
                                Icons.location_on_outlined,
                                color: kMuted,
                              ),
                              suffixIcon: _isGettingLocation
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: kPrimary,
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      onPressed: _getCurrentLocation,
                                      icon: Icon(
                                        Icons.my_location,
                                        color: kPrimary,
                                      ),
                                      tooltip: 'Use current location',
                                    ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: kCardBorder,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: kCardBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: kPrimary,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 14, color: kMuted),
                              const SizedBox(width: 6),
                              Text(
                                'Tap the location icon to auto-detect address',
                                style: TextStyle(fontSize: 12, color: kMuted),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Helper text
                      Center(
                        child: Text(
                          'Next, you can optionally set up your vehicle if you plan to drive.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: kMuted, fontSize: 13),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Continue button
                      AuthButton(
                        label: 'Continue',
                        icon: Icons.arrow_forward,
                        isLoading: _isLoading,
                        onPressed: _isFormValid ? _onContinue : null,
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
