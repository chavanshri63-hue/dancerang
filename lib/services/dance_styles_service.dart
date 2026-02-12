import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DanceStyle {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String color;
  final bool isActive;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  DanceStyle({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DanceStyle.fromMap(Map<String, dynamic> data, String id) {
    return DanceStyle(
      id: id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      icon: data['icon'] ?? 'directions_run',
      color: data['color'] ?? '#E53935',
      isActive: data['isActive'] ?? true,
      priority: data['priority'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'isActive': isActive,
      'priority': priority,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class DanceStylesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all active dance styles
  static Future<List<DanceStyle>> getAllStyles() async {
    try {
      final snapshot = await _firestore
          .collection('danceStyles')
          .where('isActive', isEqualTo: true)
          .orderBy('priority')
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => DanceStyle.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      // Return default styles if Firestore fails
      return defaultStyles();
    }
  }

  /// Get all dance styles (including inactive) for admin
  static Future<List<DanceStyle>> getAllStylesForAdmin() async {
    try {
      final snapshot = await _firestore
          .collection('danceStyles')
          .orderBy('priority')
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => DanceStyle.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      return defaultStyles();
    }
  }

  /// Add a new dance style
  static Future<String> addStyle(DanceStyle style) async {
    try {
      final docRef = await _firestore.collection('danceStyles').add(style.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add dance style');
    }
  }

  /// Update an existing dance style
  static Future<void> updateStyle(String id, DanceStyle style) async {
    try {
      await _firestore.collection('danceStyles').doc(id).update(style.toMap());
    } catch (e) {
      throw Exception('Failed to update dance style');
    }
  }

  /// Delete a dance style
  static Future<void> deleteStyle(String id) async {
    try {
      await _firestore.collection('danceStyles').doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete dance style');
    }
  }

  /// Toggle style active status
  static Future<void> toggleStyleStatus(String id, bool isActive) async {
    try {
      await _firestore.collection('danceStyles').doc(id).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to toggle style status');
    }
  }

  /// Initialize default styles if none exist
  static Future<void> initializeDefaultStyles() async {
    try {
      final snapshot = await _firestore.collection('danceStyles').limit(1).get();
      
      if (snapshot.docs.isEmpty) {
        final defaults = defaultStyles();
        
        for (int i = 0; i < defaults.length; i++) {
          final style = defaults[i];
          await _firestore.collection('danceStyles').add({
            ...style.toMap(),
            'priority': i,
          });
        }
        
      } else {
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get default styles as fallback
  static List<DanceStyle> defaultStyles() {
    final now = DateTime.now();
    return [
      DanceStyle(
        id: 'bollywood',
        name: 'Bollywood',
        description: 'Traditional Indian dance with modern Bollywood flair',
        icon: 'directions_run',
        color: '#E53935',
        isActive: true,
        priority: 0,
        createdAt: now,
        updatedAt: now,
      ),
      DanceStyle(
        id: 'hiphop',
        name: 'Hip-Hop',
        description: 'Urban street dance with rhythm and attitude',
        icon: 'headphones',
        color: '#4F46E5',
        isActive: true,
        priority: 1,
        createdAt: now,
        updatedAt: now,
      ),
      DanceStyle(
        id: 'contemporary',
        name: 'Contemporary',
        description: 'Modern expressive dance with fluid movements',
        icon: 'auto_awesome',
        color: '#10B981',
        isActive: true,
        priority: 2,
        createdAt: now,
        updatedAt: now,
      ),
      DanceStyle(
        id: 'classical',
        name: 'Classical',
        description: 'Traditional classical dance forms',
        icon: 'palette',
        color: '#F59E0B',
        isActive: true,
        priority: 3,
        createdAt: now,
        updatedAt: now,
      ),
      DanceStyle(
        id: 'fusion',
        name: 'Fusion',
        description: 'Blend of different dance styles',
        icon: 'auto_awesome',
        color: '#8B5CF6',
        isActive: true,
        priority: 4,
        createdAt: now,
        updatedAt: now,
      ),
      DanceStyle(
        id: 'beginner',
        name: 'Beginner',
        description: 'Perfect for those starting their dance journey',
        icon: 'school',
        color: '#06B6D4',
        isActive: true,
        priority: 5,
        createdAt: now,
        updatedAt: now,
      ),
      DanceStyle(
        id: 'advanced',
        name: 'Advanced',
        description: 'For experienced dancers looking for challenges',
        icon: 'trending_up',
        color: '#EF4444',
        isActive: true,
        priority: 6,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  /// Get icon data from string
  static IconData getIconData(String iconName) {
    switch (iconName) {
      case 'music_note':
        return Icons.directions_run;
      case 'headphones':
        return Icons.headphones;
      case 'accessibility_new':
        return Icons.accessibility_new;
      case 'star':
        return Icons.star;
      case 'favorite':
        return Icons.favorite;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'whatshot':
        return Icons.whatshot;
      case 'celebration':
        return Icons.celebration;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'palette':
        return Icons.palette;
      case 'school':
        return Icons.school;
      case 'trending_up':
        return Icons.trending_up;
      default:
        return Icons.directions_run;
    }
  }

  /// Get color from hex string
  static Color getColorFromHex(String hexString) {
    try {
      return Color(int.parse(hexString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFFE53935); // Default red color
    }
  }
}

class ClassStylesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'classStyles';

  /// Get all active class styles
  static Future<List<DanceStyle>> getAllStyles() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('priority')
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => DanceStyle.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      return DanceStylesService.defaultStyles();
    }
  }

  /// Get all class styles (including inactive) for admin
  static Future<List<DanceStyle>> getAllStylesForAdmin() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('priority')
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => DanceStyle.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      return DanceStylesService.defaultStyles();
    }
  }

  /// Add a new class style
  static Future<String> addStyle(DanceStyle style) async {
    try {
      final docRef = await _firestore.collection(_collection).add(style.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add class style');
    }
  }

  /// Update an existing class style
  static Future<void> updateStyle(String id, DanceStyle style) async {
    try {
      await _firestore.collection(_collection).doc(id).update(style.toMap());
    } catch (e) {
      throw Exception('Failed to update class style');
    }
  }

  /// Delete a class style
  static Future<void> deleteStyle(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete class style');
    }
  }

  /// Toggle class style active status
  static Future<void> toggleStyleStatus(String id, bool isActive) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to toggle class style status');
    }
  }

  /// Initialize class styles (seed from legacy or defaults)
  static Future<void> initializeDefaultStyles() async {
    try {
      final snapshot = await _firestore.collection(_collection).limit(1).get();
      if (snapshot.docs.isNotEmpty) return;

      final legacySnapshot = await _firestore.collection('danceStyles').get();
      if (legacySnapshot.docs.isNotEmpty) {
        for (final doc in legacySnapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data.putIfAbsent('createdAt', () => FieldValue.serverTimestamp());
          data['updatedAt'] = FieldValue.serverTimestamp();
          await _firestore.collection(_collection).add(data);
        }
        return;
      }

      final defaults = DanceStylesService.defaultStyles();
      for (int i = 0; i < defaults.length; i++) {
        final style = defaults[i];
        await _firestore.collection(_collection).add({
          ...style.toMap(),
          'priority': i,
        });
      }
    } catch (e) {
      rethrow;
    }
  }
}

class OnlineStylesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'onlineStyles';

  /// Get all active online styles
  static Future<List<DanceStyle>> getAllStyles() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('priority')
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => DanceStyle.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      return DanceStylesService.defaultStyles();
    }
  }

  /// Get all online styles (including inactive) for admin
  static Future<List<DanceStyle>> getAllStylesForAdmin() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('priority')
          .orderBy('name')
          .get();

      return snapshot.docs
          .map((doc) => DanceStyle.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      return DanceStylesService.defaultStyles();
    }
  }

  /// Add a new online style
  static Future<String> addStyle(DanceStyle style) async {
    try {
      final docRef = await _firestore.collection(_collection).add(style.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add online style');
    }
  }

  /// Update an existing online style
  static Future<void> updateStyle(String id, DanceStyle style) async {
    try {
      await _firestore.collection(_collection).doc(id).update(style.toMap());
    } catch (e) {
      throw Exception('Failed to update online style');
    }
  }

  /// Delete an online style
  static Future<void> deleteStyle(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete online style');
    }
  }

  /// Toggle online style active status
  static Future<void> toggleStyleStatus(String id, bool isActive) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to toggle online style status');
    }
  }

  /// Initialize online styles (seed from legacy or defaults)
  static Future<void> initializeDefaultStyles() async {
    try {
      final snapshot = await _firestore.collection(_collection).limit(1).get();
      if (snapshot.docs.isNotEmpty) return;

      final legacySnapshot = await _firestore.collection('danceStyles').get();
      if (legacySnapshot.docs.isNotEmpty) {
        for (final doc in legacySnapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data.putIfAbsent('createdAt', () => FieldValue.serverTimestamp());
          data['updatedAt'] = FieldValue.serverTimestamp();
          await _firestore.collection(_collection).add(data);
        }
        return;
      }

      final defaults = DanceStylesService.defaultStyles();
      for (int i = 0; i < defaults.length; i++) {
        final style = defaults[i];
        await _firestore.collection(_collection).add({
          ...style.toMap(),
          'priority': i,
        });
      }
    } catch (e) {
      rethrow;
    }
  }
}