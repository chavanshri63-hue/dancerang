import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import '../widgets/glassmorphism_app_bar.dart';
import '../services/payment_service.dart';

class WorkshopQRDisplayScreen extends StatefulWidget {
  final String workshopId;
  const WorkshopQRDisplayScreen({super.key, required this.workshopId});

  @override
  State<WorkshopQRDisplayScreen> createState() => _WorkshopQRDisplayScreenState();
}

class _WorkshopQRDisplayScreenState extends State<WorkshopQRDisplayScreen> {
  String? _qrData;
  bool _isLoading = true;
  Map<String, dynamic>? _workshopData;
  String? _studentName;
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _loadWorkshopData();
    
    // Listen to payment success events for real-time workshop updates
    _paymentRefreshSubscription = PaymentService.refreshStream.listen((event) {
      if (event['type'] == 'payment_success' && 
          (event['paymentType'] == 'workshop' || event['paymentType'] == 'event_choreography') && mounted) {
        // Refresh workshop data when workshop payment succeeds
        _loadWorkshopData();
      }
    });
  }

  @override
  void dispose() {
    _paymentRefreshSubscription?.cancel();
    super.dispose();
  }

  void _loadWorkshopData() async {
    try {
      // Get workshop data
      final workshopDoc = await FirebaseFirestore.instance
          .collection('workshops')
          .doc(widget.workshopId)
          .get();

      if (workshopDoc.exists) {
        setState(() {
          _workshopData = workshopDoc.data();
        });
      }

      // Get student name
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data();
          setState(() {
            _studentName = userData?['name'] ?? 'Student';
          });
        }
      }

      // Generate QR data
      final userId = user?.uid ?? 'demo_user';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      setState(() {
        _qrData = 'workshop_${widget.workshopId}_$userId\_$timestamp';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'Workshop QR Code',
        onLeadingPressed: () => Navigator.pop(context),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white70,
              ),
            )
          : _workshopData == null
              ? const Center(
                  child: Text(
                    'Workshop not found',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Workshop Details Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF1B1B1B),
                              const Color(0xFF2D2D2D),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.school,
                                    color: Color(0xFFE53935),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _workshopData!['title'] ?? 'Workshop',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Workshop Details
                            _buildDetailRow(
                              Icons.person,
                              'Instructor',
                              _workshopData!['instructor'] ?? 'Unknown',
                            ),
                            const SizedBox(height: 8),
                            
                            _buildDetailRow(
                              Icons.calendar_today,
                              'Date',
                              _formatDate(_workshopData!['date']),
                            ),
                            const SizedBox(height: 8),
                            
                            _buildDetailRow(
                              Icons.access_time,
                              'Time',
                              _workshopData!['time'] ?? 'TBD',
                            ),
                            const SizedBox(height: 8),
                            
                            _buildDetailRow(
                              Icons.location_on,
                              'Location',
                              _workshopData!['location'] ?? 'TBD',
                            ),
                            const SizedBox(height: 8),
                            
                            _buildDetailRow(
                              Icons.timer,
                              'Duration',
                              '${_workshopData!['duration'] ?? 60} minutes',
                            ),
                            const SizedBox(height: 8),
                            
                            _buildDetailRow(
                              Icons.people,
                              'Participants',
                              '${_workshopData!['currentParticipants'] ?? 0}/${_workshopData!['maxParticipants'] ?? 0}',
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Student Name
                      if (_studentName != null) ...[
                        Text(
                          'Student: $_studentName',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      // QR Code
                      if (_qrData != null) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: _qrData!,
                            version: QrVersions.auto,
                            size: 250.0,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Instructions
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1B1B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE53935).withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Color(0xFFE53935),
                                size: 24,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Show this QR code to your instructor',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'They will scan it to mark your attendance',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFFE53935),
          size: 18,
        ),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'TBD';
    if (date is Timestamp) {
      return '${date.toDate().day}/${date.toDate().month}/${date.toDate().year}';
    }
    return date.toString();
  }
}
