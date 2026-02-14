import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pinput/pinput.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../utils/error_handler.dart';
// Use theme-driven AppBar instead of custom neon app bar

class OTPVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final String? selectedRole; // 'Student' | 'Faculty' | 'Admin'
  final String? roleKey;      // key for Faculty/Admin

  const OTPVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.selectedRole,
    this.roleKey,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool _isResendLoading = false;
  int _resendCountdown = 60;
  String? _backgroundImageUrl;

  // Theme colors
  static const Color primaryRed = Color(0xFFE53935);
  // lightGray removed - using theme service colors

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
    _loadBackgroundImage();
    // Set system UI overlay style to match dark theme
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Color(0xFF0A0A0A), // Dark background
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    // Reset system UI overlay style when leaving screen
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
    super.dispose();
  }

  Future<void> _loadBackgroundImage() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('backgroundImages')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _backgroundImageUrl = data['otpScreen'] as String?;
          });
        }
      } else {
        // Set default dance background image
        if (mounted) {
          setState(() {
            _backgroundImageUrl = 'https://images.unsplash.com/photo-1508700929628-666bc8bd84ea?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80';
          });
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'loading background image');
      if (mounted) {
        setState(() {
          _backgroundImageUrl = 'https://images.unsplash.com/photo-1508700929628-666bc8bd84ea?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80';
        });
      }
    }
  }

  void _startResendCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
        _startResendCountdown();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Dark theme background
      extendBody: true, // Extend body behind system navigation bar
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text('Verify OTP'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Full background image covering entire screen
          Positioned.fill(
            child: Container(
              decoration: _backgroundImageUrl != null && _backgroundImageUrl!.isNotEmpty
                  ? BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(_backgroundImageUrl!),
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    )
                  : BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).colorScheme.surface,
                          Theme.of(context).colorScheme.surface.withOpacity(0.8),
                        ],
                      ),
                    ),
            ),
          ),
          // Semi-transparent overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),
          // Content with SafeArea
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Header
                Text(
                  'Enter Verification Code',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit code to ${widget.phoneNumber}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // OTP Input
                Pinput(
                  controller: _otpController,
                  length: 6,
                  defaultPinTheme: PinTheme(
                    width: 56,
                    height: 56,
                    textStyle: TextStyle(
                      fontSize: 20,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(color: Theme.of(context).dividerTheme.color ?? const Color(0xFF23262E)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  focusedPinTheme: PinTheme(
                    width: 56,
                    height: 56,
                    textStyle: TextStyle(
                      fontSize: 20,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(color: primaryRed),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onCompleted: (pin) => _verifyOTP(pin),
                ),
                
                const SizedBox(height: 32),
                
                // Verify Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _verifyOTP(_otpController.text),
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
                            'Verify OTP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Resend Button
                Center(
                  child: _resendCountdown > 0
                      ? Text(
                          'Resend code in ${_resendCountdown}s',
                          style: const TextStyle(color: Colors.grey),
                        )
                      : TextButton(
                          onPressed: _isResendLoading ? null : _resendOTP,
                          child: _isResendLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: primaryRed,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Resend Code',
                                  style: TextStyle(
                                    color: primaryRed,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                ),
                
                const SizedBox(height: 32),
                
                // Help Card
                Card(
                  color: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: primaryRed.withOpacity(0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.help_outline_rounded,
                          color: primaryRed,
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Didn\'t receive the code? Check your SMS or try resending.',
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }

  Future<void> _verifyOTP(String otp) async {
    if (otp.length != 6) {
      _showSnackBar('Please enter a valid 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      

      // Real Firebase verification
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);

      // Ensure fresh auth token before any callable/reads
      await FirebaseAuth.instance.currentUser?.getIdToken(true);

      // After sign-in, always set the role via callable (for Student, Faculty, Admin)
      if (widget.selectedRole != null) {
        try {
          final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
          // For Student role, no key is needed. For Admin/Faculty, key is required.
          await functions.httpsCallable('setUserRole').call({
            'role': widget.selectedRole,
            'key': widget.roleKey?.trim() ?? '', // Empty string for Student
          });
          // Refresh token to pick updated custom claims
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
        } catch (e, stackTrace) {
          ErrorHandler.handleError(e, stackTrace, context: 'setting user role');
        }
      }

      if (!mounted) return;
      _showSnackBar('Phone number verified successfully!', isSuccess: true);
      await Future.delayed(const Duration(milliseconds: 1000));
      
      if (!context.mounted) return;
      
      // Check if user is new (no profile data in Firestore)
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
      
      if (!userDoc.exists || userDoc.data()?['name'] == null) {
        // New user - redirect to profile setup
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => ProfileSetupScreen(
              phoneNumber: widget.phoneNumber,
            ),
          ),
          (route) => false,
        );
      } else {
        // Existing user - go to home screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'verifying OTP');
      setState(() {
        _isLoading = false;
      });
      
      String errorMessage = 'Invalid OTP. Please try again.';
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'invalid-verification-code':
            errorMessage = 'Invalid verification code. Please check and try again.';
            break;
          case 'invalid-verification-id':
            errorMessage = 'Verification session expired. Please request a new OTP.';
            break;
          case 'session-expired':
            errorMessage = 'Verification session expired. Please request a new OTP.';
            break;
          default:
            errorMessage = 'Verification failed: ${e.message}';
        }
      }
      _showSnackBar(errorMessage);
    }
  }

  Future<void> _resendOTP() async {
    setState(() {
      _isResendLoading = true;
      _resendCountdown = 60;
    });

    try {
      // Firebase Phone Auth resend
      // Note: Firebase Phone Auth doesn't support resend directly
      // The user needs to restart the verification process
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _isResendLoading = false;
      });
      _showSnackBar('Please go back and request a new OTP', isSuccess: false);
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'resending OTP');
      setState(() {
        _isResendLoading = false;
      });
      _showSnackBar(ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}