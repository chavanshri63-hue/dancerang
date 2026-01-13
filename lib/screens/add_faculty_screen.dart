import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddFacultyScreen extends StatefulWidget {
  const AddFacultyScreen({super.key});

  @override
  State<AddFacultyScreen> createState() => _AddFacultyScreenState();
}

class _AddFacultyScreenState extends State<AddFacultyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specializationController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _experienceController = TextEditingController();
  
  String _selectedSpecialization = 'Bollywood';
  bool _isLoading = false;
  DateTime? _joiningDate;

  final List<String> _specializations = [
    'Bollywood',
    'Hip Hop',
    'Contemporary',
    'Bharatanatyam',
    'Kathak',
    'Salsa',
    'Bachata',
    'Jazz',
    'Ballet',
    'Folk Dance',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _specializationController.dispose();
    _qualificationController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _addFaculty() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Admin-driven profile creation without auth password
      final phone = _phoneController.text.trim();
      final phoneDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final docId = phoneDigits.isNotEmpty ? phoneDigits : FirebaseFirestore.instance.collection('users').doc().id;

      // Add faculty data to Firestore
      await FirebaseFirestore.instance.collection('users').doc(docId).set({
        'uid': docId,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': phone,
        'role': 'Faculty',
        'specialization': _selectedSpecialization,
        'qualification': _qualificationController.text.trim(),
        'experience_years': int.tryParse(_experienceController.text.trim()) ?? 0,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'joinDate': _joiningDate != null ? Timestamp.fromDate(_joiningDate!) : FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Faculty ${_nameController.text.trim()} added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear form
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
        _qualificationController.clear();
        _experienceController.clear();
        setState(() {
          _selectedSpecialization = 'Bollywood';
          _joiningDate = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding faculty: ${e.toString()}'),
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
      appBar: AppBar(
        title: const Text('Add Faculty'),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person,
                validator: (value) => value?.isEmpty == true ? 'Please enter name' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value?.isEmpty == true ? 'Please enter email' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty == true ? 'Please enter phone number' : null,
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                label: 'Specialization',
                value: _selectedSpecialization,
                items: _specializations,
                onChanged: (value) => setState(() => _selectedSpecialization = value!),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _qualificationController,
                label: 'Qualification',
                icon: Icons.school,
                validator: (value) => value?.isEmpty == true ? 'Please enter qualification' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _experienceController,
                label: 'Experience (Years)',
                icon: Icons.work,
                keyboardType: TextInputType.number,
                validator: (value) => value?.isEmpty == true ? 'Please enter experience' : null,
              ),
              const SizedBox(height: 16),
              _buildDateField(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addFaculty,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Add Faculty', style: TextStyle(fontSize: 16)),
                ),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF1F2937),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF374151)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF374151)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935)),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF374151)),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            onChanged: onChanged,
            dropdownColor: const Color(0xFF1F2937),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
            ),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Joining Date',
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _joiningDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() {
                _joiningDate = date;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF374151)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.grey),
                const SizedBox(width: 12),
                Text(
                  _joiningDate != null
                      ? '${_joiningDate!.day}/${_joiningDate!.month}/${_joiningDate!.year}'
                      : 'Select joining date',
                  style: TextStyle(
                    color: _joiningDate != null ? Colors.white : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
