import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
// Removed custom neon app bar to use theme-driven AppBar
import 'home_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String phoneNumber;
  final bool isEditing;
  
  const ProfileSetupScreen({
    super.key,
    required this.phoneNumber,
    this.isEditing = false,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  
  String _selectedRole = 'Student';
  DateTime? _selectedDate;
  File? _profileImage;
  bool _isLoading = false;
  String? _errorMessage;

  // Theme colors
  static const Color primaryRed = Color(0xFFDC2626);
  static const Color charcoal = Color(0xFF1F2937);
  static const Color lightGray = Color(0xFFF9FAFB);

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadUserData();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    int attempt = 0;
    while (attempt < 3) {
      try {
        final user = _auth.currentUser;
        if (user == null) return;

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          if (!mounted) return;
          setState(() {
            _nameController.text = data['name'] ?? '';
            _emailController.text = data['email'] ?? '';
            _addressController.text = data['address'] ?? '';
            _bioController.text = data['bio'] ?? '';
            // Use role from Firestore (set by setUserRole function) - don't default to Student
            _selectedRole = data['role'] ?? 'Student';
            if (data['dob'] != null) {
              _selectedDate = DateTime.parse(data['dob']);
            }
          });
        }
        return; // success
      } catch (e) {
        attempt += 1;
        await Future.delayed(Duration(milliseconds: 300 * attempt));
        if (attempt >= 3) {
          return;
        }
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: $e';
      });
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null) return null;
    int attempt = 0;
    while (attempt < 3) {
      try {
        final user = _auth.currentUser;
        if (user == null) {
          setState(() {
            _errorMessage = 'User not authenticated. Please login again.';
          });
          return null;
        }

        final ref = _storage.ref().child('profile_pictures/${user.uid}');
        await ref.putFile(_profileImage!);
        final downloadUrl = await ref.getDownloadURL();
        return downloadUrl;
      } catch (e) {
        attempt += 1;
        
        if (e.toString().contains('unauthorized')) {
          setState(() {
            _errorMessage = 'Storage permission denied. Please check your account settings.';
          });
          return null;
        }
        
        if (e.toString().contains('unavailable')) {
          setState(() {
            _errorMessage = 'Storage service temporarily unavailable. Please try again later.';
          });
          return null;
        }
        
        await Future.delayed(Duration(milliseconds: 400 * attempt));
        if (attempt >= 3) {
          setState(() {
            _errorMessage = 'Failed to upload image after 3 attempts. Please try again.';
          });
          return null;
        }
      }
    }
    return null;
  }

  Future<void> _completeRegistration() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your name';
      });
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address';
      });
      return;
    }

    if (_addressController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not authenticated';
        });
        return;
      }

      // Upload profile image
      final String? profileImageUrl = await _uploadProfileImage();
      
      if (profileImageUrl != null) {
      } else {
      }

      // Get role from Firestore (set by setUserRole function during OTP verification)
      // This ensures the role matches what was set during login
      final userDocSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      String role = userDocSnapshot.data()?['role'] ?? _selectedRole;

      // Build user doc
      final Map<String, dynamic> userDoc = {
        'uid': user.uid,
        'phone': user.phoneNumber ?? widget.phoneNumber,
        'email': _emailController.text.trim(),
        'name': _nameController.text.trim(),
        'role': role,
        'address': _addressController.text.trim(),
        'dob': _selectedDate?.toIso8601String(),
        'bio': _bioController.text.trim(),
        'photoUrl': profileImageUrl,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final isNewUser = !(await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get())
          .exists;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userDoc, SetOptions(merge: true));

      // Notification sending disabled

      if (!mounted) return;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
      if (widget.isEditing) {
        // If editing, go back to previous screen (Profile tab)
        Navigator.pop(context);
      } else {
        // If first time registration, go to home screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Registration failed: $e';
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: primaryRed,
              onPrimary: Colors.white,
              surface: charcoal,
              onSurface: lightGray,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Profile' : 'Complete Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                widget.isEditing ? 'Update Your Profile' : 'Welcome to DanceRang!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.isEditing ? 'Make changes to your information' : 'Let\'s set up your profile',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Profile Picture
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: charcoal,
                      borderRadius: BorderRadius.circular(60),
                      border: Border.all(
                        color: primaryRed,
                        width: 3,
                      ),
                    ),
                    child: _profileImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(57),
                            child: Image.file(
                              _profileImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt,
                                color: primaryRed,
                                size: 40,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Add Photo',
                                style: TextStyle(
                                  color: lightGray,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Form Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name Field
                    Text(
                      'Full Name *',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Enter your full name',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).dividerTheme.color ?? const Color(0xFF23262E)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryRed),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Email Field
                    Text(
                      'Email Address *',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Enter your email address',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).dividerTheme.color ?? const Color(0xFF23262E)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryRed),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Address Field
                    Text(
                      'Address *',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addressController,
                      maxLines: 3,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Enter your complete address',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).dividerTheme.color ?? const Color(0xFF23262E)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryRed),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Date of Birth Field
                    Text(
                      'Date of Birth (Optional)',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerTheme.color ?? const Color(0xFF23262E)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.grey),
                            const SizedBox(width: 12),
                            Text(
                              _selectedDate != null
                                  ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                  : 'Select your date of birth',
                              style: TextStyle(
                                color: _selectedDate != null ? Theme.of(context).colorScheme.onSurface : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Bio Field
                    Text(
                      'Bio (Optional)',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _bioController,
                      maxLines: 3,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Tell us about yourself...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).dividerTheme.color ?? const Color(0xFF23262E)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryRed),
                        ),
                      ),
                    ),
                    
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: primaryRed),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: primaryRed,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Theme Toggle (only show if editing)
                    if (widget.isEditing) ...[
                      const SizedBox(height: 16),
                    ],
                    
                    // Complete Registration Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _completeRegistration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.isEditing ? 'Update Profile' : 'Complete Registration',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Skip Button
                    Center(
                      child: TextButton(
                        onPressed: _isLoading ? null : () {
                          // Skip profile setup and go to dashboard
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const HomeScreen()),
                            (route) => false,
                          );
                        },
                        child: const Text(
                          'Skip for now',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
