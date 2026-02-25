import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend_flutter/screens/profile/verification_screen.dart';
import 'package:frontend_flutter/screens/auth/login.dart';
import 'package:frontend_flutter/main.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  // Data State - defaults shown when data not available
  String name = 'User';
  List<Map<String, String>> vehicles = [];

  String contactNumber = 'Not available';
  String orgEmail = 'Not available';
  String personalEmail = 'Not available';

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await AuthService.getUserProfile();
    setState(() {
      name = profile['name'] ?? 'User';
      contactNumber = profile['phone'] ?? 'Not available';
      orgEmail = profile['email'] ?? 'Not available';
      // personalEmail stays as fallback since we don't collect it in signup
      _isLoading = false;
    });
  }

  // ================= LOGIC =================

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (picked != null) setState(() => _profileImage = File(picked.path));
  }

  Future<void> _openVehicleForm({
    Map<String, String>? existingVehicle,
    int? index,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddVehicleScreen(initialData: existingVehicle),
      ),
    );

    if (result != null) {
      setState(() {
        if (index != null) {
          vehicles[index] = Map<String, String>.from(result);
        } else {
          vehicles.add(Map<String, String>.from(result));
        }
      });
    }
  }

  void _deleteVehicle(int index) {
    _showWarningDialog(
      title: 'Delete Vehicle',
      content:
          'Are you sure you want to remove this vehicle from your profile?',
      confirmText: 'Delete',
      confirmColor: Colors.red,
      onConfirm: () {
        setState(() => vehicles.removeAt(index));
        Navigator.pop(context);
      },
    );
  }

  // ================= ACTION DIALOGS =================

  void _showWarningDialog({
    required String title,
    required String content,
    required String confirmText,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: TextStyle(color: confirmColor, fontWeight: FontWeight.bold),
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              confirmText,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ================= UI BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'User Profile',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 16),
            _buildStatsRow(),
            const SizedBox(height: 16),
            _buildVerificationButton(),
            const SizedBox(height: 20),
            _buildVehicleSection(),
            const SizedBox(height: 20),
            _buildMyAccountSection(),
            const SizedBox(height: 20),
            _buildDangerZone(), // Logout, Suspend, Delete
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          GestureDetector(
            onTap: _showImageSource,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : null,
                  child: _profileImage == null
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('4.9', 'Rating', Icons.star, Colors.green),
        _buildStatCard(
          vehicles.length.toString(),
          'Rides',
          Icons.directions_car,
          Colors.blue,
        ),
        _buildStatCard('2y', 'Member', Icons.access_time, Colors.orange),
      ],
    );
  }

  Widget _buildVerificationButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const VerificationScreen()),
          );
        },
        icon: const Icon(Icons.verified_user_outlined, color: Colors.white),
        label: const Text(
          'Get Verified Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            Icons.directions_car,
            'My Vehicles',
            vehicles.isNotEmpty ? 'Add New' : '',
            () => _openVehicleForm(),
          ),
          const SizedBox(height: 16),
          if (vehicles.isEmpty)
            Center(
              child: Column(
                children: [
                  Text(
                    'No vehicle added yet',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  TextButton(
                    onPressed: () => _openVehicleForm(),
                    child: const Text(
                      '+ Add Vehicle',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vehicles.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final v = vehicles[index];
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${v['makeModel']} (${v['type']})",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            v['regNumber'] ?? '',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: Colors.green),
                      onPressed: () =>
                          _openVehicleForm(existingVehicle: v, index: index),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _deleteVehicle(index),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMyAccountSection() {
    return Container(
      decoration: _cardDecoration(),
      child: ExpansionTile(
        leading: const Icon(Icons.account_circle, color: Colors.green),
        title: const Text(
          'My Account',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Manage your personal info'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoTile('Contact Number', contactNumber),
                const SizedBox(height: 12),
                _infoTile('Organization Email', orgEmail),
                const SizedBox(height: 12),
                _infoTile('Personal Email', personalEmail),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(
                            initialData: {
                              'name': name,
                              'contact': contactNumber,
                              'orgEmail': orgEmail,
                              'personalEmail': personalEmail,
                            },
                          ),
                        ),
                      );
                      if (result != null) {
                        setState(() {
                          name = result['name'];
                          contactNumber = result['contact'];
                          orgEmail = result['orgEmail'];
                          personalEmail = result['personalEmail'];
                        });
                      }
                    },
                    child: const Text('Edit Account Details'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _actionTile(Icons.logout, 'Logout', Colors.orange, () {
            _showWarningDialog(
              title: 'Logout',
              content: 'Are you sure you want to sign out?',
              confirmText: 'Logout',
              confirmColor: Colors.orange,
              onConfirm: () async {
                await AuthService.logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                    (route) => false,
                  );
                }
              },
            );
          }),
          const Divider(height: 1),
          _actionTile(
            Icons.pause_circle_outline,
            'Suspend Account',
            Colors.redAccent,
            () {
              _showWarningDialog(
                title: 'Suspend Account',
                content:
                    'This will hide your profile from others until you log back in. Continue?',
                confirmText: 'Suspend',
                confirmColor: Colors.redAccent,
                onConfirm: () => Navigator.pop(context),
              );
            },
          ),
          const Divider(height: 1),
          _actionTile(Icons.delete_forever, 'Delete Account', Colors.red, () {
            _showWarningDialog(
              title: 'Delete Permanently',
              content:
                  'This action cannot be undone. All your data will be deleted forever.',
              confirmText: 'Delete Forever',
              confirmColor: Colors.red,
              onConfirm: () => Navigator.pop(context),
            );
          }),
        ],
      ),
    );
  }

  // ================= HELPERS =================
  Widget _actionTile(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: _cardDecoration(),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(
    IconData icon,
    String title,
    String action,
    VoidCallback onAction,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.green),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        if (action.isNotEmpty)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  void _showImageSource() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
          ),
        ],
      ),
    );
  }
}

