import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'live_notification_service.dart';

class WorkshopService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Add new workshop
  static Future<Map<String, dynamic>> addWorkshop({
    required String title,
    required String instructor,
    required String date,
    required String time,
    required int price,
    required String description,
    required String category,
    required String level,
    required String location,
    required String duration,
    required int maxParticipants,
    String? imageUrl,
    File? imageFile,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Upload image if provided
      String? uploadedImageUrl = imageUrl;
      if (imageFile != null) {
        uploadedImageUrl = await _uploadWorkshopImage(imageFile);
      }

      // Generate workshop ID
      final workshopId = _firestore.collection('workshops').doc().id;

      // Create workshop data with all live features
      final workshopData = {
        'id': workshopId,
        'title': title,
        'instructor': instructor,
        'date': date,
        'time': time,
        'price': price,
        'description': description,
        'category': category,
        'level': level,
        'location': location,
        'duration': duration,
        'maxParticipants': maxParticipants,
        'currentParticipants': 0,
        'enrolledCount': 0,
        'participant_count': 0,
        'imageUrl': uploadedImageUrl ?? 'https://images.unsplash.com/photo-1508700929628-666bc8bd84ea?w=400',
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        // Live features
        'liveNotifications': true,
        'liveAttendance': true,
        'liveMetrics': true,
        'waitlistEnabled': true,
        'socialFeatures': true,
        'analyticsEnabled': true,
      };

      // Save to Firestore
      await _firestore.collection('workshops').doc(workshopId).set(workshopData);

      // Send live notification about new workshop to all students
      try {
        await _sendNewWorkshopNotification(workshopData);
      } catch (e) {
      }

      return {
        'success': true,
        'workshopId': workshopId,
        'message': 'Workshop added successfully!',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to add workshop: $e',
      };
    }
  }

  /// Update existing workshop
  static Future<Map<String, dynamic>> updateWorkshop({
    required String workshopId,
    required String title,
    required String instructor,
    required String date,
    required String time,
    required int price,
    required String description,
    required String category,
    required String level,
    required String location,
    required String duration,
    required int maxParticipants,
    String? imageUrl,
    File? imageFile,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Upload new image if provided
      String? uploadedImageUrl = imageUrl;
      if (imageFile != null) {
        uploadedImageUrl = await _uploadWorkshopImage(imageFile);
      }

      // Update workshop data
      final updateData = {
        'title': title,
        'instructor': instructor,
        'date': date,
        'time': time,
        'price': price,
        'description': description,
        'category': category,
        'level': level,
        'location': location,
        'duration': duration,
        'maxParticipants': maxParticipants,
        'updatedAt': FieldValue.serverTimestamp(),
        if (uploadedImageUrl != null) 'imageUrl': uploadedImageUrl,
      };

      // Update in Firestore
      await _firestore.collection('workshops').doc(workshopId).update(updateData);

      return {
        'success': true,
        'message': 'Workshop updated successfully!',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update workshop: $e',
      };
    }
  }

  /// Delete workshop
  static Future<Map<String, dynamic>> deleteWorkshop(String workshopId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if user is admin using custom claims
      final idTokenResult = await user.getIdTokenResult(true); // Force refresh
      final isAdmin = idTokenResult.claims?['admin'] == true;
      
      if (!isAdmin) {
        throw Exception('Only admins can delete workshops');
      }

      // Delete workshop
      await _firestore.collection('workshops').doc(workshopId).delete();

      // Delete related enrollments
      final enrollmentsQuery = await _firestore
          .collection('workshop_enrollments')
          .where('workshop_id', isEqualTo: workshopId)
          .get();

      for (var doc in enrollmentsQuery.docs) {
        await doc.reference.delete();
      }

      return {
        'success': true,
        'message': 'Workshop deleted successfully!',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to delete workshop: $e',
      };
    }
  }

  /// Get all workshops
  static Future<List<Map<String, dynamic>>> getAllWorkshops() async {
    try {
      final querySnapshot = await _firestore
          .collection('workshops')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get workshop by ID
  static Future<Map<String, dynamic>?> getWorkshopById(String workshopId) async {
    try {
      final doc = await _firestore.collection('workshops').doc(workshopId).get();
      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get workshops by category
  static Future<List<Map<String, dynamic>>> getWorkshopsByCategory(String category) async {
    try {
      final querySnapshot = await _firestore
          .collection('workshops')
          .where('category', isEqualTo: category)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get user's enrolled workshops
  static Future<List<Map<String, dynamic>>> getUserEnrolledWorkshops(String userId) async {
    try {
      final enrollmentsQuery = await _firestore
          .collection('workshop_enrollments')
          .where('user_id', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .get();

      final workshopIds = enrollmentsQuery.docs
          .map((doc) => doc.data()['workshop_id'] as String)
          .toList();

      if (workshopIds.isEmpty) return [];

      final workshopsQuery = await _firestore
          .collection('workshops')
          .where(FieldPath.documentId, whereIn: workshopIds)
          .get();

      return workshopsQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Upload workshop image
  static Future<String> _uploadWorkshopImage(File imageFile) async {
    try {
      final fileName = 'workshops/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Get workshop categories
  static List<String> getWorkshopCategories() {
    return [
      'Contemporary',
      'Bollywood',
      'Hip-Hop',
      'Classical',
      'Latin',
      'Jazz',
      'Bharatanatyam',
      'Kathak',
      'Salsa',
      'Bachata',
      'Other',
    ];
  }

  /// Get workshop levels
  static List<String> getWorkshopLevels() {
    return [
      'Beginner',
      'Intermediate',
      'Advanced',
      'All Levels',
    ];
  }

  /// Get workshop durations
  static List<String> getWorkshopDurations() {
    return [
      '1 hour',
      '1.5 hours',
      '2 hours',
      '2.5 hours',
      '3 hours',
      'Half Day (4 hours)',
      'Full Day (8 hours)',
    ];
  }

  /// Send notification about new workshop
  static Future<void> _sendNewWorkshopNotification(Map<String, dynamic> workshopData) async {
    try {
      final title = workshopData['title'] as String? ?? 'New Workshop';
      final instructor = workshopData['instructor'] as String? ?? 'Instructor';
      final date = workshopData['date'] as String?;
      final time = workshopData['time'] as String?;
      
      // Get all students
      final studentsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Student')
          .get();
      
      for (final studentDoc in studentsSnapshot.docs) {
        try {
          await LiveNotificationService.sendNewWorkshopNotification(
            workshopTitle: title,
            instructor: instructor,
            userId: studentDoc.id,
            date: date,
            time: time,
          );
        } catch (e) {
          // Continue to next student
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }

  /// Validate workshop data
  static Map<String, String> validateWorkshopData({
    required String title,
    required String instructor,
    required String date,
    required String time,
    required int price,
    required String description,
    required String category,
    required String level,
    required String location,
    required String duration,
    required int maxParticipants,
  }) {
    final errors = <String, String>{};

    if (title.trim().isEmpty) {
      errors['title'] = 'Title is required';
    }

    if (instructor.trim().isEmpty) {
      errors['instructor'] = 'Instructor name is required';
    }

    if (date.trim().isEmpty) {
      errors['date'] = 'Date is required';
    }

    if (time.trim().isEmpty) {
      errors['time'] = 'Time is required';
    }

    if (price <= 0) {
      errors['price'] = 'Price must be greater than 0';
    }

    if (description.trim().isEmpty) {
      errors['description'] = 'Description is required';
    }

    if (category.trim().isEmpty) {
      errors['category'] = 'Category is required';
    }

    if (level.trim().isEmpty) {
      errors['level'] = 'Level is required';
    }

    if (location.trim().isEmpty) {
      errors['location'] = 'Location is required';
    }

    if (duration.trim().isEmpty) {
      errors['duration'] = 'Duration is required';
    }

    if (maxParticipants <= 0) {
      errors['maxParticipants'] = 'Max participants must be greater than 0';
    }

    return errors;
  }
}
