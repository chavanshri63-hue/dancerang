import 'package:cloud_firestore/cloud_firestore.dart';
import 'package_model.dart';

class DanceClass {
  final String id;
  final String name;
  final String instructor;
  final String description;
  final String category;
  final String level; // Beginner, Intermediate, Advanced
  final String duration; // e.g., "60 minutes"
  final String price;
  final String studio;
  final String imageUrl;
  final String? ageGroup; // 'kids' | 'adults'
  final DateTime? dateTime; // Old format
  final List<String>? days; // New format
  final String? startTime; // New format
  final String? endTime; // New format
  final int maxStudents;
  final int currentBookings;
  final int? availableSpots; // Store actual available spots
  final bool isAvailable;
  final int? numberOfSessions; // Total number of sessions for this class (set by admin/faculty)
  final List<String> requirements;
  final Map<String, dynamic> schedule; // Day and time
  final List<ClassPackage> packages; // Available packages for this class

  DanceClass({
    required this.id,
    required this.name,
    required this.instructor,
    required this.description,
    required this.category,
    required this.level,
    required this.duration,
    required this.price,
    required this.studio,
    required this.imageUrl,
    this.ageGroup,
    this.dateTime, // Old format - optional
    this.days, // New format - optional
    this.startTime, // New format - optional
    this.endTime, // New format - optional
    required this.maxStudents,
    required this.currentBookings,
    this.availableSpots, // Optional field
    required this.isAvailable,
    this.numberOfSessions, // Optional - total sessions for this class
    required this.requirements,
    required this.schedule,
    required this.packages,
  });

