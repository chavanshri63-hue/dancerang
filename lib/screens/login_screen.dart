import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'otp_verification_screen.dart';
import 'home_screen.dart';
import '../config/app_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _specialKeyController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedRole = 'Student';
  final List<String> _roles = ['Student', 'Faculty', 'Admin'];
  String? _adminKey;
  String? _facultyKey;
  bool _keysLoaded = false;
  String _countryCode = '+91';
  final List<String> _countryCodes = [
    '+91', '+1', '+44', '+971', '+61', '+65', '+81', '+49', '+33', '+39'
  ];

  // Theme colors
  static const Color primaryRed = Color(0xFFE53935);
  static const Color lightGray = Color(0xFFF9FAFB);

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Background image
  String? _backgroundImageUrl;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadBackgroundImage();
    _loadRoleKeys();
  }

  Future<void> _loadRoleKeys() async {
    try {
      final doc = await _firestore
          .collection('appSettings')
          .doc('roleKeys')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _adminKey = data['adminKey']?.toString().trim();
            _facultyKey = data['facultyKey']?.toString().trim();
            _keysLoaded = true;
          });
        }
      } else {
        // Fallback to AppConfig defaults if Firestore doesn't have keys
        if (mounted) {
          setState(() {
            _adminKey = AppConfig.adminKey;
            _facultyKey = AppConfig.facultyKey;
            _keysLoaded = true;
          });
        }
      }
    } catch (e) {
      // Fallback to AppConfig defaults on error
      if (mounted) {
        setState(() {
          _adminKey = AppConfig.adminKey;
          _facultyKey = AppConfig.facultyKey;
          _keysLoaded = true;
        });
      }
    }
  }

  Future<void> _loadBackgroundImage() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('backgroundImages')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        if (!mounted) return;
        setState(() {
          _backgroundImageUrl = data['loginScreen'] as String?;
        });
             } else {
               // Set default dance background image
               if (!mounted) return;
               setState(() {
                 _backgroundImageUrl = AppConfig.defaultLoginBackground;
               });
             }
    } catch (e) {
      // Set default dance background image on error
      if (!mounted) return;
      setState(() {
        _backgroundImageUrl = AppConfig.defaultLoginBackground;
      });
    }
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // Start animation
    _fadeController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _specialKeyController.dispose();
    _fadeController.dispose();
    super.dispose();
  }


  Future<void> _sendOTP() async {
    // Wait for keys to load if not loaded yet
    if (!_keysLoaded) {
      await _loadRoleKeys();
    }

    // Role key validation (client-side guard only)
    if (_selectedRole != 'Student') {
      final key = _specialKeyController.text.trim();
      if (key.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter $_selectedRole key';
        });
        return;
      }
      
      // Normalize both keys for comparison (trim and case-sensitive)
      final normalizedInputKey = key.trim();
      final bool valid = (_selectedRole == 'Admin' && _adminKey != null && normalizedInputKey == _adminKey!.trim()) ||
                        (_selectedRole == 'Faculty' && _facultyKey != null && normalizedInputKey == _facultyKey!.trim());
      
      if (!valid) {
        // Fallback: Also check against AppConfig directly if Firestore keys don't match
        final bool fallbackValid = (_selectedRole == 'Admin' && normalizedInputKey == AppConfig.adminKey.trim()) ||
                                   (_selectedRole == 'Faculty' && normalizedInputKey == AppConfig.facultyKey.trim());
        
        if (!fallbackValid) {
          setState(() {
            _errorMessage = 'Invalid $_selectedRole key. Please check and try again.';
          });
          return;
        }
      }
    }
    if (_phoneController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your phone number';
      });
      return;
    }

    final rawInput = _phoneController.text.trim();
    final digitsOnly = rawInput.replaceAll(RegExp(r'\\D'), '');
    if (digitsOnly.length < 6) {
      setState(() {
        _errorMessage = 'Please enter a valid phone number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String phoneNumber = _phoneController.text.trim();
      if (!phoneNumber.startsWith('+')) {
        phoneNumber = '$_countryCode$phoneNumber';
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed
          setState(() {
            _isLoading = false;
          });
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
            _errorMessage = e.message ?? 'Verification failed';
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationScreen(
                verificationId: verificationId,
                phoneNumber: phoneNumber,
                selectedRole: _selectedRole,
                roleKey: _selectedRole == 'Admin' 
                    ? _specialKeyController.text.trim() 
                    : (_selectedRole == 'Faculty' 
                        ? _specialKeyController.text.trim() 
                        : null),
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Auto-retrieval timeout
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside text fields
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        body: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B0C0E),
              Color(0xFF1A1A1A),
              Color(0xFF0B0C0E),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
          image: _backgroundImageUrl != null && _backgroundImageUrl!.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(_backgroundImageUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.7),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Clean Header
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          // Clean Typography
                          Text(
                            'DanceRang',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: lightGray,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Step into Excellence',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: primaryRed.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Join 1000+ Dancers',
                              style: const TextStyle(
                                fontSize: 14,
                                color: primaryRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // Clean Login Card (Rich Obsidian Capsule)
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF262626),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome to DanceRang',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: lightGray,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter your phone number to continue',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Clean Phone Input
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF111827),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _errorMessage != null
                                      ? primaryRed
                                      : (Theme.of(context).dividerTheme.color ?? const Color(0xFF23262E)).withOpacity(0.6),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: const BoxDecoration(
                                      color: primaryRed,
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        bottomLeft: Radius.circular(12),
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _countryCode,
                                        dropdownColor: const Color(0xFF1B1B1B),
                                        iconEnabledColor: Colors.white,
                                        items: _countryCodes
                                            .map((code) => DropdownMenuItem(
                                                  value: code,
                                                  child: Text(
                                                    code,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ))
                                            .toList(),
                                        onChanged: (value) {
                                          if (value == null) return;
                                          setState(() {
                                            _countryCode = value;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                      child: TextField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.phone,
                                        style: const TextStyle(color: lightGray),
                                        decoration: const InputDecoration(
                                          hintText: 'Enter your phone number',
                                          hintStyle: TextStyle(color: Colors.grey),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        ),
                                      onChanged: (value) {
                                        if (_errorMessage != null) {
                                          setState(() {
                                            _errorMessage = null;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Role selection
                            Text(
                              'Login as',
                              style: const TextStyle(
                                fontSize: 14,
                                color: lightGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Theme.of(context).dividerTheme.color ?? const Color(0xFF23262E)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedRole,
                                  isExpanded: true,
                                  dropdownColor: Theme.of(context).colorScheme.surface,
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                  iconEnabledColor: Theme.of(context).colorScheme.onSurface,
                                  items: _roles.map((r) => DropdownMenuItem<String>(
                                    value: r,
                                    child: Text(r),
                                  )).toList(),
                                  onChanged: (val) {
                                    if (val == null) return;
                                    setState(() {
                                      _selectedRole = val;
                                      _errorMessage = null;
                                      if (_selectedRole == 'Student') {
                                        _specialKeyController.clear();
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),

                            // Special key card (for Admin/Faculty)
                            if (_selectedRole != 'Student') ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: primaryRed.withOpacity(0.25)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$_selectedRole Key',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _specialKeyController,
                                      obscureText: true,
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                      decoration: InputDecoration(
                                        hintText: 'Enter special key',
                                        hintStyle: const TextStyle(color: Colors.grey),
                                        filled: true,
                                        fillColor: Theme.of(context).colorScheme.surface,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(color: Theme.of(context).dividerTheme.color ?? const Color(0xFF23262E)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: const BorderSide(color: primaryRed),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 12),
                                      Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          color: primaryRed,
                                          fontSize: 14,
                                        ),
                                      ),
                            ],
                            
                            const SizedBox(height: 24),
                            
                            // Clean Send OTP Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _sendOTP,
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
                                    : const Text(
                                        'Send OTP',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    
                    const SizedBox(height: 24),
                    
                    // Clean Terms of Service
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        'By continuing, you agree to our Terms of Service',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }
}