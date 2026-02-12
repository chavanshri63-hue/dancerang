import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_faculty_screen.dart';

class FacultyManagementScreen extends StatefulWidget {
  const FacultyManagementScreen({super.key});

  @override
  State<FacultyManagementScreen> createState() => _FacultyManagementScreenState();
}

class _FacultyManagementScreenState extends State<FacultyManagementScreen> {
  Future<List<String>> _fetchFacultyClasses(String facultyId, String facultyName) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('classes').get();
      final classes = <String>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final instructorId = (data['instructorId'] ?? '').toString();
        final instructor = (data['instructor'] ?? '').toString();
        final instructorName = (data['instructorName'] ?? '').toString();
        final className = (data['name'] ?? '').toString();
        if (className.isEmpty) continue;
        final matches = instructorId == facultyId ||
            instructor == facultyId ||
            instructor == facultyName ||
            instructorName == facultyName;
        if (matches) classes.add(className);
      }
      return classes;
    } catch (e) {
      return [];
    }
  }

  void _showFacultyDetails(Map<String, dynamic> data, String docId) {
    final name = (data['name'] ?? '').toString();
    final phone = (data['phone'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final address = (data['address'] ?? '').toString();
    final specialization = (data['specialization'] ?? '').toString();
    final qualification = (data['qualification'] ?? '').toString();
    final experience = (data['experience_years'] ?? '').toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Faculty Details', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Name', name),
                _infoRow('Phone', phone),
                _infoRow('Email', email),
                _infoRow('Address', address),
                _infoRow('Specialization', specialization),
                _infoRow('Qualification', qualification),
                _infoRow('Experience (Years)', experience),
                const SizedBox(height: 12),
                const Text('Classes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                FutureBuilder<List<String>>(
                  future: _fetchFacultyClasses(docId, name),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(color: Colors.white70),
                      );
                    }
                    final classes = snapshot.data ?? [];
                    if (classes.isEmpty) {
                      return const Text('No classes assigned', style: TextStyle(color: Colors.white70));
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: classes.map((c) => Text('• $c', style: const TextStyle(color: Colors.white70))).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFaculty(String docId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Delete Faculty', style: TextStyle(color: Colors.white)),
        content: Text('Delete $name? This cannot be undone.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseFirestore.instance.collection('users').doc(docId).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted $name'), backgroundColor: Colors.green),
    );
  }

  Widget _infoRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$label: $value', style: const TextStyle(color: Colors.white70)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('Faculty Management'),
        backgroundColor: const Color(0xFF1F2937),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddFacultyScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white70));
          }
          final docs = snapshot.data?.docs ?? [];
          final facultyDocs = docs.where((d) {
            final role = (d.data()['role'] ?? '').toString().toLowerCase();
            return role == 'faculty';
          }).toList();
          if (facultyDocs.isEmpty) {
            return const Center(
              child: Text('No faculty found', style: TextStyle(color: Colors.white70)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: facultyDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final doc = facultyDocs[i];
              final data = doc.data();
              final name = (data['name'] ?? 'Unknown').toString();
              final phone = (data['phone'] ?? '').toString();
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
                          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          if (phone.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(phone, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showFacultyDetails(data, doc.id),
                      child: const Text('Details'),
                    ),
                    TextButton(
                      onPressed: () => _deleteFaculty(doc.id, name),
                      child: const Text('Delete', style: TextStyle(color: Color(0xFFE53935))),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
