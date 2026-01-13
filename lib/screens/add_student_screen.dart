import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';

class AddStudentData {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String level;
  final String danceClass;
  final DateTime joiningDate;
  final String status;

  AddStudentData({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.level,
    required this.danceClass,
    required this.joiningDate,
    required this.status,
  });

  factory AddStudentData.fromMap(Map<String, dynamic> data, String id) {
    return AddStudentData(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      level: data['level'] ?? 'Beginner',
      danceClass: data['danceClass'] ?? 'Bollywood Dance',
      joiningDate: (data['joiningDate'] as Timestamp).toDate(),
      status: data['status'] ?? 'active',
    );
  }
}

class AddStudentScreen extends StatefulWidget {
  final AddStudentData? studentData;
  final bool isEditMode;
  
  const AddStudentScreen({
    super.key,
    this.studentData,
    this.isEditMode = false,
  });

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _joiningDate;
  
  String _selectedLevel = 'Beginner';
  String _selectedClass = 'Bollywood Dance';
  bool _isLoading = false;

  final List<String> _levels = ['Beginner', 'Intermediate', 'Advanced'];
  final List<String> _classes = [
    'Bollywood Dance',
    'Hip-Hop',
    'Contemporary',
    'Kathak',
    'Bharatanatyam',
    'Salsa',
    'Bachata',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode && widget.studentData != null) {
      _nameController.text = widget.studentData!.name;
      _emailController.text = widget.studentData!.email;
      _phoneController.text = widget.studentData!.phone;
      _selectedLevel = widget.studentData!.level;
      _selectedClass = widget.studentData!.danceClass;
      _joiningDate = widget.studentData!.joiningDate;
      
      // Ensure selected values are valid
      if (!_levels.contains(_selectedLevel)) {
        _selectedLevel = 'Beginner';
      }
      if (!_classes.contains(_selectedClass)) {
        _selectedClass = 'Bollywood Dance';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _addStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Admin-driven profile creation without auth password
      final phone = _phoneController.text.trim();
      final phoneDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final docId = widget.isEditMode 
          ? widget.studentData!.id 
          : (phoneDigits.isNotEmpty ? phoneDigits : FirebaseFirestore.instance.collection('users').doc().id);

      // Prepare user data
      final userData = {
        'uid': docId,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': phone,
        'role': 'Student',
        'level': _selectedLevel,
        'enrolledClass': _selectedClass,
        'isActive': true,
        'joinDate': _joiningDate != null ? Timestamp.fromDate(_joiningDate!) : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (!widget.isEditMode) 'createdAt': FieldValue.serverTimestamp(),
        if (!widget.isEditMode) 'createdBy': FirebaseAuth.instance.currentUser?.uid,
      };

      if (widget.isEditMode) {
        // Update existing student
        await FirebaseFirestore.instance.collection('users').doc(docId).update(userData);
      } else {
        // Add new student
        await FirebaseFirestore.instance.collection('users').doc(docId).set(userData);
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Student ${_nameController.text.trim()} ${widget.isEditMode ? 'updated' : 'added'} successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        if (!widget.isEditMode) {
          // Clear form only for new students
          _nameController.clear();
          _emailController.clear();
          _phoneController.clear();
          setState(() {
            _selectedLevel = 'Beginner';
            _selectedClass = 'Bollywood Dance';
            _joiningDate = null;
          });
        } else {
          // Navigate back for edit mode
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${widget.isEditMode ? 'updating' : 'adding'} student: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: widget.isEditMode ? 'Edit Student' : 'Add New Student',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Icon
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFE53935).withValues(alpha: 0.3),
                        const Color(0xFFE53935).withValues(alpha: 0.1),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFFE53935).withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.person_add,
                    size: 50,
                    color: Color(0xFFE53935),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Name Field
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter student name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email Field
              _buildTextField(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter email address';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone Field
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter phone number';
                  }
                  if (value.length < 10) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password removed per requirement
              const SizedBox(height: 24),

              // Joining Date Picker
              GestureDetector(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _joiningDate ?? now,
                    firstDate: DateTime(now.year - 3),
                    lastDate: DateTime(now.year + 3),
                    helpText: 'Select Joining Date',
                  );
                  if (picked != null) {
                    setState(() {
                      _joiningDate = DateTime(picked.year, picked.month, picked.day);
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B1B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event, color: Color(0xFFE53935)),
                      const SizedBox(width: 12),
                      Text(
                        _joiningDate == null
                            ? 'Joining Date'
                            : '${_joiningDate!.day}/${_joiningDate!.month}/${_joiningDate!.year}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFFE53935)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Level Selection
              _buildDropdown(
                label: 'Dance Level',
                value: _selectedLevel,
                items: _levels,
                onChanged: (value) {
                  setState(() {
                    _selectedLevel = value!;
                  });
                },
                icon: Icons.trending_up,
              ),
              const SizedBox(height: 16),

              // Class Selection
              _buildDropdown(
                label: 'Enrolled Class',
                value: _selectedClass,
                items: _classes,
                onChanged: (value) {
                  setState(() {
                    _selectedClass = value!;
                  });
                },
                icon: Icons.school,
              ),
              const SizedBox(height: 32),

              // Add Student Button
              ElevatedButton(
                onPressed: _isLoading ? null : _addStudent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Add Student',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              const SizedBox(height: 16),

              // Helper note
              const Text(
                'Note: Phone number should be the student\'s device number so QR attendance links correctly.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFFE53935)),
        filled: true,
        fillColor: const Color(0xFF1B1B1B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFE53935),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    // Debug: Print dropdown values
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          dropdownColor: const Color(0xFF1B1B1B),
          style: const TextStyle(color: Colors.white),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFE53935)),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFFE53935), size: 20),
                  const SizedBox(width: 12),
                  Text(item),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
