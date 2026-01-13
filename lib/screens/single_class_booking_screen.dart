import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/class_enrollment_model.dart';
import '../services/class_enrollment_service.dart';
import '../widgets/glassmorphism_app_bar.dart';

class SingleClassBookingScreen extends StatefulWidget {
  const SingleClassBookingScreen({super.key});

  @override
  State<SingleClassBookingScreen> createState() => _SingleClassBookingScreenState();
}

class _SingleClassBookingScreenState extends State<SingleClassBookingScreen> {
  String _selectedDanceStyle = '';
  String _selectedInstructor = '';
  DateTime? _selectedDate;
  String _selectedTime = '';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _availableClasses = [];
  List<String> _danceStyles = [];
  List<String> _instructors = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableClasses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableClasses() async {
    setState(() => _isLoading = true);
    
    try {
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('status', isEqualTo: 'published')
          .get();

      final classes = classesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'danceStyle': data['danceStyle'] ?? '',
          'instructor': data['instructor'] ?? '',
          'price': data['price'] ?? 0,
          'duration': data['duration'] ?? 60,
          'maxStudents': data['maxStudents'] ?? 20,
          'currentStudents': data['currentStudents'] ?? 0,
          'schedule': data['schedule'] ?? {},
        };
      }).toList();

      setState(() {
        _availableClasses = classes;
        _danceStyles = classes.map((c) => c['danceStyle'] as String).toSet().toList();
        _instructors = classes.map((c) => c['instructor'] as String).toSet().toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading classes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'Single Class Booking',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAvailableClasses,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Section
                  _buildFilterSection(),
                  const SizedBox(height: 20),
                  
                  // Available Classes
                  Text(
                    'Available Classes',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildClassesList(),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Classes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Dance Style Filter
            DropdownButtonFormField<String>(
              value: _selectedDanceStyle.isEmpty ? null : _selectedDanceStyle,
              decoration: const InputDecoration(
                labelText: 'Dance Style',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('All Styles')),
                ..._danceStyles.map((style) => DropdownMenuItem(
                  value: style,
                  child: Text(style),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedDanceStyle = value ?? '';
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Instructor Filter
            DropdownButtonFormField<String>(
              value: _selectedInstructor.isEmpty ? null : _selectedInstructor,
              decoration: const InputDecoration(
                labelText: 'Instructor',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('All Instructors')),
                ..._instructors.map((instructor) => DropdownMenuItem(
                  value: instructor,
                  child: Text(instructor),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedInstructor = value ?? '';
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassesList() {
    final filteredClasses = _availableClasses.where((cls) {
      if (_selectedDanceStyle.isNotEmpty && cls['danceStyle'] != _selectedDanceStyle) {
        return false;
      }
      if (_selectedInstructor.isNotEmpty && cls['instructor'] != _selectedInstructor) {
        return false;
      }
      return true;
    }).toList();

    if (filteredClasses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No classes available',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredClasses.length,
      itemBuilder: (context, index) {
        final cls = filteredClasses[index];
        return _buildClassCard(cls);
      },
    );
  }

  Widget _buildClassCard(Map<String, dynamic> cls) {
    final isFullyBooked = cls['currentStudents'] >= cls['maxStudents'];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cls['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${cls['danceStyle']} • ${cls['instructor']}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${cls['price']}',
                  style: const TextStyle(
                    color: Color(0xFFE53935),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${cls['duration']} minutes',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 16),
                Icon(Icons.people, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${cls['currentStudents']}/${cls['maxStudents']} students',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isFullyBooked ? null : () => _showBookingDialog(cls),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFullyBooked ? Colors.grey : const Color(0xFFE53935),
                ),
                child: Text(
                  isFullyBooked ? 'Fully Booked' : 'Join Now',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingDialog(Map<String, dynamic> cls) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: Text(
          'Book ${cls['name']}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => _joinClassWithPayment(cls),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            child: const Text('Proceed to Pay', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _joinClassWithPayment(Map<String, dynamic> cls) async {
    if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to join a class')),
        );
        return;
      }

      setState(() => _isLoading = true);

      // Create a single-session package to mirror normal enrollment structure
      final ClassPackage singleSessionPackage = ClassPackage(
        id: 'single_class_1',
        name: 'Single Class',
        description: 'Access for this single class session',
        price: (cls['price'] as num?)?.toDouble() ?? 0,
        totalSessions: 1,
        validityDays: 7,
        features: const ['1 session', 'Valid 7 days'],
        category: 'single',
        isRecommended: false,
      );

      // Enroll via shared service (handles payment via Razorpay)
      final result = await ClassEnrollmentService.enrollInClass(
        classId: cls['id'] as String,
        className: cls['name'] as String,
        package: singleSessionPackage,
        userId: user.uid,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.pop(context);
      }

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enrollment created. Complete payment to confirm.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );

        // Clear form and refresh list; counts update via global refresh after payment
        _nameController.clear();
        _phoneController.clear();
        _loadAvailableClasses();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Failed to start enrollment'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to start payment: $e'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }
}