// ================= EDIT PROFILE SCREEN =================

class EditProfileScreen extends StatefulWidget {
  final Map<String, String> initialData;
  const EditProfileScreen({super.key, required this.initialData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _contactController;
  late TextEditingController _orgEmailController;
  late TextEditingController _personalEmailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData['name']);
    _contactController = TextEditingController(
      text: widget.initialData['contact'],
    );
    _orgEmailController = TextEditingController(
      text: widget.initialData['orgEmail'],
    );
    _personalEmailController = TextEditingController(
      text: widget.initialData['personalEmail'],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _orgEmailController.dispose();
    _personalEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Personal Details',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildEditField('Full Name', Icons.person, _nameController),
            const SizedBox(height: 16),
            _buildEditField('Contact Number', Icons.phone, _contactController),
            const SizedBox(height: 16),
            _buildEditField(
              'Organization Email',
              Icons.school,
              _orgEmailController,
            ),
            const SizedBox(height: 16),
            _buildEditField(
              'Personal Email',
              Icons.email,
              _personalEmailController,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context, {
                  'name': _nameController.text,
                  'contact': _contactController.text,
                  'orgEmail': _orgEmailController.text,
                  'personalEmail': _personalEmailController.text,
                }),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(
    String label,
    IconData icon,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.green),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.green),
            ),
          ),
        ),
      ],
    );
  }
}

// ================= ADD VEHICLE SCREEN =================

class AddVehicleScreen extends StatefulWidget {
  final Map<String, String>? initialData;
  const AddVehicleScreen({super.key, this.initialData});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  String? selectedType;
  final List<String> vehicleTypes = ['Hatch Back', 'Sedan', 'SUV', 'Premium'];

  late TextEditingController _regController;
  late TextEditingController _seatsController;
  late TextEditingController _modelController;
  late TextEditingController _featuresController;
  late TextEditingController _rcController; // Controller for RC Field

  final RegExp indianPlateRegExp = RegExp(
    r'^[A-Z]{2}[ -]?[0-9]{1,2}(?:[ -]?[A-Z]{1,2})?[ -]?[0-9]{4}$',
  );
  File? _rcImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _regController = TextEditingController(
      text: widget.initialData?['regNumber'],
    );
    _seatsController = TextEditingController(
      text: widget.initialData?['seats'],
    );
    _modelController = TextEditingController(
      text: widget.initialData?['makeModel'],
    );
    _featuresController = TextEditingController(
      text: widget.initialData?['features'],
    );
    _rcController = TextEditingController(
      text: widget.initialData?['rcNumber'],
    );
    if (widget.initialData != null) {
      selectedType = widget.initialData!['type'];
    }
  }

  @override
  void dispose() {
    _regController.dispose();
    _seatsController.dispose();
    _modelController.dispose();
    _featuresController.dispose();
    _rcController.dispose();
    super.dispose();
  }

  Future<void> _pickRCImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _rcImage = File(image.path));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RC Document Uploaded Successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialData == null ? 'Add Vehicle' : 'Edit Vehicle',
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vehicle Type',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: _inputDecoration(Icons.category),
                items: vehicleTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => selectedType = val),
                validator: (val) => val == null ? 'Please select a type' : null,
              ),
              const SizedBox(height: 16),
              _buildLabel('Registration Number (Plate No.)'),
              TextFormField(
                controller: _regController,
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDecoration(Icons.pin),
                validator: (val) =>
                    (val == null ||
                        !indianPlateRegExp.hasMatch(val.toUpperCase()))
                    ? 'Enter valid plate number'
                    : null,
              ),
              const SizedBox(height: 16),

              // --- NEW RC VERIFICATION SECTION ---
              _buildLabel('Vehicle Registration Certificate (RC)'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rcController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _inputDecoration(
                        Icons.description,
                      ).copyWith(hintText: 'Enter RC Number'),
                      validator: (val) => (val == null || val.isEmpty)
                          ? 'RC Number required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 58, // Matching TextField height
                    child: ElevatedButton(
                      onPressed: _pickRCImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _rcImage != null
                            ? Colors.blue
                            : Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _rcImage != null ? 'Uploaded' : 'Verify',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_rcImage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '✅ Document: ${_rcImage!.path.split('/').last}',
                    style: const TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),

              // -----------------------------------
              _buildLabel('Seats Offering'),
              TextFormField(
                controller: _seatsController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(Icons.chair),
                validator: (val) =>
                    (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _buildLabel('Make and Model'),
              TextFormField(
                controller: _modelController,
                decoration: _inputDecoration(Icons.directions_car),
                maxLines: 2,
                validator: (val) =>
                    (val == null || val.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _buildLabel('Features'),
              TextFormField(
                controller: _featuresController,
                decoration: _inputDecoration(Icons.featured_play_list),
                maxLines: 2,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      if (_rcImage == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please upload RC document to verify',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(context, {
                        'type': selectedType,
                        'regNumber': _regController.text.toUpperCase(),
                        'rcNumber': _rcController.text.toUpperCase(),
                        'seats': _seatsController.text,
                        'makeModel': _modelController.text,
                        'features': _featuresController.text,
                      });
                    }
                  },
                  child: Text(
                    widget.initialData == null ? 'Save' : 'Update',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
  );

  InputDecoration _inputDecoration(IconData icon) => InputDecoration(
    prefixIcon: Icon(icon, color: Colors.green),
    filled: true,
    fillColor: Colors.grey.shade50,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.green),
    ),
  );
}
