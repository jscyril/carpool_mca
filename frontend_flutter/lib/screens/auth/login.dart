import 'package:flutter/material.dart';

enum UserRole { student, faculty }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int _tabIndex = 1; // 0 = Log In, 1 = Sign Up (default like screenshot)

  // Sign up form state
  UserRole _role = UserRole.student;
  bool _agree = false;
  bool _obscure = true;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  static const Color kPrimary = Color(0xFF14B08A);
  static const Color kMuted = Color(0xFF6B7280);
  static const Color kCardBorder = Color(0xFFE6EAF0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              _TopBar(
                title: "UNIRIDE",
                onBack: () => Navigator.maybePop(context),
              ),

              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _TopCards(
                  primary: kPrimary,
                  cardBorder: kCardBorder,
                ),
              ),

              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _AuthTabs(
                  selectedIndex: _tabIndex,
                  primary: kPrimary,
                  onChanged: (i) => setState(() => _tabIndex = i),
                ),
              ),

              // Content area (only Sign Up UI shown here to match screenshot)
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _ContentCard(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _tabIndex == 0
                        ? _LoginPlaceholder(primary: kPrimary)
                        : _SignUpForm(
                      primary: kPrimary,
                      muted: kMuted,
                      cardBorder: kCardBorder,
                      role: _role,
                      onRoleChanged: (r) => setState(() => _role = r),
                      emailCtrl: _emailCtrl,
                      passCtrl: _passCtrl,
                      obscure: _obscure,
                      onToggleObscure: () =>
                          setState(() => _obscure = !_obscure),
                      agree: _agree,
                      onAgreeChanged: (v) =>
                          setState(() => _agree = v ?? false),
                      onSubmit: () {
                        // TODO: call your signup API
                      },
                      onGoogle: () {
                        // TODO: google sign-in
                      },
                      onApple: () {
                        // TODO: apple sign-in
                      },
                      onTerms: () {
                        // TODO: open terms
                      },
                      onPrivacy: () {
                        // TODO: open privacy
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),
              const Text(
                "© 2023 University Carpool Inc.",
                style: TextStyle(color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _TopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48), // to balance the back button
        ],
      ),
    );
  }
}

class _TopCards extends StatelessWidget {
  final Color primary;
  final Color cardBorder;

