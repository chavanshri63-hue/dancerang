part of '../home_screen.dart';

// Classes Tab
class ClassesTab extends StatefulWidget {
  const ClassesTab({super.key});

  @override
  State<ClassesTab> createState() => _ClassesTabState();
}
class _ClassesTabState extends State<ClassesTab> {
  List<DanceStyle> _danceStyles = [];
  List<String> _categories = [];
  String _selectedCategory = 'all';
  List<String> _branches = [];
  String _selectedBranch = 'all';
  String _searchQuery = '';
  String _audienceFilter = 'all'; // 'all' | 'kids' | 'adults'
  bool _isAdmin = false;
  final EventController _eventController = EventController();
  StreamSubscription<ClassEvent>? _eventSubscription;
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;
  int _refreshKey = 0;

  String _normalizeKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadBranches();
    _checkAdminRole();
    // Listen to class events and refresh classes list
    _eventSubscription = _eventController.eventStream.listen((event) {
      if (mounted) {
        setState(() {
          _refreshKey++;
        });
      }
    });
    
    // Listen to payment success events for real-time enrollment updates
    _paymentRefreshSubscription = PaymentService.refreshStream.listen((event) {
      if (mounted && (event['type'] == 'payment_success' || event['type'] == 'enrollment_updated')) {
        if (event['paymentType'] == 'class_fee' || event['paymentType'] == 'class') {
          // Force refresh enrollment status when payment succeeds
          setState(() {
            _refreshKey++;
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(ClassesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-check admin role when widget updates
    _checkAdminRole();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _paymentRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      _danceStyles = await ClassStylesService.getAllStyles();
      _categories = _danceStyles.map((style) => style.name).toList();
      if (mounted) setState(() {});
    } catch (e) {
      _categories = ['Hip Hop', 'Bollywood', 'Contemporary', 'Jazz', 'Ballet', 'Salsa'];
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadBranches() async {
    try {
      final branches = await BranchesService.getAllBranches();
      final seen = <String>{};
      _branches = branches
          .map((branch) => branch.name.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => e[0].toUpperCase() + e.substring(1))
          .where((e) => seen.add(e.toLowerCase()))
          .toList();
      final classSnapshot = await FirebaseFirestore.instance.collection('classes').get();
      for (final doc in classSnapshot.docs) {
        final studio = (doc.data()['studio'] ?? '').toString().trim();
        if (studio.isNotEmpty && seen.add(studio.toLowerCase())) {
          _branches.add(studio);
        }
      }
      _branches.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (mounted) setState(() {});
    } catch (e) {
      _branches = [];
      if (mounted) setState(() {});
    }
  }

  Future<void> _checkAdminRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final role = userDoc.data()?['role'] as String?;
        if (mounted) setState(() {
          _isAdmin = role?.toLowerCase() == 'admin';
        });
      } catch (e) {
        // Error checking admin role
      }
    }
  }

  Stream<List<DanceClass>> _getClassesStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null && !DemoSession.isActive) {
      return Stream.value([]);
    }

    // Show all available classes to everyone (admin, faculty, students)
    // Students can see all classes to join them
    return FirebaseFirestore.instance
        .collection('classes')
        .where('isAvailable', isEqualTo: true)
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return DanceClass.fromMap(data);
      }).toList();
    });
  }

  List<DanceClass> _filterClasses(List<DanceClass> classes) {
    // Audience filter: prefer explicit ageGroup if present; fallback to keyword inference
    List<DanceClass> filtered = classes.where((c) {
      if (_audienceFilter == 'all') return true;
      bool? explicitIsKids;
      if (c.ageGroup != null) {
        explicitIsKids = c.ageGroup!.toLowerCase() == 'kids';
      }
      final name = c.name.toLowerCase();
      final desc = c.description.toLowerCase();
      final inferredKids = name.contains('kid') || name.contains('junior') || name.contains('child') ||
          desc.contains('kid') || desc.contains('junior') || desc.contains('child');
      final isKids = explicitIsKids ?? inferredKids;
      return _audienceFilter == 'kids' ? isKids : !isKids;
    }).toList();

    if (_selectedBranch != 'all') {
      filtered = filtered.where((classItem) {
        return _normalizeKey(classItem.studio) == _normalizeKey(_selectedBranch);
      }).toList();
    }

    if (_searchQuery.isEmpty) return filtered;

    return filtered.where((classItem) {
      return classItem.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             classItem.instructor.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _showLoginPrompt(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text(
          'Login Required',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Future<void> _bookClass(DanceClass danceClass) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginPrompt('To join a class, please login first');
      return;
    }

    if (danceClass.isFullyBooked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This class is fully booked'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Parse amount from formatted price string like "₹5" or "500"
      final String raw = danceClass.price.replaceAll('₹', '').replaceAll(',', '').trim();
      final int rupees = int.tryParse(raw) ?? 0;
      final int amountRupees = rupees; // Use rupees directly, not paise

      if (amountRupees <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid class price'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show payment option dialog
      final choice = await PaymentOptionDialog.show(context);
      if (choice == null) return; // User cancelled

      if (choice == PaymentChoice.cash) {
        // Request cash payment approval from admin
        final paymentId = PaymentService.generatePaymentId();
        final res = await PaymentService.requestCashPayment(
          paymentId: paymentId,
          amount: amountRupees,
          description: 'Class: ${danceClass.name}',
          paymentType: 'class_fee',
          itemId: danceClass.id,
          metadata: {
            'class_name': danceClass.name,
            'instructor': danceClass.instructor,
          },
        );
        if (res['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sent for admin confirmation (cash payment)'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cash request failed: ${res['error'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (choice == PaymentChoice.online) {
        final paymentId = PaymentService.generatePaymentId();
        final result = await PaymentService.processPayment(
          paymentId: paymentId,
          amount: amountRupees,
          description: 'Class: ${danceClass.name}',
          paymentType: 'class_fee',
          itemId: danceClass.id,
          metadata: {
            'class_name': danceClass.name,
            'scheduled_at': danceClass.dateTime?.toIso8601String() ?? 'TBD',
          },
        );

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
              content: Text('Payment failed to start: ${result['error'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _scheduleClassReminder(DanceClass danceClass) async {
    try {
      // Schedule notification 1 hour before class
      final classDateTime = danceClass.dateTime;
      if (classDateTime == null) return; // Skip if no dateTime
      final reminderTime = classDateTime.subtract(const Duration(hours: 1));
      
      // Notification scheduling disabled
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'Dance Classes',
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              _showSearchDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Audience Filter (centered segmented control)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Center(child: _buildAudienceSegmented()),
          ),
          // Branch Filter
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _branches.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildBranchChip('All', 'all', Icons.location_on);
                      }
                      final branch = _branches[index - 1];
                      return _buildBranchChip(branch, _normalizeKey(branch), Icons.location_on);
                    },
                  ),
                ),
              ],
            ),
          ),
          // Category filter removed as requested
          // Classes List
          Flexible(
            child: StreamBuilder<List<DanceClass>>(
              key: ValueKey(_refreshKey),
              stream: _getClassesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                }
                
                final classes = snapshot.data ?? [];
                final filteredClasses = _filterClasses(classes);
                
                if (filteredClasses.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 64,
                          color: Color(0xFF6B7280),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No Enrolled Classes',
                          style: TextStyle(
                            color: Color(0xFFF9FAFB),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Join a class to see it here',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredClasses.length,
                  itemBuilder: (context, index) {
                    final danceClass = filteredClasses[index];
                    return _buildClassCardWithEnrollmentStatus(danceClass);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseAuth.instance.currentUser != null
            ? FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .snapshots()
            : null,
        builder: (context, snapshot) {
          final userRole = snapshot.data?.data()?['role']?.toString().toLowerCase() ?? '';
          final isAdmin = userRole == 'admin';
          final isFaculty = userRole == 'faculty';
          
          if (isAdmin) {
            return FloatingActionButton(
              heroTag: 'classes_tab_add_class_admin',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminClassesManagementScreen(),
                ),
              );
            },
            backgroundColor: const Color(0xFFE53935),
            child: const Icon(Icons.add, color: Colors.white),
            );
          }
          
          if (isFaculty) {
            return FloatingActionButton(
              heroTag: 'classes_tab_add_class_faculty',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddEditClassScreen(),
                  ),
                );
              },
              backgroundColor: const Color(0xFFE53935),
              child: const Icon(Icons.add, color: Colors.white),
            );
          }
          
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildAudienceSegmented() {
    final options = ['all', 'kids', 'adults'];
    final labels = const ['All', 'Kids', 'Adults'];
    final isSelected = options.map((v) => _audienceFilter == v).toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(4),
      child: ToggleButtons(
        isSelected: isSelected,
        onPressed: (index) {
          setState(() {
            _audienceFilter = options[index];
          });
        },
        borderRadius: BorderRadius.circular(20),
        constraints: const BoxConstraints(minHeight: 36, minWidth: 90),
        fillColor: const Color(0xFFE53935),
        selectedColor: Colors.white,
        color: Colors.white70,
        selectedBorderColor: const Color(0xFFE53935),
        borderColor: Colors.white.withValues(alpha: 0.2),
        children: labels.map((t) => Text(t, style: const TextStyle(fontWeight: FontWeight.w600))).toList(),
      ),
    );
  }


  Widget _buildCategoryChip(String name, String id, IconData icon) {
    final isSelected = _selectedCategory == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(name),
        avatar: Icon(icon, size: 16),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = id;
          });
        },
        selectedColor: const Color(0xFFE53935),
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFFF9FAFB),
        ),
      ),
    );
  }

  Widget _buildBranchChip(String name, String id, IconData icon) {
    final isSelected = _selectedBranch == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(name),
        avatar: Icon(icon, size: 16),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedBranch = id;
          });
        },
        selectedColor: const Color(0xFFE53935),
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFFF9FAFB),
        ),
      ),
    );
  }

  void _showStyleManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StyleManagementModal(
        categories: _categories,
        onCategoriesUpdated: () {
          _loadCategories();
        },
      ),
    );
  }

  // New method for class card with enrollment status
  Widget _buildClassCardWithEnrollmentStatus(DanceClass danceClass) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return _buildClassCard(danceClass);
    }

    // Check enrollment in user subcollection (more reliable) and global collection (fallback)
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('enrollments')
          .doc(danceClass.id)
          .snapshots(),
      builder: (context, userEnrollmentSnapshot) {
        // Also check global collection as fallback
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
              .collection('enrollments')
          .where('userId', isEqualTo: currentUser.uid)
          .where('itemId', isEqualTo: danceClass.id)
          .where('status', isEqualTo: 'enrolled')
              .limit(1)
          .snapshots(),
          builder: (context, globalEnrollmentSnapshot) {
            final userEnrolled = userEnrollmentSnapshot.hasData && 
                userEnrollmentSnapshot.data!.exists &&
                (userEnrollmentSnapshot.data!.data()?['status'] == 'enrolled');
            final globalEnrolled = globalEnrollmentSnapshot.hasData && 
                globalEnrollmentSnapshot.data!.docs.isNotEmpty;
            final isEnrolled = userEnrolled || globalEnrolled;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Stack(
            children: [
              _buildClassCard(danceClass),
              if (isEnrolled)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Enrolled',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
          },
        );
      },
    );
  }
  Widget _buildClassCard(DanceClass danceClass) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFFE53935).withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Class Image
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF111318),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: (danceClass.imageUrl.isNotEmpty &&
                            (danceClass.imageUrl.startsWith('http://') || danceClass.imageUrl.startsWith('https://')))
                        ? Image.network(
                            danceClass.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.directions_run,
                                color: Color(0xFFE53935),
                                size: 40,
                              );
                            },
                          )
                        : const Icon(
                            Icons.directions_run,
                            color: Color(0xFFE53935),
                            size: 40,
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // Class Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        danceClass.name,
                        style: const TextStyle(
                          color: Color(0xFFF9FAFB),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'by ${danceClass.instructor}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              danceClass.category.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              danceClass.level,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      danceClass.price,
                      style: const TextStyle(
                        color: Color(0xFFE53935),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      danceClass.duration,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Description
            Text(
              danceClass.description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            // Schedule and Availability
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${danceClass.formattedDate} at ${danceClass.formattedTime}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 12),
            // Action Buttons
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showClassDetails(danceClass),
                  icon: const Icon(Icons.info_outline, size: 14),
                  label: const Text('Details', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE53935),
                    side: const BorderSide(color: Color(0xFFE53935)),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _EnrolButton(danceClassId: danceClass.id, danceClassName: danceClass.name, isFull: danceClass.isFullyBooked, onBook: () => _bookClass(danceClass)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showClassDetails(DanceClass danceClass) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClassDetailsModal(danceClass: danceClass),
    );
  }

  void _showNotificationSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text(
          'Notification Settings',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notifications, color: Color(0xFFE53935)),
              title: const Text(
                'Class Reminders',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Get notified before your classes',
                style: TextStyle(color: Colors.white70),
              ),
              trailing: Switch(
                value: true,
                onChanged: (value) {
                  // Handle notification toggle
                },
                thumbColor: const WidgetStatePropertyAll(Color(0xFFE53935)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.schedule, color: Color(0xFFE53935)),
              title: const Text(
                'Schedule Notifications',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                '1 hour and 15 minutes before class',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notification settings saved!'),
                    backgroundColor: Color(0xFFE53935),
                  ),
                );
              },
            ),
            const Divider(color: Color(0xFF262626)),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Color(0xFF4F46E5)),
              title: const Text(
                'Test Notification',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Send a test notification to verify setup',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await LiveNotificationService.sendTestNotification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Test notification sent! Check your notifications.'),
                      backgroundColor: Color(0xFF10B981),
                      duration: Duration(seconds: 3),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: const Color(0xFFE53935),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text(
          'Search Classes',
          style: TextStyle(color: Color(0xFFF9FAFB)),
        ),
        content: TextField(
          style: const TextStyle(color: Color(0xFFF9FAFB)),
          decoration: const InputDecoration(
            hintText: 'Search by name or instructor...',
            hintStyle: TextStyle(color: Colors.white70),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
}

// Class Details Modal
class _ClassDetailsModal extends StatefulWidget {
  final DanceClass danceClass;

  const _ClassDetailsModal({required this.danceClass});

  @override
  State<_ClassDetailsModal> createState() => _ClassDetailsModalState();
}
class _ClassDetailsModalState extends State<_ClassDetailsModal> {
  @override
  Widget build(BuildContext context) {
    final danceClass = widget.danceClass;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B1B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Class Details',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Class Image
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF111111),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        danceClass.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.directions_run,
                              color: Color(0xFFE53935),
                              size: 60,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Class Title
                  Text(
                    danceClass.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Instructor
                  Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFFE53935), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Instructor: ${danceClass.instructor}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Class Info Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.category,
                          title: 'Category',
                          value: danceClass.category,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.trending_up,
                          title: 'Level',
                          value: danceClass.level,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.schedule,
                          title: 'Duration',
                          value: danceClass.duration,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.currency_rupee,
                          title: 'Price',
                          value: danceClass.price,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Schedule
                  _buildSectionTitle('Schedule'),
                  _buildClassScheduleCard(danceClass),
                  const SizedBox(height: 20),
                  
                  // Description
                  _buildSectionTitle('Description'),
                  Text(
                    danceClass.description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Availability removed as requested
                  const SizedBox(height: 0),
                  const SizedBox(height: 20),
                  
                  // Admin Students List (Admin/Faculty only)
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseAuth.instance.currentUser != null 
                        ? FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).snapshots()
                        : const Stream.empty(),
                    builder: (context, userSnapshot) {
                      final userRole = userSnapshot.data?.data()?['role']?.toString().toLowerCase() ?? '';
                      final isAdminOrFaculty = userRole == 'admin' || userRole == 'faculty';
                      
                      if (!isAdminOrFaculty) {
                        return const SizedBox.shrink();
                      }
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Enrolled Students'),
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: StreamBuilder<List<Map<String, dynamic>>>(
                              stream: AdminStudentsService.getClassEnrolledStudents(danceClass.id),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(color: Color(0xFFE53935)),
                                        SizedBox(height: 8),
                                        Text(
                                          'Loading enrolled students...',
                                          style: TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.red, size: 32),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Error loading students',
                                          style: const TextStyle(color: Colors.red, fontSize: 14),
                                        ),
                                        Text(
                                          '${snapshot.error}',
                                          style: const TextStyle(color: Colors.red, fontSize: 10),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                
                                final students = snapshot.data ?? [];
                                
                                if (students.isEmpty) {
                                  return const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.school_outlined, color: Colors.white54, size: 48),
                                        SizedBox(height: 12),
                                        Text(
                                          'No students enrolled yet',
                                          style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Students will appear here once they enroll',
                                          style: TextStyle(color: Colors.white54, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                
                                return ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: students.length,
                                  itemBuilder: (context, index) {
                                    final student = students[index];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: const Color(0xFFE53935),
                                            child: Text(
                                              student['name'][0].toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
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
                                                  student['name'],
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  student['email'],
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFE53935).withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: const Color(0xFFE53935).withOpacity(0.3)),
                                                      ),
                                                      child: Text(
                                                        '${student['completedSessions']}/${student['totalSessions']} sessions',
                                                        style: const TextStyle(
                                                          color: Color(0xFFE53935),
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: student['paymentStatus'] == 'paid' 
                                                            ? Colors.green.withOpacity(0.2)
                                                            : Colors.orange.withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(
                                                          color: student['paymentStatus'] == 'paid' 
                                                              ? Colors.green.withOpacity(0.3)
                                                              : Colors.orange.withOpacity(0.3)
                                                        ),
                                                      ),
                                                      child: Text(
                                                        student['paymentStatus'] == 'paid' ? 'Paid' : 'Pending',
                                                        style: TextStyle(
                                                          color: student['paymentStatus'] == 'paid' 
                                                              ? Colors.green
                                                              : Colors.orange,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Removed QR Scanner button from class details for admin/faculty
                          const SizedBox(height: 0),
                        ],
                      );
                    },
                  ),
                  
                  // Action Buttons - Check enrollment status
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseAuth.instance.currentUser != null
                        ? FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .collection('enrollments')
                            .doc(danceClass.id)
                            .snapshots()
                        : null,
                    builder: (context, userEnrollmentSnap) {
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseAuth.instance.currentUser != null
                            ? FirebaseFirestore.instance
                                .collection('enrollments')
                                .where('userId', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                                .where('itemId', isEqualTo: danceClass.id)
                                .where('status', whereIn: ['enrolled', 'completed'])
                                .limit(1)
                                .snapshots()
                            : null,
                        builder: (context, globalEnrollmentSnap) {
                          final userStatus = (userEnrollmentSnap.hasData && userEnrollmentSnap.data!.exists)
                              ? (userEnrollmentSnap.data!.data()?['status'] as String?)
                              : null;
                          final userEnrolled = userStatus == 'enrolled' || userStatus == 'completed';
                          final globalEnrolled = globalEnrollmentSnap.hasData &&
                              globalEnrollmentSnap.data!.docs.isNotEmpty;
                          final isEnrolled = userEnrolled || globalEnrolled;
                          final isCompleted = userStatus == 'completed' || 
                              (globalEnrollmentSnap.hasData && 
                               globalEnrollmentSnap.data!.docs.any((doc) => doc.data()['status'] == 'completed'));

                          return Row(
                            children: [
                              Expanded(
                                child: isEnrolled
                                    ? ElevatedButton.icon(
                                        onPressed: null,
                                        icon: Icon(isCompleted ? Icons.check_circle_outline : Icons.check_circle, size: 18),
                                        label: Text(isCompleted ? 'Completed' : 'Enrolled'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isCompleted ? Colors.orange : Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      )
                                    : ElevatedButton.icon(
                                        onPressed: danceClass.isFullyBooked
                                            ? null
                                            : () => _joinClassNow(context, danceClass),
                                        icon: const Icon(Icons.login, size: 18),
                                        label: Text(danceClass.isFullyBooked ? 'Full' : 'Join Now'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFE53935),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassScheduleCard(DanceClass danceClass) {
    // Get days from class - check multiple sources
    List<String> days = [];
    if (danceClass.days != null && danceClass.days!.isNotEmpty) {
      days = danceClass.days!;
    } else if (danceClass.schedule['days'] != null) {
      days = List<String>.from(danceClass.schedule['days']);
    }
    
    final start = danceClass.startTime ?? danceClass.schedule['startTime']?.toString();
    final end = danceClass.endTime ?? danceClass.schedule['endTime']?.toString();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Schedule', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  days.isNotEmpty ? days.join(', ') : 'Days not set',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                (start != null && end != null) ? '$start - $end' : danceClass.formattedTime,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFE53935), size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showClassPackages(BuildContext context) {
    Navigator.pop(context); // Close details modal first
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClassPackagesModal(danceClass: widget.danceClass),
    );
  }

  Future<void> _joinClassNow(BuildContext context, DanceClass danceClass) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to join this class')),
      );
      return;
    }

    if (danceClass.isFullyBooked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This class is fully booked'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Parse amount from formatted price string like "₹500"
      final String raw = danceClass.price.replaceAll('₹', '').replaceAll(',', '').trim();
      final int amountRupees = int.tryParse(raw) ?? 0;
      if (amountRupees <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid class price'), backgroundColor: Colors.red),
        );
        return;
      }

      // Mirror main card flow: ask payment option
      final choice = await PaymentOptionDialog.show(context);
      if (choice == null) return;

      if (choice == PaymentChoice.cash) {
        final paymentId = PaymentService.generatePaymentId();
        final res = await PaymentService.requestCashPayment(
          paymentId: paymentId,
          amount: amountRupees,
          description: 'Class: ${danceClass.name}',
          paymentType: 'class_fee',
          itemId: danceClass.id,
          metadata: {
            'class_name': danceClass.name,
            'instructor': danceClass.instructor,
          },
        );
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sent for admin confirmation (cash payment)'), backgroundColor: Colors.green),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cash request failed: ${res['error'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (choice == PaymentChoice.online) {
        final paymentId = PaymentService.generatePaymentId();
        final result = await PaymentService.processPayment(
          paymentId: paymentId,
          amount: amountRupees,
          description: 'Class: ${danceClass.name}',
          paymentType: 'class_fee',
          itemId: danceClass.id,
          metadata: {
            'class_name': danceClass.name,
            'scheduled_at': danceClass.dateTime?.toIso8601String() ?? 'TBD',
          },
        );
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Redirecting to payment...'), backgroundColor: Colors.orange),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment failed to start: ${result['error'] ?? 'Unknown error'}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting payment: $e'), backgroundColor: const Color(0xFFE53935)),
      );
    }
  }
}

// Class Packages Modal
class _ClassPackagesModal extends StatelessWidget {
  final DanceClass danceClass;

  const _ClassPackagesModal({required this.danceClass});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF1B1B1B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.card_giftcard, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Class Packages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),
          // Join Now (replace packages)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildClassScheduleCard(danceClass),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _joinClassNow(context, danceClass),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Join Now', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard({
    required String title,
    required String price,
    String? originalPrice,
    required String description,
    required List<String> features,
    required bool isRecommended,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isRecommended 
            ? const Color(0xFFE53935).withOpacity(0.1)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRecommended 
              ? const Color(0xFFE53935)
              : Colors.white.withOpacity(0.1),
          width: isRecommended ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'RECOMMENDED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                price,
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (originalPrice != null) ...[
                const SizedBox(width: 8),
                Text(
                  originalPrice,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ...features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFFE53935),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  feature,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: isRecommended 
                    ? const Color(0xFFE53935)
                    : Colors.white.withOpacity(0.1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                isRecommended ? 'Choose Package' : 'Select Package',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassScheduleCard(DanceClass danceClass) {
    // Get days from class - check multiple sources
    List<String> days = [];
    if (danceClass.days != null && danceClass.days!.isNotEmpty) {
      days = danceClass.days!;
    } else if (danceClass.schedule['days'] != null) {
      days = List<String>.from(danceClass.schedule['days']);
    }
    
    final start = danceClass.startTime ?? danceClass.schedule['startTime']?.toString();
    final end = danceClass.endTime ?? danceClass.schedule['endTime']?.toString();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Schedule', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  days.isNotEmpty ? days.join(', ') : 'Days not set',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                (start != null && end != null) ? '$start - $end' : danceClass.formattedTime,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _joinClassNow(BuildContext context, DanceClass danceClass) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to join this class')),
      );
      return;
    }

    try {
      // Compute sessions per month from schedule: days per week * 4
      final List<String> days = danceClass.days ?? List<String>.from(danceClass.schedule['days'] ?? []);
      final int sessionsPerMonth = (days.isNotEmpty ? days.length : 2) * 4;

      // Parse numeric price from class.price (e.g., '₹3500')
      int priceInt = 0;
      try {
        final digits = RegExp(r'\d+').allMatches(danceClass.price).map((m) => m.group(0)).join();
        priceInt = int.tryParse(digits) ?? 0;
      } catch (_) {}

      final ClassPackage monthlyPackage = ClassPackage(
        id: 'monthly_auto_${danceClass.id}',
        name: 'Monthly ${sessionsPerMonth} Sessions',
        description: 'Auto-derived from class schedule',
        price: priceInt.toDouble(),
        totalSessions: sessionsPerMonth,
        validityDays: 30,
        features: ['${sessionsPerMonth} sessions', 'Valid for 1 month'],
        category: 'monthly',
        isRecommended: true,
      );

      // Use shared enrollment flow
      final result = await ClassEnrollmentService.enrollInClass(
        classId: danceClass.id,
        className: danceClass.name,
        package: monthlyPackage,
        userId: user.uid,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enrollment created. Complete payment to confirm.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Failed to start enrollment'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to join: $e'), backgroundColor: const Color(0xFFE53935)),
      );
    }
  }

  void _bookSingleClass(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SingleClassBookingScreen(),
      ),
    );
  }

  void _bookPackage(BuildContext context, String packageType) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PackageBookingScreen(packageType: packageType),
      ),
    );
  }
}
