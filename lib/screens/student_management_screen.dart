import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/glassmorphism_app_bar.dart';
import 'add_student_screen.dart';
import 'student_detail_screen.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
  }


  List<StudentData> _filterStudents(List<StudentData> students) {
    return students.where((student) {
      final matchesSearch = student.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          student.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          student.id.toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesFilter = _selectedFilter == 'all' ||
                          (_selectedFilter == 'active' && student.status == StudentStatus.active) ||
                          (_selectedFilter == 'inactive' && student.status == StudentStatus.inactive);
      
      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'Student Management',
        onLeadingPressed: () => Navigator.pop(context),
        actions: [
          IconButton(
            onPressed: _addStudent,
            icon: const Icon(Icons.add, color: Colors.white70),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'Student')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white70,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading students: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final students = snapshot.data?.docs.map((doc) {
                  final data = doc.data();
                  return StudentData(
                    id: doc.id,
                    name: data['name'] ?? 'Unknown Student',
                    email: data['email'] ?? '',
                    phone: data['phone'] ?? '',
                    joinDate: data['createdAt']?.toDate() ?? DateTime.now(),
                    level: data['level'] ?? 'Beginner',
                    classesEnrolled: 0, // computed on demand in details
                    attendancePercentage: 0,
                    status: data['isActive'] == true ? StudentStatus.active : StudentStatus.inactive,
                  );
                }).toList() ?? [];

                final filteredStudents = _filterStudents(students);

                if (filteredStudents.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildStudentsList(filteredStudents);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            style: const TextStyle(color: Color(0xFFF9FAFB)),
            decoration: InputDecoration(
              hintText: 'Search students...',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFE53935)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.clear, color: Colors.white54),
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: const Color(0xFFE53935).withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: const Color(0xFFE53935).withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.white70,
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Active', 'active'),
                const SizedBox(width: 8),
                _buildFilterChip('Inactive', 'inactive'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: const Color(0xFFE53935),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFFF9FAFB),
      ),
    );
  }

  Widget _buildStudentsList(List<StudentData> students) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return _buildStudentCard(student);
      },
    );
  }

  Widget _buildStudentCard(StudentData student) {
    return Card(
      elevation: 4,
      shadowColor: const Color(0xFFE53935).withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFFE53935).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFE53935).withValues(alpha: 0.2),
                        const Color(0xFFD32F2F).withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: const Color(0xFFE53935).withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white70,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: const TextStyle(
                          color: Color(0xFFF9FAFB),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        student.email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${student.id}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: student.status == StudentStatus.active
                        ? const Color(0xFF10B981).withValues(alpha: 0.2)
                        : const Color(0xFFEF4444).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: student.status == StudentStatus.active
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    student.status == StudentStatus.active ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: student.status == StudentStatus.active
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(Icons.phone, student.phone),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(Icons.trending_up, '${student.level}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('class_enrollments')
                        .where('userId', isEqualTo: student.id)
                        .where('status', isEqualTo: 'active')
                        .snapshots(),
                    builder: (context, snap) {
                      final count = snap.data?.size ?? 0;
                      return _buildInfoChip(Icons.school, '$count Classes');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('attendance')
                        .where('userId', isEqualTo: student.id)
                        .snapshots(),
                    builder: (context, snap) {
                      final present = snap.data?.size ?? 0;
                      final percent = present > 0 ? 100 : 0;
                      return _buildInfoChip(Icons.percent, '$percent%');
                    },
                  ),
                ),
              ],
            ),
            // Batch chips removed from card to keep list light
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _viewStudentDetails(student),
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0,2)),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _editStudent(student),
                      icon: const Icon(Icons.edit, size: 16, color: Colors.white70),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFE53935).withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0,2)),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _deleteStudent(student),
                      icon: const Icon(Icons.delete, size: 16, color: Color(0xFFE53935)),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Color(0xFFE53935),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE53935).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFE53935), size: 12),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFF9FAFB),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Students Found',
            style: TextStyle(
              color: Color(0xFFF9FAFB),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No students match your search criteria',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _addStudent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddStudentScreen(),
      ),
    );
  }

  void _viewStudentDetails(StudentData student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentDetailScreen(
          studentId: student.id,
          studentName: student.name,
        ),
      ),
    );
  }

  void _editStudent(StudentData student) {
    // Convert to AddStudentScreen's AddStudentData format
    final addStudentData = AddStudentData(
      id: student.id,
      name: student.name,
      email: student.email,
      phone: student.phone,
      level: student.level,
      // Prefer first batch title if available; fallback to level
      danceClass: (student.batchTitles.isNotEmpty ? student.batchTitles.first : student.level),
      joiningDate: student.joinDate,
      status: student.status == StudentStatus.active ? 'active' : 'inactive',
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddStudentScreen(
          studentData: addStudentData,
          isEditMode: true,
        ),
      ),
    );
  }

  void _deleteStudent(StudentData student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Student',
          style: TextStyle(color: Color(0xFFF9FAFB)),
        ),
        content: Text(
          'Are you sure you want to delete ${student.name}? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDeleteStudent(student);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteStudent(StudentData student) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFE53935)),
        ),
      );

      // Debug: Print student ID being deleted

      // Delete student from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(student.id)
          .delete();


      // Also delete any related enrolments
      final enrolmentsSnapshot = await FirebaseFirestore.instance
          .collection('enrollments')
          .where('userId', isEqualTo: student.id)
          .get();

      // Delete all enrolments for this student
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in enrolmentsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();


      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Student deleted successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }

      // Student list will auto-refresh via StreamBuilder

    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to delete student: ${e.toString()}')),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _performDeleteStudent(student),
            ),
          ),
        );
      }
    }
  }

  /// Resolve a student's latest enrolled batch/class title with graceful fallbacks
  Future<String> _fetchLatestBatchTitle(String userId) async {
    try {
      // Preferred: per-user enrolments mirror with title
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('enrollments')
          .where('status', isEqualTo: 'enrolled');
      try {
        q = q.orderBy('ts', descending: true);
      } catch (_) {}
      final snap = await q.limit(1).get();
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        final title = (data['title'] ?? '').toString().trim();
        if (title.isNotEmpty) return title;
        // Fallback to resolve from item type/ID if title missing
        final itemId = (data['itemId'] ?? '').toString();
        final itemType = (data['itemType'] ?? '').toString();
        if (itemId.isNotEmpty) {
          final resolved = await _resolveItemTitle(itemId, itemType);
          if (resolved.isNotEmpty) return resolved;
        }
      }
    } catch (_) {}

    // Global mirror fallback
    try {
      Query<Map<String, dynamic>> q2 = FirebaseFirestore.instance
          .collection('enrollments')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'enrolled');
      try {
        q2 = q2.orderBy('ts', descending: true);
      } catch (_) {}
      final snap2 = await q2.limit(1).get();
      if (snap2.docs.isNotEmpty) {
        final data = snap2.docs.first.data();
        final title = (data['title'] ?? '').toString().trim();
        if (title.isNotEmpty) return title;
        final itemId = (data['itemId'] ?? '').toString();
        final itemType = (data['itemType'] ?? '').toString();
        if (itemId.isNotEmpty) {
          final resolved = await _resolveItemTitle(itemId, itemType);
          if (resolved.isNotEmpty) return resolved;
        }
      }
    } catch (_) {}

    // Legacy collections fallback
    final legacy = await _resolveFromLegacy(userId);
    if (legacy.isNotEmpty) return legacy;

    return '';
  }

  Future<String> _resolveItemTitle(String itemId, String itemType) async {
    try {
      final col = itemType == 'workshop' ? 'workshops' : 'classes';
      final doc = await FirebaseFirestore.instance.collection(col).doc(itemId).get();
      final data = doc.data();
      if (data != null) {
        final name = (data['name'] ?? data['title'] ?? '').toString().trim();
        return name;
      }
    } catch (_) {}
    return '';
  }

  Future<String> _resolveFromLegacy(String userId) async {
    try {
      // Check class_enrollments (legacy)
      final cls = await FirebaseFirestore.instance
          .collection('class_enrollments')
          .where('user_id', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      if (cls.docs.isNotEmpty) {
        final data = cls.docs.first.data();
        final classId = (data['class_id'] ?? '').toString();
        if (classId.isNotEmpty) {
          final title = await _resolveItemTitle(classId, 'class_fee');
          if (title.isNotEmpty) return title;
        }
      }
      // Check workshop_enrollments (legacy)
      final w = await FirebaseFirestore.instance
          .collection('workshop_enrollments')
          .where('user_id', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      if (w.docs.isNotEmpty) {
        final data = w.docs.first.data();
        final workshopId = (data['workshop_id'] ?? '').toString();
        if (workshopId.isNotEmpty) {
          final title = await _resolveItemTitle(workshopId, 'workshop');
          if (title.isNotEmpty) return title;
        }
      }
    } catch (_) {}
    return '';
  }
}

class StudentData {
  final String id;
  final String name;
  final String email;
  final String phone;
  final DateTime joinDate;
  final String level;
  final int classesEnrolled;
  final int attendancePercentage;
  final StudentStatus status;
  final List<String> batchTitles;

  StudentData({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.joinDate,
    required this.level,
    required this.classesEnrolled,
    required this.attendancePercentage,
    required this.status,
    this.batchTitles = const [],
  });
}

enum StudentStatus {
  active,
  inactive,
}
