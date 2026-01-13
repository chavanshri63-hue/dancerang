import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';
import '../services/payment_service.dart';
import 'event_choreography_chat_screen.dart';

class EventChoreographyScreen extends StatefulWidget {
  final String role;

  const EventChoreographyScreen({
    super.key,
    required this.role,
  });

  @override
  State<EventChoreographyScreen> createState() => _EventChoreographyScreenState();
}

class _EventChoreographyScreenState extends State<EventChoreographyScreen> {
  bool _isLoading = false;
  bool _isBooking = false;
  bool _isSavingRates = false;
  String _selectedPackage = 'school';
  DateTime? _selectedDate;
  String _selectedDateText = 'Select event date';
  StreamSubscription<Map<String, dynamic>>? _refreshSub;
  // Live form state
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _numDancesController = TextEditingController(text: '1');
  int _numDances = 1;
  
  // Rates from Firestore
  Map<String, dynamic> _rates = {
    'school_1_5': 5500,
    'school_6_plus': 4500,
    'sangeet_1_5': 8500,
    'sangeet_6_plus': 7500,
    'corporate_1_5': 8500,
    'corporate_6_plus': 7500,
    'extra_person': 1000,
  };
  
  // Rules from Firestore
  Map<String, dynamic> _rules = {
    'advance_percentage': 50,
    'cancellation_days': 7,
    'rescheduling_hours': 48,
  };
  
  // Controllers for edit form
  final Map<String, TextEditingController> _rateControllers = {};
  final Map<String, TextEditingController> _ruleControllers = {};

