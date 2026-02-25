import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity Verification', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Verification Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Verify your status to increase trust and unlock driver features.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            
            // 1. College Verification Tile
            _buildVerificationTile(
              context,
              title: 'College / University Verification',
              subtitle: 'Upload ID card and verify campus email',
              icon: Icons.school_outlined,
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CollegeVerificationScreen()),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 2. Driver's License Tile (Icon fixed to badge_outlined for compatibility)
            _buildVerificationTile(
              context,
              title: 'Verify Driver\'s License',
              subtitle: 'Required to offer rides as a driver',
              icon: Icons.badge_outlined, // Changed from id_card_outlined to fix build error
              color: Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LicenseVerificationScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationTile(BuildContext context, 
      {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ================= COLLEGE VERIFICATION FLOW =================

class CollegeVerificationScreen extends StatefulWidget {
  const CollegeVerificationScreen({super.key});

  @override
  State<CollegeVerificationScreen> createState() => _CollegeVerificationScreenState();
}

class _CollegeVerificationScreenState extends State<CollegeVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  File? _idCardImage;
  final ImagePicker _picker = ImagePicker();
  
  final TextEditingController _collegeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _idCardImage = File(image.path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('College Verification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('College Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildLabel('College / University Name'),
              TextFormField(
                controller: _collegeController,
                decoration: _inputDecoration(Icons.business),
                validator: (val) => val!.isEmpty ? 'Please enter college name' : null,
              ),
              const SizedBox(height: 20),
              _buildLabel('College Email ID'),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(Icons.email_outlined),
                validator: (val) => !val!.contains('@') ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 30),
              _buildLabel('College ID Card Picture'),
              const SizedBox(height: 8),
              _buildImagePickerBox(_idCardImage, _pickImage, 'Upload ID Front Side'),
              const SizedBox(height: 40),
              _buildSubmitButton('Submit for Verification', () {
                if (_formKey.currentState!.validate() && _idCardImage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification documents submitted!')));
                  Navigator.pop(context);
                } else if (_idCardImage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload ID card picture')));
                }
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= DRIVER LICENSE VERIFICATION FLOW =================

class LicenseVerificationScreen extends StatefulWidget {
  const LicenseVerificationScreen({super.key});

  @override
  State<LicenseVerificationScreen> createState() => _LicenseVerificationScreenState();
}

class _LicenseVerificationScreenState extends State<LicenseVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  File? _licenseImage;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _licenseNoController = TextEditingController();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) setState(() => _licenseImage = File(image.path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('License Verification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Driving License', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildLabel('License Number'),
              TextFormField(
                controller: _licenseNoController,
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDecoration(Icons.credit_card),
                validator: (val) => val!.isEmpty ? 'Please enter license number' : null,
              ),
              const SizedBox(height: 30),
              _buildLabel('Upload License Photo'),
              _buildImagePickerBox(_licenseImage, _pickImage, 'Capture License Photo'),
              const SizedBox(height: 40),
              _buildSubmitButton('Verify License', () {
                if (_formKey.currentState!.validate() && _licenseImage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('License submitted for review!')));
                  Navigator.pop(context);
                } else if (_licenseImage == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please capture license photo')));
                }
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= SHARED WIDGETS =================

Widget _buildLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
);

InputDecoration _inputDecoration(IconData icon) => InputDecoration(
  prefixIcon: Icon(icon, color: Colors.green),
  filled: true,
  fillColor: Colors.grey.shade50,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.green)),
);

Widget _buildImagePickerBox(File? imageFile, VoidCallback onTap, String hint) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: imageFile == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(hint, style: TextStyle(color: Colors.grey.shade600)),
              ],
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(imageFile, fit: BoxFit.cover),
            ),
    ),
  );
}

Widget _buildSubmitButton(String label, VoidCallback onPressed) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
    ),
  );
}