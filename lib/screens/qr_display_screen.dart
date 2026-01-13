import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../widgets/glassmorphism_app_bar.dart';

class QRDisplayScreen extends StatefulWidget {
  final String role;
  const QRDisplayScreen({super.key, required this.role});

  @override
  State<QRDisplayScreen> createState() => _QRDisplayScreenState();
}

class _QRDisplayScreenState extends State<QRDisplayScreen> {
  String? _qrData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateQRData();
  }

  void _generateQRData() {
    // Generate QR data for student
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'demo_user';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    setState(() {
      // Student QR format: student_userId_timestamp
      _qrData = 'student_$userId\_$timestamp';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'My QR Code',
        onLeadingPressed: () => Navigator.pop(context),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE53935),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // Role-based header
                  Card(
                    elevation: 8,
                    shadowColor: Colors.black.withValues(alpha: 0.1),
                    color: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).cardColor,
                            Theme.of(context).cardColor.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE53935).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFE53935).withValues(alpha: 0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.qr_code,
                                  size: 24,
                                  color: Color(0xFFE53935),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Your QR Code',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Show this QR code to mark attendance',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // QR Code Container
                  Card(
                    elevation: 8,
                    shadowColor: Colors.black.withValues(alpha: 0.1),
                    color: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).cardColor,
                            Theme.of(context).cardColor.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _qrData != null
                                  ? QrImageView(
                                      data: _qrData!,
                                      version: QrVersions.auto,
                                      size: 200.0,
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                    )
                                  : Icon(
                                      Icons.qr_code,
                                      size: 80,
                                      color: Colors.grey.shade600,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.person_outline,
                                  color: Color(0xFF4F46E5),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Role: ${widget.role.toUpperCase()}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF9FAFB),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.access_time,
                                  color: Color(0xFFFF9800),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Generated: ${DateTime.now().toString().split('.')[0]}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE53935).withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE53935).withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _generateQRData,
                            icon: const Icon(Icons.refresh, size: 20),
                            label: const Text('Refresh QR'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: const Color(0xFFE53935),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Instructions
                  Card(
                    elevation: 6,
                    shadowColor: const Color(0xFFE53935).withValues(alpha: 0.2),
                    color: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: const Color(0xFFE53935).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).cardColor,
                            Theme.of(context).cardColor.withValues(alpha: 0.9),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE53935).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFE53935).withValues(alpha: 0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.info_outline,
                                  color: Color(0xFFE53935),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Instructions',
                                style: TextStyle(
                                  color: Color(0xFFE53935),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935).withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE53935).withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              widget.role.toLowerCase() == 'student'
                                  ? '• Show this QR code to your instructor\n• QR code refreshes every time you open this screen\n• Keep your phone charged during classes'
                                  : widget.role.toLowerCase() == 'faculty'
                                      ? '• Use the camera to scan student QR codes\n• QR codes are valid for attendance marking\n• Ensure good lighting when scanning'
                                      : '• This QR code provides admin access\n• Use it for administrative functions\n• Keep it secure and confidential',
                              style: const TextStyle(
                                color: Color(0xFFF9FAFB),
                                fontSize: 14,
                                height: 1.6,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
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