  Stream<QuerySnapshot<Map<String, dynamic>>> _userBookingsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('eventChoreoBookings')
        .where('userId', isEqualTo: user.uid)
        .snapshots();
  }


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside text fields
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: GlassmorphismAppBar(
        title: 'Event Choreography',
        actions: [
          if (widget.role.toLowerCase() == 'admin')
            IconButton(
              onPressed: _editRates,
              icon: const Icon(Icons.edit, color: Colors.white70),
            ),
          if (widget.role.toLowerCase() == 'admin')
          IconButton(
              tooltip: 'Edit WhatsApp Number',
              onPressed: _editWaNumber,
              icon: const Icon(Icons.chat, color: Colors.greenAccent),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            )
          : RefreshIndicator(
              onRefresh: _refreshEvents,
              color: Colors.white70,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _PackageSelector(
                    selectedPackage: _selectedPackage,
                    onSelect: (value) {
                      setState(() {
                        _selectedPackage = value;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  _PricingCard(selectedPackage: _selectedPackage, rates: _rates),
                  const SizedBox(height: 20),
                  const _RulesCard(),
                  const SizedBox(height: 20),
                  const _FeaturesCard(),
                  const SizedBox(height: 20),
                  // Testimonials removed as requested
                  _MyBookingsCard(
                    stream: _userBookingsStream(),
                    isAdmin: widget.role.toLowerCase() == 'admin',
                    onChatWhatsApp: _openWhatsAppForBooking,
                  ),
                  const SizedBox(height: 100), // Space for floating button
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openBookingForm,
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.event_available),
        label: const Text('Book Now'),
      ),
    ),
    );
  }

  void _editWaNumber() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B1B1B),
          title: const Text('Set WhatsApp Number', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter phone in international format, e.g. +9198xxxxxx', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: '+91XXXXXXXXXX'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final num = controller.text.trim();
                try {
                  await FirebaseFirestore.instance
                      .collection('appSettings')
                      .doc('eventChoreo')
                      .set({'whatsappNumber': num, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp number saved')));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to save WhatsApp number. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openWhatsAppForBooking(String bookingId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('appSettings').doc('eventChoreo').get();
      final number = (doc.data() ?? const {})['whatsappNumber'] as String?;
      if (number == null || number.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp number not set. Tap the green icon on top to set it.')),
        );
        return;
      }
      final phone = number.replaceAll(RegExp(r'[^0-9+]'), '');
      final Uri uri = Uri.parse('https://wa.me/$phone?text=' + Uri.encodeComponent('Hello, regarding booking $bookingId'));
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open WhatsApp')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load rates. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _contactController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _venueController.dispose();
    _numDancesController.dispose();
    _refreshSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadRates();
    // Listen for backend confirmations to refresh bookings
    _refreshSub = PaymentService.refreshStream.listen((event) {
      final t = (event['type'] as String?) ?? '';
      if (t == 'payment_success' || t == 'enrollment_updated') {
        setState(() {}); // triggers StreamBuilder rebuild
      }
    });
  }
  
  Future<void> _loadRates() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('eventChoreoRates')
          .get();
      
      if (doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          _rates = {
            'school_1_5': (data['school_1_5'] as num?)?.toInt() ?? 5500,
            'school_6_plus': (data['school_6_plus'] as num?)?.toInt() ?? 4500,
            'sangeet_1_5': (data['sangeet_1_5'] as num?)?.toInt() ?? 8500,
            'sangeet_6_plus': (data['sangeet_6_plus'] as num?)?.toInt() ?? 7500,
            'corporate_1_5': (data['corporate_1_5'] as num?)?.toInt() ?? 8500,
            'corporate_6_plus': (data['corporate_6_plus'] as num?)?.toInt() ?? 7500,
            'extra_person': (data['extra_person'] as num?)?.toInt() ?? 1000,
          };
          _rules = {
            'advance_percentage': (data['advance_percentage'] as num?)?.toInt() ?? 50,
            'cancellation_days': (data['cancellation_days'] as num?)?.toInt() ?? 7,
            'rescheduling_hours': (data['rescheduling_hours'] as num?)?.toInt() ?? 48,
          };
        });
      } else {
      }
    } catch (e) {
    }
  }

  Widget _buildPackageSelector() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Event Type',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildPackageOption(
                      'school',
                      'School Function',
                      Icons.school,
                      const Color(0xFFE53935),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPackageOption(
                      'sangeet',
                      'Sangeet Function',
                      Icons.directions_run,
                      const Color(0xFFE53935),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPackageOption(
                      'corporate',
                      'Corporate Function',
                      Icons.business,
                      const Color(0xFFE53935),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackageOption(String value, String title, IconData icon, Color color) {
    final isSelected = _selectedPackage == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPackage = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.white70,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? color : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pricing Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildPricingDetails(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPricingDetails() {
    switch (_selectedPackage) {
      case 'school':
        return _buildSchoolPricing();
      case 'sangeet':
        return _buildSangeetPricing();
      case 'corporate':
        return _buildCorporatePricing();
      default:
        return _buildSchoolPricing();
    }
  }

  Widget _buildSchoolPricing() {
    final rate1_5 = _rates['school_1_5'] as int? ?? 5500;
    final rate6_plus = _rates['school_6_plus'] as int? ?? 4500;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPriceItem('Per Dance', '₹${_formatCurrency(rate1_5)}', 'For 1-5 dances'),
        _buildPriceItem('Per Dance', '₹${_formatCurrency(rate6_plus)}', 'For 6+ dances'),
        const SizedBox(height: 12),
        const Text(
          'Includes:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _buildIncludedItem('Song suggestions'),
        _buildIncludedItem('Song editing'),
        _buildIncludedItem('Practice sessions'),
      ],
    );
  }

  Widget _buildSangeetPricing() {
    final rate1_5 = _rates['sangeet_1_5'] as int? ?? 8500;
    final rate6_plus = _rates['sangeet_6_plus'] as int? ?? 7500;
    final extraPerson = _rates['extra_person'] as int? ?? 1000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPriceItem('Per Dance', '₹${_formatCurrency(rate1_5)}', 'For 1-5 dances'),
        _buildPriceItem('Per Dance', '₹${_formatCurrency(rate6_plus)}', 'For 6+ dances'),
        _buildPriceItem('Group Dance (5-6 members)', 'Normal rate', 'Standard group size'),
        _buildPriceItem('Extra person', '₹${_formatCurrency(extraPerson)}', 'Per additional person'),
        const SizedBox(height: 12),
        const Text(
          'Includes:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _buildIncludedItem('Song suggestions'),
        _buildIncludedItem('Song editing'),
        _buildIncludedItem('Practice sessions'),
      ],
    );
  }

  Widget _buildCorporatePricing() {
    final rate1_5 = _rates['corporate_1_5'] as int? ?? 8500;
    final rate6_plus = _rates['corporate_6_plus'] as int? ?? 7500;
    final extraPerson = _rates['extra_person'] as int? ?? 1000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPriceItem('Per Dance', '₹${_formatCurrency(rate1_5)}', 'For 1-5 dances'),
        _buildPriceItem('Per Dance', '₹${_formatCurrency(rate6_plus)}', 'For 6+ dances'),
        _buildPriceItem('Group Dance (5-6 members)', 'Normal rate', 'Standard group size'),
        _buildPriceItem('Extra person', '₹${_formatCurrency(extraPerson)}', 'Per additional person'),
        const SizedBox(height: 12),
        const Text(
          'Includes:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _buildIncludedItem('Song suggestions'),
        _buildIncludedItem('Song editing'),
        _buildIncludedItem('Practice sessions'),
      ],
    );
  }

  Widget _buildPriceItem(String title, String price, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: const TextStyle(
              color: Color(0xFFE53935),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncludedItem(String item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: Color(0xFF10B981),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            item,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesCard() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Booking Rules & Terms',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildRuleItem(
                'Advance Payment',
                '50% of total amount required for booking confirmation',
                Icons.payment,
                const Color(0xFF4F46E5),
              ),
              _buildRuleItem(
                'Final Payment',
                'Remaining 50% to be paid 1 day before the event',
                Icons.schedule,
                const Color(0xFFFF9800),
              ),
              _buildRuleItem(
                'Session Schedule',
                'Practice sessions will be decided by our teachers',
                Icons.calendar_today,
                const Color(0xFF10B981),
              ),
              _buildRuleItem(
                'Non-Refundable',
                'Booking amount is non-refundable once confirmed',
                Icons.warning,
                const Color(0xFFE53935),
              ),
              _buildRuleItem(
                'Cancellation Policy',
                'No refunds for cancellations within 7 days of event',
                Icons.cancel,
                const Color(0xFF9C27B0),
              ),
              _buildRuleItem(
                'Rescheduling',
                'Event can be rescheduled with 48 hours notice',
                Icons.update,
                const Color(0xFF42A5F5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleItem(String title, String description, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesCard() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What We Provide',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildFeatureItem('Professional Choreographers', Icons.person),
              _buildFeatureItem('Custom Song Selection', Icons.directions_run),
              _buildFeatureItem('Song Editing & Mixing', Icons.audiotrack),
              _buildFeatureItem('Practice Sessions', Icons.schedule),
              _buildFeatureItem('Costume Suggestions', Icons.checkroom),
              _buildFeatureItem('Performance Guidance', Icons.star),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF10B981),
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonialsCard() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Client Testimonials',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildTestimonialItem(
                'Priya Sharma',
                'School Function',
                'Amazing choreography for our annual function! The team was professional and creative.',
                '⭐⭐⭐⭐⭐',
              ),
              const SizedBox(height: 12),
              _buildTestimonialItem(
                'Raj Patel',
                'Sangeet Function',
                'Perfect blend of traditional and modern dance. Highly recommended!',
                '⭐⭐⭐⭐⭐',
              ),
              const SizedBox(height: 12),
              _buildTestimonialItem(
                'Sneha Singh',
                'Corporate Event',
                'Great team, excellent coordination. Our employees loved the performance!',
                '⭐⭐⭐⭐⭐',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestimonialItem(String name, String event, String review, String rating) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFE53935).withValues(alpha: 0.2),
                child: Text(
                  name[0],
                  style: const TextStyle(
                    color: Color(0xFFE53935),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      event,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                rating,
                style: const TextStyle(
                  color: Color(0xFFFF9800),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _openBookingForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBookingForm(),
    );
  }

  Widget _buildBookingForm() {
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside text fields
        FocusScope.of(context).unfocus();
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Color(0xFF1B1B1B),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Book Event Choreography',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDropdownField('Event Type', _getSelectedPackageName()),
                    const SizedBox(height: 16),
                    _buildFormField('Contact Person', 'Enter your name', controller: _contactController, onChanged: (_) => setState(() {})),
                    const SizedBox(height: 16),
                    _buildFormField('Phone Number', 'Enter your phone number', controller: _phoneController, keyboardType: TextInputType.phone, onChanged: (_) => setState(() {})),
                    const SizedBox(height: 16),
                    _buildFormField('Email', 'Enter your email address', controller: _emailController, keyboardType: TextInputType.emailAddress, onChanged: (_) => setState(() {})),
                    const SizedBox(height: 16),
                    _buildDateField('Event Date', 'Select event date'),
                    const SizedBox(height: 16),
                    _buildFormField('Event Venue', 'Enter event venue', controller: _venueController, onChanged: (_) => setState(() {})),
                    const SizedBox(height: 16),
                    _buildFormField(
                      'Number of Dances',
                      'Enter number of dances',
                      controller: _numDancesController,
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        final parsed = int.tryParse(val.trim());
                        setState(() {
                          _numDances = (parsed != null && parsed > 0) ? parsed : 1;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildFormField('Group Size', 'Enter group size (if applicable)'),
                    const SizedBox(height: 16),
                    _buildFormField('Special Requirements', 'Any special requirements'),
                    const SizedBox(height: 20),
                    const Text(
                      'Payment Summary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Amount:', style: TextStyle(color: Colors.white70)),
                              Text('₹${_calculateTotalAmount()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Advance (50%):', style: TextStyle(color: Colors.white70)),
                              Text('₹${_calculateAdvanceAmount()}', style: const TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Final Payment:', style: TextStyle(color: Colors.white70)),
                              Text('₹${_calculateFinalAmount()}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isBooking ? null : _processBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Confirm Booking',
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
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildFormField(String label, String hint, {TextEditingController? controller, TextInputType? keyboardType, void Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE53935)),
            ),
          ),
          style: const TextStyle(color: Colors.white),
          keyboardType: keyboardType,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: DropdownButtonHideUnderline(
            child: Theme(
              data: Theme.of(context).copyWith(
                canvasColor: const Color(0xFF2B2B2B),
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
              ),
            child: DropdownButton<String>(
              value: _selectedPackage,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                underline: const SizedBox.shrink(),
                alignment: AlignmentDirectional.centerStart,
                menuMaxHeight: 320,
              items: const [
                DropdownMenuItem(
                  value: 'school',
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('School Function', style: TextStyle(color: Colors.white)),
                    ),
                ),
                DropdownMenuItem(
                  value: 'sangeet',
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Sangeet Function', style: TextStyle(color: Colors.white)),
                    ),
                ),
                DropdownMenuItem(
                  value: 'corporate',
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Corporate Function', style: TextStyle(color: Colors.white)),
                    ),
                ),
              ],
              onChanged: (String? newValue) {
                  if (newValue == null) return;
                  setState(() {
                    _selectedPackage = newValue;
                  });
              },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
                const SizedBox(width: 12),
                Text(
                  _selectedDateText,
                  style: TextStyle(
                    color: _selectedDate != null ? Colors.white : Colors.white70,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.arrow_drop_down, color: Colors.white70),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getSelectedPackageName() {
    switch (_selectedPackage) {
      case 'school':
        return 'School Function';
      case 'sangeet':
        return 'Sangeet Function';
      case 'corporate':
        return 'Corporate Function';
      default:
        return 'School Function';
    }
  }

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  int _getPerDanceRate() {
    // Rates from Firestore
    switch (_selectedPackage) {
      case 'school':
        return _numDances >= 6 
            ? (_rates['school_6_plus'] as int? ?? 4500)
            : (_rates['school_1_5'] as int? ?? 5500);
      case 'sangeet':
        return _numDances >= 6
            ? (_rates['sangeet_6_plus'] as int? ?? 7500)
            : (_rates['sangeet_1_5'] as int? ?? 8500);
      case 'corporate':
        return _numDances >= 6
            ? (_rates['corporate_6_plus'] as int? ?? 7500)
            : (_rates['corporate_1_5'] as int? ?? 8500);
      default:
        return _rates['school_1_5'] as int? ?? 5500;
    }
  }

  int _calculateTotalAmount() {
    final perDance = _getPerDanceRate();
    return perDance * (_numDances > 0 ? _numDances : 1);
  }

  int _calculateAdvanceAmount() {
    final percentage = _rules['advance_percentage'] as int? ?? 50;
    return (_calculateTotalAmount() * percentage / 100).round();
  }

  int _calculateFinalAmount() {
    return _calculateTotalAmount() - _calculateAdvanceAmount();
  }

  void _processBooking() async {
    if (_isBooking) return;
    setState(() {
      _isBooking = true;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to book'),
          backgroundColor: Colors.red,
        ),
      );
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      setState(() {
        _isBooking = false;
      });
      return;
    }

    // Create booking first
    final bookingRef = FirebaseFirestore.instance.collection('eventChoreoBookings').doc();
    final bookingId = bookingRef.id;

    final data = {
      'bookingId': bookingId,
      'userId': user.uid,
      'package': _selectedPackage,
      'packageName': _getSelectedPackageName(),
      'eventDate': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
      'contactName': _contactController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'venue': _venueController.text.trim(),
      'numDances': _numDances,
      'status': 'pending', // pending → confirmed → in_progress → completed
      'totalAmount': _calculateTotalAmount(),
      'advanceAmount': _calculateAdvanceAmount(),
      'finalAmount': _calculateFinalAmount(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await bookingRef.set(data);
      
      // Ask payment choice (Online or Cash)
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          backgroundColor: const Color(0xFF1B1B1B),
          title: const Text('Select Payment Method', style: TextStyle(color: Colors.white)),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'online'),
              child: const ListTile(
                leading: Icon(Icons.payment, color: Colors.orange),
                title: Text('Online Payment', style: TextStyle(color: Colors.white)),
                subtitle: Text('Pay advance now', style: TextStyle(color: Colors.white70)),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'cash'),
              child: const ListTile(
                leading: Icon(Icons.money, color: Color(0xFF10B981)),
                title: Text('Mark as Paid Cash', style: TextStyle(color: Colors.white)),
                subtitle: Text('Send for admin approval', style: TextStyle(color: Colors.white70)),
              ),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (choice == null) {
        // User closed dialog; keep booking as pending
        setState(() => _isBooking = false);
        return;
      }

      if (choice == 'cash') {
        final paymentId = PaymentService.generatePaymentId();
        final res = await PaymentService.requestCashPayment(
          paymentId: paymentId,
          amount: _calculateAdvanceAmount(),
          description: 'Event Choreography Advance: ${_getSelectedPackageName()}',
          paymentType: 'event_choreography',
          itemId: bookingId,
          metadata: {
            'booking_id': bookingId,
            'package': _selectedPackage,
            'package_name': _getSelectedPackageName(),
            'total_amount': _calculateTotalAmount(),
            'advance_amount': _calculateAdvanceAmount(),
            'final_amount': _calculateFinalAmount(),
            'event_date': _selectedDate?.toIso8601String(),
          },
        );
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sent for admin confirmation (cash payment)'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to request cash approval: ${res['error'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        return;
      }

      // Online payment flow
      final paymentId = PaymentService.generatePaymentId();
      final result = await PaymentService.processPayment(
        paymentId: paymentId,
        amount: _calculateAdvanceAmount(),
        description: 'Event Choreography Advance: ${_getSelectedPackageName()}',
        paymentType: 'event_choreography',
        itemId: bookingId,
        metadata: {
          'booking_id': bookingId,
          'package': _selectedPackage,
          'package_name': _getSelectedPackageName(),
          'total_amount': _calculateTotalAmount(),
          'advance_amount': _calculateAdvanceAmount(),
          'final_amount': _calculateFinalAmount(),
          'event_date': _selectedDate?.toIso8601String(),
        },
      );

      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Redirecting to payment...'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${result['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create booking: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBooking = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE53935),
              onPrimary: Colors.white,
              surface: Color(0xFF2B2B2B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      if (!mounted) return;
      // Immediately update the form
      setState(() {
        _selectedDate = picked;
        _selectedDateText = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  Future<void> _editRates() async {
    if (widget.role != 'admin') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only admins can edit rates'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Load latest rates from Firestore before opening modal
    await _loadRates();
    
    // Clear existing controllers to start fresh with latest values
    _rateControllers.forEach((key, controller) => controller.dispose());
    _rateControllers.clear();
    _ruleControllers.forEach((key, controller) => controller.dispose());
    _ruleControllers.clear();
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEditRatesForm(),
    ).then((_) {
      // Clear controllers when modal closes
      _rateControllers.forEach((key, controller) => controller.dispose());
      _rateControllers.clear();
      _ruleControllers.forEach((key, controller) => controller.dispose());
      _ruleControllers.clear();
    });
  }

  Widget _buildMyBookingsCard() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Event Bookings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _userBookingsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white70));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text('No bookings yet', style: TextStyle(color: Colors.white70));
                  }
                  final docs = snapshot.data!.docs;
                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data();
                      final status = (data['status'] as String? ?? 'pending');
                      final packageName = data['packageName'] as String? ?? '';
                      final createdAt = (data['createdAt'] is Timestamp)
                          ? (data['createdAt'] as Timestamp).toDate()
                          : null;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(packageName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    createdAt != null ? 'Created • ${createdAt.day}/${createdAt.month}/${createdAt.year}' : 'Created • —',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildStatusBadge(status),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => EventChoreoChatScreen(bookingId: data['bookingId'] as String, isAdmin: widget.role == 'admin'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.chat, color: Colors.white70, size: 18),
                              label: const Text('Chat', style: TextStyle(color: Colors.white70)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'confirmed':
        color = const Color(0xFF10B981);
        break;
      case 'in_progress':
        color = const Color(0xFFFF9800);
        break;
      case 'completed':
        color = const Color(0xFF4F46E5);
        break;
      default:
        color = const Color(0xFFE53935);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEditRatesForm() {
    // Initialize controllers only if they don't exist - preserve user input
    _rateControllers['school_1_5'] ??= TextEditingController(text: _rates['school_1_5'].toString());
    _rateControllers['school_6_plus'] ??= TextEditingController(text: _rates['school_6_plus'].toString());
    _rateControllers['sangeet_1_5'] ??= TextEditingController(text: _rates['sangeet_1_5'].toString());
    _rateControllers['sangeet_6_plus'] ??= TextEditingController(text: _rates['sangeet_6_plus'].toString());
    _rateControllers['corporate_1_5'] ??= TextEditingController(text: _rates['corporate_1_5'].toString());
    _rateControllers['corporate_6_plus'] ??= TextEditingController(text: _rates['corporate_6_plus'].toString());
    _rateControllers['extra_person'] ??= TextEditingController(text: _rates['extra_person'].toString());
    
    _ruleControllers['advance_percentage'] ??= TextEditingController(text: _rules['advance_percentage'].toString());
    _ruleControllers['cancellation_days'] ??= TextEditingController(text: _rules['cancellation_days'].toString());
    _ruleControllers['rescheduling_hours'] ??= TextEditingController(text: _rules['rescheduling_hours'].toString());
    
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B1B),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
        child: Stack(
          children: [
            Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Edit Rates & Rules',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEditablePricingCard(),
                    const SizedBox(height: 20),
                    _buildEditableRulesCard(),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSavingRates ? null : _saveRates,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
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
              ),
            ],
              ),
            ),
            // Custom toolbar above keyboard
            Builder(
              builder: (context) {
                final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
                if (keyboardHeight > 0) {
                  return Positioned(
                    bottom: keyboardHeight,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 44,
                      color: const Color(0xFF1B1B1B),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextButton(
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                              },
                              child: const Text(
                                'Done',
                                style: TextStyle(
                                  color: Color(0xFFE53935),
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
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditablePricingCard() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Pricing',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildEditablePriceField('School Function (1-5 dances)', 'school_1_5'),
              const SizedBox(height: 12),
              _buildEditablePriceField('School Function (6+ dances)', 'school_6_plus'),
              const SizedBox(height: 12),
              _buildEditablePriceField('Sangeet Function (1-5 dances)', 'sangeet_1_5'),
              const SizedBox(height: 12),
              _buildEditablePriceField('Sangeet Function (6+ dances)', 'sangeet_6_plus'),
              const SizedBox(height: 12),
              _buildEditablePriceField('Corporate Function (1-5 dances)', 'corporate_1_5'),
              const SizedBox(height: 12),
              _buildEditablePriceField('Corporate Function (6+ dances)', 'corporate_6_plus'),
              const SizedBox(height: 12),
              _buildEditablePriceField('Extra Person Charge', 'extra_person'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableRulesCard() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Rules',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildEditableRuleField('Advance Payment Percentage', 'advance_percentage'),
              const SizedBox(height: 12),
              _buildEditableRuleField('Cancellation Notice (days)', 'cancellation_days'),
              const SizedBox(height: 12),
              _buildEditableRuleField('Rescheduling Notice (hours)', 'rescheduling_hours'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditablePriceField(String label, String key) {
    final controller = _rateControllers[key];
    if (controller == null) return const SizedBox.shrink();
    
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 100,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '₹',
              hintStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE53935)),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onEditingComplete: () {
              FocusScope.of(context).unfocus();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEditableRuleField(String label, String key) {
    final controller = _ruleControllers[key];
    if (controller == null) return const SizedBox.shrink();
    
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 100,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Enter value',
              hintStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE53935)),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onEditingComplete: () {
              FocusScope.of(context).unfocus();
            },
          ),
        ),
      ],
    );
  }

  Future<void> _saveRates() async {
    if (_isSavingRates) return;
    
    // Dismiss keyboard first
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isSavingRates = true;
    });
    
    try {
      // Read values from controllers
      final updatedRates = <String, int>{};
      _rateControllers.forEach((key, controller) {
        final textValue = controller.text.trim();
        final value = int.tryParse(textValue) ?? 0;
        updatedRates[key] = value;
      });
      
      final updatedRules = <String, int>{};
      _ruleControllers.forEach((key, controller) {
        final textValue = controller.text.trim();
        final value = int.tryParse(textValue) ?? 0;
        updatedRules[key] = value;
      });
      
      // Save to Firestore
      final saveData = {
        ...updatedRates,
        ...updatedRules,
      };
      
      await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('eventChoreoRates')
          .set(saveData, SetOptions(merge: true));
      
      
      // Close modal first
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      // Reload rates from Firestore to ensure sync
      await _loadRates();
      
    if (!mounted) return;
      
      // Force UI rebuild after rates are loaded
      setState(() {
      });
      
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rates and rules updated successfully!'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving rates: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
    if (mounted) {
      setState(() {
        _isSavingRates = false;
      });
      }
    }
  }

  Future<void> _refreshEvents() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate loading delay
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }
}

class _PackageSelector extends StatelessWidget {
  final String selectedPackage;
  final ValueChanged<String> onSelect;

  const _PackageSelector({
    required this.selectedPackage,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Event Type',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _PackageOption(
                      value: 'school',
                      title: 'School Function',
                      icon: Icons.school,
                      color: const Color(0xFFE53935),
                      selected: selectedPackage == 'school',
                      onTap: () => onSelect('school'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PackageOption(
                      value: 'sangeet',
                      title: 'Sangeet Function',
                      icon: Icons.directions_run,
                      color: const Color(0xFFE53935),
                      selected: selectedPackage == 'sangeet',
                      onTap: () => onSelect('sangeet'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PackageOption(
                      value: 'corporate',
                      title: 'Corporate Function',
                      icon: Icons.business,
                      color: const Color(0xFFE53935),
                      selected: selectedPackage == 'corporate',
                      onTap: () => onSelect('corporate'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackageOption extends StatelessWidget {
  final String value;
  final String title;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PackageOption({
    required this.value,
    required this.title,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.white.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? color : Colors.white70,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: selected ? color : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String selectedPackage;
  final Map<String, dynamic> rates;

  const _PricingCard({required this.selectedPackage, required this.rates});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pricing Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _PricingDetails(selectedPackage: selectedPackage, rates: rates),
            ],
          ),
        ),
      ),
    );
  }
}

class _PricingDetails extends StatelessWidget {
  final String selectedPackage;
  final Map<String, dynamic> rates;
  const _PricingDetails({required this.selectedPackage, required this.rates});

  @override
  Widget build(BuildContext context) {
    switch (selectedPackage) {
      case 'sangeet':
        return _SangeetPricing(rates: rates);
      case 'corporate':
        return _CorporatePricing(rates: rates);
      case 'school':
      default:
        return _SchoolPricing(rates: rates);
    }
  }
}

class _SchoolPricing extends StatelessWidget {
  final Map<String, dynamic> rates;
  const _SchoolPricing({required this.rates});
  
  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final rate1_5 = (rates['school_1_5'] as num?)?.toInt() ?? 5500;
    final rate6_plus = (rates['school_6_plus'] as num?)?.toInt() ?? 4500;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PriceItem(title: 'Per Dance', price: '₹${_formatCurrency(rate1_5)}', description: 'For 1-5 dances'),
        _PriceItem(title: 'Per Dance', price: '₹${_formatCurrency(rate6_plus)}', description: 'For 6+ dances'),
        const SizedBox(height: 12),
        const Text('Includes:', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const _IncludedItem('Song suggestions'),
        const _IncludedItem('Song editing'),
        const _IncludedItem('Practice sessions'),
      ],
    );
  }
}

class _SangeetPricing extends StatelessWidget {
  final Map<String, dynamic> rates;
  const _SangeetPricing({required this.rates});
  
  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final rate1_5 = (rates['sangeet_1_5'] as num?)?.toInt() ?? 8500;
    final rate6_plus = (rates['sangeet_6_plus'] as num?)?.toInt() ?? 7500;
    final extraPerson = (rates['extra_person'] as num?)?.toInt() ?? 1000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PriceItem(title: 'Per Dance', price: '₹${_formatCurrency(rate1_5)}', description: 'For 1-5 dances'),
        _PriceItem(title: 'Per Dance', price: '₹${_formatCurrency(rate6_plus)}', description: 'For 6+ dances'),
        const _PriceItem(title: 'Group Dance (5-6 members)', price: 'Normal rate', description: 'Standard group size'),
        _PriceItem(title: 'Extra person', price: '₹${_formatCurrency(extraPerson)}', description: 'Per additional person'),
        const SizedBox(height: 12),
        const Text('Includes:', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const _IncludedItem('Song suggestions'),
        const _IncludedItem('Song editing'),
        const _IncludedItem('Practice sessions'),
      ],
    );
  }
}

class _CorporatePricing extends StatelessWidget {
  final Map<String, dynamic> rates;
  const _CorporatePricing({required this.rates});
  
  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final rate1_5 = (rates['corporate_1_5'] as num?)?.toInt() ?? 8500;
    final rate6_plus = (rates['corporate_6_plus'] as num?)?.toInt() ?? 7500;
    final extraPerson = (rates['extra_person'] as num?)?.toInt() ?? 1000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PriceItem(title: 'Per Dance', price: '₹${_formatCurrency(rate1_5)}', description: 'For 1-5 dances'),
        _PriceItem(title: 'Per Dance', price: '₹${_formatCurrency(rate6_plus)}', description: 'For 6+ dances'),
        const _PriceItem(title: 'Group Dance (5-6 members)', price: 'Normal rate', description: 'Standard group size'),
        _PriceItem(title: 'Extra person', price: '₹${_formatCurrency(extraPerson)}', description: 'Per additional person'),
        const SizedBox(height: 12),
        const Text('Includes:', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const _IncludedItem('Song suggestions'),
        const _IncludedItem('Song editing'),
        const _IncludedItem('Practice sessions'),
      ],
    );
  }
}

class _PriceItem extends StatelessWidget {
  final String title;
  final String price;
  final String description;
  const _PriceItem({required this.title, required this.price, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                Text(description, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Text(price, style: const TextStyle(color: Color(0xFFE53935), fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _IncludedItem extends StatelessWidget {
  final String item;
  const _IncludedItem(this.item);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
          const SizedBox(width: 8),
          Text(item, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }
}

class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Theme.of(context).cardColor, Theme.of(context).cardColor.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What We Provide', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              _FeatureItem('Professional Choreographers', Icons.person),
              _FeatureItem('Custom Song Selection', Icons.directions_run),
              _FeatureItem('Song Editing & Mixing', Icons.audiotrack),
              _FeatureItem('Practice Sessions', Icons.schedule),
              _FeatureItem('Costume Suggestions', Icons.checkroom),
              _FeatureItem('Performance Guidance', Icons.star),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final String title;
  final IconData icon;
  const _FeatureItem(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF10B981), size: 20),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }
}

class _TestimonialsCard extends StatelessWidget {
  const _TestimonialsCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Theme.of(context).cardColor, Theme.of(context).cardColor.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Client Testimonials', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              _TestimonialItem(
                name: 'Priya Sharma',
                type: 'School Function',
                review: 'Amazing choreography for our annual function! The team was professional and creative.',
                rating: '⭐⭐⭐⭐⭐',
              ),
              SizedBox(height: 12),
              _TestimonialItem(
                name: 'Raj Patel',
                type: 'Sangeet Function',
                review: 'Perfect blend of traditional and modern dance. Highly recommended!',
                rating: '⭐⭐⭐⭐⭐',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestimonialItem extends StatelessWidget {
  final String name;
  final String type;
  final String review;
  final String rating;
  const _TestimonialItem({required this.name, required this.type, required this.review, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(type, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(review, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
        const SizedBox(height: 4),
        Text(rating, style: const TextStyle(color: Color(0xFFFFD700), fontSize: 14)),
      ],
    );
  }
}

class _MyBookingsCard extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final bool isAdmin;
  final Future<void> Function(String bookingId)? onChatWhatsApp;
  const _MyBookingsCard({required this.stream, required this.isAdmin, this.onChatWhatsApp});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Theme.of(context).cardColor, Theme.of(context).cardColor.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('My Bookings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white70));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text('No bookings yet.', style: TextStyle(color: Colors.white70));
                  }
                  final docs = snapshot.data!.docs;
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (data['packageName'] as String?) ?? 'Package',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Status: ${(data['status'] as String?) ?? 'pending'}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white70),
                              tooltip: 'WhatsApp',
                              onPressed: () async {
                                final id = (data['bookingId'] as String?) ?? '';
                                if (onChatWhatsApp != null) {
                                  await onChatWhatsApp!(id);
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Booking Rules & Terms',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const _RuleItem(
                title: 'Advance Payment',
                description: '50% of total amount required for booking confirmation',
                icon: Icons.payment,
                color: Color(0xFF4F46E5),
              ),
              const _RuleItem(
                title: 'Final Payment',
                description: 'Remaining 50% to be paid 1 day before the event',
                icon: Icons.schedule,
                color: Color(0xFFFF9800),
              ),
              const _RuleItem(
                title: 'Session Schedule',
                description: 'Practice sessions will be decided by our teachers',
                icon: Icons.calendar_today,
                color: Color(0xFF10B981),
              ),
              const _RuleItem(
                title: 'Non-Refundable',
                description: 'Booking amount is non-refundable once confirmed',
                icon: Icons.warning,
                color: Color(0xFFE53935),
              ),
              const _RuleItem(
                title: 'Cancellation Policy',
                description: 'No refunds for cancellations within 7 days of event',
                icon: Icons.cancel,
                color: Color(0xFF9C27B0),
              ),
              const _RuleItem(
                title: 'Rescheduling',
                description: 'Event can be rescheduled with 48 hours notice',
                icon: Icons.update,
                color: Color(0xFF42A5F5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _RuleItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}