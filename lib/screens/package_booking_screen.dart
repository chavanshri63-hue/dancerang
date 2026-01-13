import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';
import '../models/class_enrollment_model.dart';
import '../services/class_enrollment_service.dart';

class PackageBookingScreen extends StatefulWidget {
  final String packageType;
  
  const PackageBookingScreen({
    super.key,
    required this.packageType,
  });

  @override
  State<PackageBookingScreen> createState() => _PackageBookingScreenState();
}

class _PackageBookingScreenState extends State<PackageBookingScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _selectedDuration = '1 month';
  String _selectedClasses = '8';
  bool _isLoading = false;
  Map<String, dynamic>? _packageDetails;

  final Map<String, Map<String, dynamic>> _packageOptions = {
    '1 month': {
      'classes': ['4', '8', '12'],
      'prices': {'4': 2000, '8': 3500, '12': 4800},
    },
    '3 months': {
      'classes': ['12', '24', '36'],
      'prices': {'12': 5500, '24': 10000, '36': 13500},
    },
    '6 months': {
      'classes': ['24', '48', '72'],
      'prices': {'24': 18000, '48': 32000, '72': 42000},
    },
    '1 year': {
      'classes': ['48', '96', '144'],
      'prices': {'48': 32000, '96': 58000, '72': 78000},
    },
  };

  @override
  void initState() {
    super.initState();
    _loadAvailableClasses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadPackageDetails() async {
    setState(() => _isLoading = true);
    
    try {
      // Load package details from Firestore or use default
      final packageSnapshot = await FirebaseFirestore.instance
          .collection('subscription_plans')
          .where('type', isEqualTo: widget.packageType.toLowerCase())
          .limit(1)
          .get();

      if (packageSnapshot.docs.isNotEmpty) {
        setState(() {
          _packageDetails = packageSnapshot.docs.first.data();
          _isLoading = false;
        });
      } else {
        // Use default package details
        setState(() {
          _packageDetails = {
            'name': '${widget.packageType} Package',
            'description': 'Perfect for ${widget.packageType.toLowerCase()} commitment',
            'features': [
              'Unlimited access to all classes',
              'Priority booking',
              'Free practice sessions',
              'Progress tracking',
            ],
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading package details: $e'),
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
        title: 'Join Classes',
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

  List<Map<String, dynamic>> _availableClasses = [];

  Widget _buildClassesList() {
    if (_availableClasses.isEmpty) {
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
      itemCount: _availableClasses.length,
      itemBuilder: (context, index) {
        final cls = _availableClasses[index];
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
          'Join ${cls['name']}',
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

  Widget _buildPackageDetailsCard() {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _packageDetails?['name'] ?? '${widget.packageType} Package',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _packageDetails?['description'] ?? 'Perfect for ${widget.packageType.toLowerCase()} commitment',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'Package Features:',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            ...(_packageDetails?['features'] ?? [
              'Unlimited access to all classes',
              'Priority booking',
              'Free practice sessions',
              'Progress tracking',
            ]).map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFFE53935), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingForm() {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking Details',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Duration Selection
            Text(
              'Package Duration',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedDuration,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: _packageOptions.keys.map<DropdownMenuItem<String>>((duration) {
                return DropdownMenuItem<String>(
                  value: duration,
                  child: Text(duration),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDuration = value!;
                  _selectedClasses = (_packageOptions[value]!['classes'] as List<String>).first;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Classes Selection
            Text(
              'Number of Classes',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedClasses,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: ((_packageOptions[_selectedDuration]!['classes'] as List<String>)
                  .map<DropdownMenuItem<String>>((classes) {
                return DropdownMenuItem<String>(
                  value: classes,
                  child: Text('$classes classes'),
                );
              }).toList()),
              onChanged: (value) {
                setState(() {
                  _selectedClasses = value!;
                });
              },
            ),
            const SizedBox(height: 20),
            
            // Personal Information
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookNowButton() {
    final price = _packageOptions[_selectedDuration]!['prices'][_selectedClasses] ?? 0;
    
    return Card(
      color: const Color(0xFFE53935),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₹$price',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _processBooking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFE53935),
                ),
                child: const Text(
                  'Book Package Now',
                  style: TextStyle(
                    fontSize: 18,
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

  Future<void> _processBooking() async {
    if (_nameController.text.trim().isEmpty || 
        _phoneController.text.trim().isEmpty || 
        _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to book a package')),
        );
        return;
      }

      final price = _packageOptions[_selectedDuration]!['prices'][_selectedClasses] ?? 0;
      final endDate = _calculateEndDate(_selectedDuration);

      // Create package booking
      await FirebaseFirestore.instance.collection('package_bookings').add({
        'userId': user.uid,
        'packageType': widget.packageType,
        'duration': _selectedDuration,
        'classes': int.parse(_selectedClasses),
        'price': price,
        'studentName': _nameController.text.trim(),
        'studentPhone': _phoneController.text.trim(),
        'studentEmail': _emailController.text.trim(),
        'status': 'pending',
        'startDate': FieldValue.serverTimestamp(),
        'endDate': Timestamp.fromDate(endDate),
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Package booking submitted successfully! We will contact you soon.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit booking. Please check your connection and try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  DateTime _calculateEndDate(String duration) {
    final now = DateTime.now();
    switch (duration) {
      case '1 month':
        return DateTime(now.year, now.month + 1, now.day);
      case '3 months':
        return DateTime(now.year, now.month + 3, now.day);
      case '6 months':
        return DateTime(now.year, now.month + 6, now.day);
      case '1 year':
        return DateTime(now.year + 1, now.month, now.day);
      default:
        return now.add(const Duration(days: 30));
    }
  }
}
