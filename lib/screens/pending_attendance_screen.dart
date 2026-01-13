import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/glassmorphism_app_bar.dart';

class PendingAttendanceScreen extends StatefulWidget {
  const PendingAttendanceScreen({super.key});

  @override
  State<PendingAttendanceScreen> createState() => _PendingAttendanceScreenState();
}

class _PendingAttendanceScreenState extends State<PendingAttendanceScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingClasses = [];

  @override
  void initState() {
    super.initState();
    _loadPendingAttendance();
  }

  Future<void> _loadPendingAttendance() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get user's enrolled classes
      final enrolledSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('enrollments')
          .get();

      final enrolledClassIds = enrolledSnapshot.docs.map((doc) => doc.id).toList();

      if (enrolledClassIds.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get class details for enrolled classes
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where(FieldPath.documentId, whereIn: enrolledClassIds)
          .get();

      final now = DateTime.now();
      final pendingClasses = <Map<String, dynamic>>[];

      for (var classDoc in classesSnapshot.docs) {
        final classData = classDoc.data();
        final classDateTime = (classData['dateTime'] as Timestamp).toDate();
        
        // Check if class is today and hasn't started yet
        if (classDateTime.isAfter(now) && 
            classDateTime.day == now.day &&
            classDateTime.month == now.month &&
            classDateTime.year == now.year) {
          
          // Check if attendance is already marked
          final attendanceSnapshot = await FirebaseFirestore.instance
              .collection('attendance')
              .where('userId', isEqualTo: user.uid)
              .where('classId', isEqualTo: classDoc.id)
              .where('date', isEqualTo: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}')
              .get();

          if (attendanceSnapshot.docs.isEmpty) {
            pendingClasses.add({
              'id': classDoc.id,
              'name': classData['name'] ?? 'Unknown Class',
              'instructor': classData['instructor'] ?? 'Unknown Instructor',
              'time': '${classDateTime.hour.toString().padLeft(2, '0')}:${classDateTime.minute.toString().padLeft(2, '0')}',
              'studio': classData['studio'] ?? 'Unknown Studio',
              'category': classData['category'] ?? 'Unknown Category',
              'level': classData['level'] ?? 'Unknown Level',
            });
          }
        }
      }

      setState(() {
        _pendingClasses = pendingClasses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAttendance(String classId, String className) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final dateString = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await FirebaseFirestore.instance.collection('attendance').add({
        'userId': user.uid,
        'classId': classId,
        'date': dateString,
        'status': 'present',
        'markedAt': FieldValue.serverTimestamp(),
        'markedBy': 'self',
      });

      // Remove from pending list
      setState(() {
        _pendingClasses.removeWhere((classData) => classData['id'] == classId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance marked for $className'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking attendance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'Pending Attendance',
        onLeadingPressed: () => Navigator.pop(context),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingClasses.isEmpty
              ? _buildEmptyState()
              : _buildPendingClassesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.green.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'No Pending Attendance',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All your classes for today have been marked',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingClassesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingClasses.length,
      itemBuilder: (context, index) {
        final classData = _pendingClasses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: const Color(0xFF1B1B1B),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        classData['name'],
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.5)),
                      ),
                      child: Text(
                        'Pending',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      classData['instructor'],
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.access_time, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      classData['time'],
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      classData['studio'],
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.category, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      '${classData['category']} - ${classData['level']}',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _markAttendance(
                      classData['id'],
                      classData['name'],
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Mark Attendance'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}