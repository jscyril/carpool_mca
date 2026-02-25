import 'package:flutter/material.dart';
import 'common_widgets.dart';

class DriverDetailsScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;

  const DriverDetailsScreen({
    super.key,
    this.onComplete,
    this.onSkip,
    this.onBack,
  });

  @override
  State<DriverDetailsScreen> createState() => _DriverDetailsScreenState();
}

class _DriverDetailsScreenState extends State<DriverDetailsScreen> {
  final _vehicleModelCtrl = TextEditingController();
  final _licensePlateCtrl = TextEditingController();

  String? _driverLicensePath;
  String? _vehicleDocPath;
  bool _isLoading = false;

  @override
  void dispose() {
    _vehicleModelCtrl.dispose();
    _licensePlateCtrl.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return _vehicleModelCtrl.text.trim().isNotEmpty &&
        _licensePlateCtrl.text.trim().isNotEmpty &&
        _driverLicensePath != null;
  }

  Future<void> _pickDriverLicense() async {
    // TODO: Implement actual image picker
    // For now, simulate a selection
    await Future.delayed(const Duration(milliseconds: 300));

    // Show image source dialog
    final source = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ImageSourceSheet(),
    );

    if (source != null) {
      // Simulate image selection
      setState(() {
        _driverLicensePath = 'assets/images/license_placeholder.jpg';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Driver\'s license uploaded successfully'),
            backgroundColor: kPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickVehicleDoc() async {
    // TODO: Implement actual image picker
    await Future.delayed(const Duration(milliseconds: 300));

    final source = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ImageSourceSheet(),
    );

    if (source != null) {
      setState(() {
        _vehicleDocPath = 'assets/images/vehicle_placeholder.jpg';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Vehicle document uploaded successfully'),
            backgroundColor: kPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _onSave() async {
    if (!_isFormValid) return;

    setState(() => _isLoading = true);

    // Simulate API call to save driver details
    await Future.delayed(const Duration(milliseconds: 1000));

    // TODO: Replace with actual API call to save driver details

    setState(() => _isLoading = false);
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Simple back button with step indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 18, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed:
                        widget.onBack ?? () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                  const Spacer(),
                  const Text(
                    'Step 2 of 3',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: kMuted,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Car icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.directions_car,
                          color: kPrimary,
                          size: 36,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Center(
                      child: Text(
                        'Become a Driver',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Center(
                      child: Text(
                        'Fill in your vehicle details to start offering rides. You can always do this later in your profile.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: kMuted,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Vehicle Make & Model
                    AuthTextField(
                      controller: _vehicleModelCtrl,
                      label: 'Vehicle Make & Model',
                      hint: 'e.g. Toyota Corolla',
                      prefixIcon: Icons.directions_car_outlined,
                      suffix: Icon(
                        Icons.local_shipping_outlined,
                        color: kMuted,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // License Plate Number
                    AuthTextField(
                      controller: _licensePlateCtrl,
                      label: 'License Plate Number',
                      hint: 'E.G. ABC 1234',
                      prefixIcon: Icons.credit_card_outlined,
                      suffix: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.qr_code_scanner,
                          color: kPrimary,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Driver's License Upload
                    DocumentUploadCard(
                      title: "Driver's License Verification",
                      subtitle: 'Supports JPG, PNG (Max 5MB)',
                      isRequired: true,
                      imagePath: _driverLicensePath,
                      onTap: _pickDriverLicense,
                      onRemove: _driverLicensePath != null
                          ? () => setState(() => _driverLicensePath = null)
                          : null,
                    ),

                    const SizedBox(height: 20),

                    // Vehicle Document Upload (Optional)
                    DocumentUploadCard(
                      title: "Vehicle Registration (Optional)",
                      subtitle: 'Supports JPG, PNG (Max 5MB)',
                      isRequired: false,
                      imagePath: _vehicleDocPath,
                      onTap: _pickVehicleDoc,
                      onRemove: _vehicleDocPath != null
                          ? () => setState(() => _vehicleDocPath = null)
                          : null,
                    ),

                    const SizedBox(height: 32),

                    // Save Button
                    AuthButton(
                      label: 'Save Vehicle & Continue',
                      icon: Icons.check,
                      isLoading: _isLoading,
                      onPressed: _isFormValid ? _onSave : null,
                    ),

                    const SizedBox(height: 16),

                    // Skip option
                    Center(
                      child: TextButton(
                        onPressed: widget.onSkip,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Skip for now',
                              style: TextStyle(
                                color: kMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.arrow_forward, color: kMuted, size: 18),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
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

// ============================================================================
// Image Source Selection Bottom Sheet
// ============================================================================

class _ImageSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: kCardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Upload Document',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how you want to upload your document',
            style: TextStyle(color: kMuted),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _SourceOption(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SourceOption(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: kMuted, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          border: Border.all(color: kCardBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: kPrimary, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