  factory DanceClass.fromMap(Map<String, dynamic> map) {
    String _stringValue(dynamic value, String fallback) {
      if (value == null) return fallback;
      return value.toString();
    }
    // Handle old format (dateTime)
    DateTime? resolvedDateTime;
    final dynamic rawDateTime = map['dateTime'];
    if (rawDateTime != null) {
      if (rawDateTime is Timestamp) {
        resolvedDateTime = rawDateTime.toDate();
      } else if (rawDateTime is String) {
        resolvedDateTime = DateTime.tryParse(rawDateTime) ?? DateTime.now();
      } else if (rawDateTime is int) {
        // treat as milliseconds since epoch
        resolvedDateTime = DateTime.fromMillisecondsSinceEpoch(rawDateTime);
      } else {
        resolvedDateTime = DateTime.now();
      }
    }

    // Handle new format (days, startTime, endTime)
    List<String>? days;
    String? startTime;
    String? endTime;
    
    if (map['days'] != null) {
      days = List<String>.from(map['days']);
    }
    if (map['startTime'] != null) {
      startTime = map['startTime'].toString();
    }
    if (map['endTime'] != null) {
      endTime = map['endTime'].toString();
    }

    return DanceClass(
      id: map['id'] ?? '',
      name: _stringValue(map['name'], ''),
      instructor: _stringValue(map['instructor'] ?? map['instructorName'], ''), // Support both fields
      description: _stringValue(map['description'], ''),
      category: _stringValue(map['category'], ''),
      level: _stringValue(map['level'], 'Beginner'),
      duration: _stringValue(map['duration'], '60 minutes'),
      price: _stringValue(map['price'], '₹500'),
      studio: _stringValue(map['studio'], ''),
      imageUrl: _stringValue(map['imageUrl'], ''),
      ageGroup: map['ageGroup']?.toString(),
      dateTime: resolvedDateTime, // Old format
      days: days, // New format
      startTime: startTime, // New format
      endTime: endTime, // New format
      maxStudents: map['maxStudents'] ?? 20,
      currentBookings: (map['currentBookings'] ?? 0) > 0 
          ? (map['currentBookings'] ?? 0)
          : (map['enrolledCount'] ?? map['participant_count'] ?? 0),
      availableSpots: map['availableSpots'] ?? map['maxStudents'] ?? 20,
      isAvailable: map['isAvailable'] ?? true,
      numberOfSessions: map['numberOfSessions'] != null ? (map['numberOfSessions'] as num).toInt() : null,
      requirements: (map['requirements'] as List<dynamic>? ?? [])
          .map((r) => r?.toString() ?? '')
          .where((r) => r.isNotEmpty)
          .toList(),
      schedule: Map<String, dynamic>.from(map['schedule'] ?? {}),
      packages: (map['packages'] as List<dynamic>? ?? [])
          .where((p) => p is Map)
          .map((p) => ClassPackage.fromMap(Map<String, dynamic>.from(p as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'id': id,
      'name': name,
      'instructor': instructor,
      'description': description,
      'category': category,
      'level': level,
      'duration': duration,
      'price': price,
      'studio': studio,
      'imageUrl': imageUrl,
      if (ageGroup != null) 'ageGroup': ageGroup,
      'maxStudents': maxStudents,
      'currentBookings': currentBookings,
      'availableSpots': availableSpots,
      'isAvailable': isAvailable,
      if (numberOfSessions != null) 'numberOfSessions': numberOfSessions,
      'requirements': requirements,
      'schedule': schedule,
      'packages': packages.map((p) => p.toMap()).toList(),
    };
    
    // Add old format if available
    if (dateTime != null) {
      map['dateTime'] = Timestamp.fromDate(dateTime!);
    }
    
    // Add new format if available
    if (days != null) {
      map['days'] = days!;
    }
    if (startTime != null) {
      map['startTime'] = startTime!;
    }
    if (endTime != null) {
      map['endTime'] = endTime!;
    }
    
    return map;
  }

  // Helper methods
  bool get isFullyBooked => currentBookings >= maxStudents;
  int get availableSpotsCount => availableSpots ?? (maxStudents - currentBookings);
  
  // Handle both old and new formats
  String get formattedDate {
    if (dateTime != null) {
      return '${dateTime!.day}/${dateTime!.month}/${dateTime!.year}';
    } else if (days != null && days!.isNotEmpty) {
      return days!.join(', ');
    }
    return 'TBD';
  }
  
  String get formattedTime {
    if (dateTime != null) {
      return '${dateTime!.hour.toString().padLeft(2, '0')}:${dateTime!.minute.toString().padLeft(2, '0')}';
    } else if (startTime != null && endTime != null) {
      return '$startTime - $endTime';
    }
    return 'TBD';
  }
  
  // Check if class uses new format
  bool get isNewFormat => days != null && startTime != null && endTime != null;
  bool get isOldFormat => dateTime != null;
}

// Class categories
class ClassCategory {
  final String id;
  final String name;
  final String icon;
  final String description;

  ClassCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
  });

  static List<ClassCategory> getCategories() {
    return [
      ClassCategory(
        id: 'hiphop',
        name: 'Hip Hop',
        icon: '🕺',
        description: 'Urban dance styles and freestyle',
      ),
      ClassCategory(
        id: 'bollywood',
        name: 'Bollywood',
        icon: '🎬',
        description: 'Bollywood dance and Indian classical fusion',
      ),
      ClassCategory(
        id: 'contemporary',
        name: 'Contemporary',
        icon: '💃',
        description: 'Modern contemporary dance forms',
      ),
      ClassCategory(
        id: 'jazz',
        name: 'Jazz',
        icon: '🎭',
        description: 'Jazz dance techniques and choreography',
      ),
      ClassCategory(
        id: 'ballet',
        name: 'Ballet',
        icon: '🩰',
        description: 'Classical ballet techniques',
      ),
      ClassCategory(
        id: 'salsa',
        name: 'Salsa',
        icon: '🌶️',
        description: 'Latin dance and salsa techniques',
      ),
    ];
  }
}

// Class levels
enum ClassLevel {
  beginner('Beginner', '🟢'),
  intermediate('Intermediate', '🟡'),
  advanced('Advanced', '🔴');

  const ClassLevel(this.displayName, this.icon);
  final String displayName;
  final String icon;
}
