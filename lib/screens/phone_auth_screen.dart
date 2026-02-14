import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'otp_verification_screen.dart';
import '../utils/error_handler.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String _verificationId = '';

  // Theme colors
  static const Color primaryRed = Color(0xFFE53935);
  static const Color charcoal = Color(0xFF1B1D22);
  static const Color darkGray = Color(0xFF000000);
  static const Color lightGray = Color(0xFFF9FAFB);
  static const Color brightRed = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside text fields
        FocusScope.of(context).unfocus();
      },
      child: Theme(
        data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: darkGray,
          primaryColor: primaryRed,
          colorScheme: const ColorScheme.dark(
            primary: primaryRed,
            surface: charcoal,
            onSurface: lightGray,
            error: brightRed,
          ),
        ),
        child: Scaffold(
        backgroundColor: darkGray,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                
                // Header
                const Text(
                  'Welcome to DanceRang!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF9FAFB), // Light gray
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your phone number to get started',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Phone Input Card
                Card(
                  color: charcoal,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: primaryRed.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Phone Number',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF9FAFB), // Light gray
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Phone Input Field
                        Container(
                          decoration: BoxDecoration(
                            color: darkGray,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                decoration: const BoxDecoration(
                                  color: primaryRed,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  '+91',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(color: Color(0xFFF9FAFB)), // Light gray
                                  decoration: const InputDecoration(
                                    hintText: 'Enter your phone number',
                                    hintStyle: TextStyle(color: Colors.grey),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Send OTP Button
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
                
                // Info Card
                Card(
                  color: charcoal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: primaryRed.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: primaryRed,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          fit: FlexFit.loose,
                          child: Text(
                            'We\'ll send you a verification code via SMS',
                            style: TextStyle(color: lightGray),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Alternative Login Button
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/simple-auth');
                    },
                    child: const Text(
                      'Use Demo Login Instead',
                      style: TextStyle(
                        color: primaryRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

  Future<void> _sendOTP() async {
    if (_phoneController.text.trim().isEmpty) {
      _showSnackBar('Please enter your phone number');
      return;
    }

    // Validate phone number format
    String phoneNumber = _phoneController.text.trim();
    if (!phoneNumber.startsWith('+')) {
      phoneNumber = '+91$phoneNumber';
    }

    setState(() {
      _isLoading = true;
    });

    try {
      
      // Check APNs token availability before proceeding
      try {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          await Future.delayed(const Duration(seconds: 3));
          final retryToken = await FirebaseMessaging.instance.getAPNSToken();
          if (retryToken == null) {
            throw Exception('APNs token not available. Please ensure push notifications are properly configured.');
          }
        }
      } catch (e, stackTrace) {
        ErrorHandler.handleError(e, stackTrace, context: 'checking APNs token');
        setState(() {
          _isLoading = false;
        });
        _showSnackBar(ErrorHandler.getUserFriendlyMessage(e));
        return;
      }
      
      // Add a small delay to ensure APNs is fully ready
      await Future.delayed(const Duration(seconds: 2));
      
      // Use Firebase Phone Auth only
      await _sendOTPViaFirebase(phoneNumber);
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'sending OTP');
      setState(() {
        _isLoading = false;
      });
      
      if (e.toString().contains('APNS') || e.toString().contains('APNs')) {
        _showSnackBar('Phone verification temporarily unavailable. Please try again later.');
        _showFallbackOption();
      } else {
        _showSnackBar(ErrorHandler.getUserFriendlyMessage(e));
      }
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      await _auth.signInWithCredential(credential);
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'signing in with credential');
      _showSnackBar(ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  void _navigateToOTPVerification() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OTPVerificationScreen(
          verificationId: _verificationId,
          phoneNumber: _phoneController.text.trim(),
        ),
      ),
    );
  }

  void _showFallbackOption() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: charcoal,
          title: const Text(
            'Phone Verification Unavailable',
            style: TextStyle(color: Color(0xFFF9FAFB)),
          ),
          content: const Text(
            'Phone verification is temporarily unavailable. Would you like to use demo login instead?',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/simple-auth');
              },
              child: const Text('Use Demo Login'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendOTPViaFirebase(String phoneNumber) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          setState(() {
            _isLoading = false;
          });
          _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
          });
          
          // Show user-friendly error messages
          String errorMessage = 'Verification failed. ';
          switch (e.code) {
            case 'invalid-phone-number':
              errorMessage += 'Invalid phone number format.';
              break;
            case 'too-many-requests':
              errorMessage += 'Too many requests. Please try again later.';
              break;
            case 'quota-exceeded':
              errorMessage += 'SMS quota exceeded. Please try again later.';
              break;
            case 'app-not-authorized':
              errorMessage += 'App not authorized for phone verification.';
              break;
            case 'missing-phone-number':
              errorMessage += 'Phone number is required.';
              break;
            default:
              errorMessage += 'Please check your internet connection and try again.';
          }
          _showSnackBar(errorMessage);
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
          });
          _showSnackBar('OTP sent! Check your phone for SMS.');
          _navigateToOTPVerification();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'sending OTP via Firebase');
      setState(() {
        _isLoading = false;
      });
      _showSnackBar(ErrorHandler.getUserFriendlyMessage(e));
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: brightRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}