  const _TopCards({required this.primary, required this.cardBorder});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final leftWidth = (w - 36) * 0.52; // approx like screenshot (left bigger)
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
                // If you don't have an asset yet, you can temporarily use Image.network(...)
                Image.asset(
                  "assets/images/community.jpg",
                  fit: BoxFit.cover,
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
                        "Community",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Join 5k+\nStudents",
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
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: primary.withValues(alpha: 0.08)),
                ),
                child: Center(
                  child: Icon(Icons.directions_car, color: primary, size: 34),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 94,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Safe Rides",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Verified campus emails\nonly.",
                      style: TextStyle(color: Color(0xFF6B7280), height: 1.25),
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

class _AuthTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Color primary;

  const _AuthTabs({
    required this.selectedIndex,
    required this.onChanged,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Row(
        children: [
          _TabItem(
            label: "Log In",
            selected: selectedIndex == 0,
            primary: primary,
            onTap: () => onChanged(0),
          ),
          _TabItem(
            label: "Sign Up",
            selected: selectedIndex == 1,
            primary: primary,
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
  final Color primary;
  final VoidCallback onTap;
  final bool trailingDot;

  const _TabItem({
    required this.label,
    required this.selected,
    required this.primary,
    required this.onTap,
    this.trailingDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = selected ? primary : const Color(0xFF9CA3AF);

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
            // Bottom indicator line (like screenshot)
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 3,
                width: selected ? 140 : 0,
                decoration: BoxDecoration(
                  color: selected ? primary : Colors.transparent,
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

class _ContentCard extends StatelessWidget {
  final Widget child;

  const _ContentCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6EAF0)),
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

class _LoginPlaceholder extends StatelessWidget {
  final Color primary;
  const _LoginPlaceholder({required this.primary});

  @override
  Widget build(BuildContext context) {
    // Just a placeholder so the tab switch works.
    // You can build a similar Login form later.
    return Column(
      key: const ValueKey("login"),
      children: [
        const Text(
          "Log In",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          "Build your login form here.",
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text("Continue"),
        ),
      ],
    );
  }
}

class _SignUpForm extends StatelessWidget {
  final Color primary;
  final Color muted;
  final Color cardBorder;

  final UserRole role;
  final ValueChanged<UserRole> onRoleChanged;

  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;

  final bool obscure;
  final VoidCallback onToggleObscure;

  final bool agree;
  final ValueChanged<bool?> onAgreeChanged;

  final VoidCallback onSubmit;
  final VoidCallback onGoogle;
  final VoidCallback onApple;

  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  const _SignUpForm({
    super.key,
    required this.primary,
    required this.muted,
    required this.cardBorder,
    required this.role,
    required this.onRoleChanged,
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.agree,
    required this.onAgreeChanged,
    required this.onSubmit,
    required this.onGoogle,
    required this.onApple,
    required this.onTerms,
    required this.onPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey("signup"),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        const Text(
          "Create Account",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          "Start your campus commute today.",
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 16),
        ),
        const SizedBox(height: 18),

        // Student / Faculty segmented control (Material 3)
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7FB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: SegmentedButton<UserRole>(
            segments: const [
              ButtonSegment(value: UserRole.student, label: Text("Student")),
              ButtonSegment(value: UserRole.faculty, label: Text("Faculty")),
            ],
            selected: {role},
            onSelectionChanged: (set) => onRoleChanged(set.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return Colors.white;
                return Colors.transparent;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return primary;
                return const Color(0xFF374151);
              }),
              textStyle: WidgetStateProperty.all(
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              side: WidgetStateProperty.all(BorderSide(color: cardBorder)),
            ),
          ),
        ),

        const SizedBox(height: 18),
        const Text(
          "UNIVERSITY EMAIL",
          style: TextStyle(
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        _Field(
          controller: emailCtrl,
          hint: "student_id@university.edu",
          prefix: Icons.school_outlined,
          keyboardType: TextInputType.emailAddress,
        ),

        const SizedBox(height: 16),
        const Text(
          "PASSWORD",
          style: TextStyle(
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        _Field(
          controller: passCtrl,
          hint: "••••••••",
          prefix: Icons.lock_outline,
          obscure: obscure,
          suffix: IconButton(
            onPressed: onToggleObscure,
            icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          ),
        ),

        const SizedBox(height: 12),
        Row(
          children: [
            Checkbox(
              value: agree,
              onChanged: onAgreeChanged,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            Expanded(
              child: Wrap(
                children: [
                  const Text("I agree to the "),
                  InkWell(
                    onTap: onTerms,
                    child: Text("Terms of Service", style: TextStyle(color: primary)),
                  ),
                  const Text(" and "),
                  InkWell(
                    onTap: onPrivacy,
                    child: Text("Privacy Policy", style: TextStyle(color: primary)),
                  ),
                  const Text("."),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: agree ? onSubmit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: primary.withValues(alpha: 0.4),
            minimumSize: const Size.fromHeight(62),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Create Account"),
              SizedBox(width: 10),
              Icon(Icons.arrow_forward),
            ],
          ),
        ),

        const SizedBox(height: 18),
        Row(
          children: const [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text("Or continue with", style: TextStyle(color: Color(0xFF9CA3AF))),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onGoogle,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: const BorderSide(color: Color(0xFFE6EAF0)),
                ),
                child: const Text("Google", style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: onApple,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: const BorderSide(color: Color(0xFFE6EAF0)),
                ),
                child: const Text("Apple", style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefix;
  final Widget? suffix;
  final bool obscure;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.hint,
    required this.prefix,
    this.suffix,
    this.obscure = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(prefix),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE6EAF0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE6EAF0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF14B08A), width: 1.5),
        ),
      ),
    );
  }
}