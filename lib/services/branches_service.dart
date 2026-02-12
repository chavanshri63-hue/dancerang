import 'package:cloud_firestore/cloud_firestore.dart';

class Branch {
  final String id;
  final String name;
  final bool isActive;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  Branch({
    required this.id,
    required this.name,
    required this.isActive,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Branch.fromMap(Map<String, dynamic> data, String id) {
    return Branch(
      id: id,
      name: data['name'] ?? '',
      isActive: data['isActive'] ?? true,
      priority: data['priority'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isActive': isActive,
      'priority': priority,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class BranchesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const List<String> _defaultBranches = ['Balewadi', 'Wakad'];

  static Future<List<Branch>> getAllBranches() async {
    try {
      final snapshot = await _firestore
          .collection('branches')
          .where('isActive', isEqualTo: true)
          .orderBy('priority')
          .orderBy('name')
          .get();
      return snapshot.docs
          .map((doc) => Branch.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<String> addBranch(Branch branch) async {
    try {
      final docRef = await _firestore.collection('branches').add(branch.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add branch');
    }
  }

  static Future<void> initializeDefaultBranches() async {
    try {
      final snapshot = await _firestore.collection('branches').limit(1).get();
      if (snapshot.docs.isNotEmpty) return;
      final now = DateTime.now();
      for (final name in _defaultBranches) {
        final branch = Branch(
          id: '',
          name: name,
          isActive: true,
          priority: 0,
          createdAt: now,
          updatedAt: now,
        );
        await _firestore.collection('branches').add(branch.toMap());
      }
    } catch (e) {
      // Ignore initialization failures
    }
  }
}
