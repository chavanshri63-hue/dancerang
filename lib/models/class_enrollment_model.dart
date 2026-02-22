import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for class enrollment with session tracking
class ClassEnrollment {
  final String id;
  final String userId;
  final String classId;
  final String className;
  final String packageId;
  final String packageName;
  final int totalSessions;
  final int completedSessions;
  final int remainingSessions;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'active', 'pending_payment', 'expired', 'completed', 'cancelled', 'payment_success_unfulfilled'
  final double packagePrice;
  final String paymentStatus; // 'paid', 'pending', 'failed'
  final DateTime? lastAttendanceDate;
  final List<AttendanceRecord> attendanceHistory;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClassEnrollment({
    required this.id,
    required this.userId,
    required this.classId,
    required this.className,
    required this.packageId,
    required this.packageName,
    required this.totalSessions,
    required this.completedSessions,
    required this.remainingSessions,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.packagePrice,
    required this.paymentStatus,
    this.lastAttendanceDate,
    required this.attendanceHistory,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClassEnrollment.fromMap(Map<String, dynamic> map) {
    return ClassEnrollment(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      classId: map['classId'] ?? '',
      className: map['className'] ?? '',
      packageId: map['packageId'] ?? '',
      packageName: map['packageName'] ?? '',
      totalSessions: map['totalSessions'] ?? 0,
      completedSessions: map['completedSessions'] ?? 0,
      remainingSessions: map['remainingSessions'] ?? 0,
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'active',
      packagePrice: (map['packagePrice'] ?? 0).toDouble(),
      paymentStatus: map['paymentStatus'] ?? 'pending',
      lastAttendanceDate: (map['lastAttendanceDate'] as Timestamp?)?.toDate(),
      attendanceHistory: (map['attendanceHistory'] as List<dynamic>? ?? [])
          .map((record) => AttendanceRecord.fromMap(Map<String, dynamic>.from(record)))
          .toList(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'classId': classId,
      'className': className,
      'packageId': packageId,
      'packageName': packageName,
      'totalSessions': totalSessions,
      'completedSessions': completedSessions,
      'remainingSessions': remainingSessions,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status,
      'packagePrice': packagePrice,
      'paymentStatus': paymentStatus,
      'lastAttendanceDate': lastAttendanceDate != null ? Timestamp.fromDate(lastAttendanceDate!) : null,
      'attendanceHistory': attendanceHistory.map((record) => record.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Helper methods
  bool get isActive => status == 'active' && DateTime.now().isBefore(endDate);
  bool get isExpired => DateTime.now().isAfter(endDate);
  bool get isCompleted => completedSessions >= totalSessions;
  bool get needsPayment => paymentStatus == 'pending' || paymentStatus == 'failed';
  bool get isPaymentDue => isExpired || remainingSessions <= 1;
  
  double get progressPercentage => totalSessions > 0 ? (completedSessions / totalSessions) * 100 : 0;
  
  String get statusText {
    if (status == 'pending_payment') return 'Payment Pending';
    if (status == 'payment_success_unfulfilled') return 'Contact Support';
    if (isCompleted) return 'Completed';
    if (isExpired) return 'Expired';
    if (needsPayment) return 'Payment Due';
    return 'Active';
  }

  ClassEnrollment copyWith({
    String? id,
    String? userId,
    String? classId,
    String? className,
    String? packageId,
    String? packageName,
    int? totalSessions,
    int? completedSessions,
    int? remainingSessions,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    double? packagePrice,
    String? paymentStatus,
    DateTime? lastAttendanceDate,
    List<AttendanceRecord>? attendanceHistory,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClassEnrollment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      totalSessions: totalSessions ?? this.totalSessions,
      completedSessions: completedSessions ?? this.completedSessions,
      remainingSessions: remainingSessions ?? this.remainingSessions,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      packagePrice: packagePrice ?? this.packagePrice,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      lastAttendanceDate: lastAttendanceDate ?? this.lastAttendanceDate,
      attendanceHistory: attendanceHistory ?? this.attendanceHistory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Model for individual attendance records
class AttendanceRecord {
  final String id;
  final DateTime attendanceDate;
  final String classId;
  final String className;
  final String markedBy; // faculty/admin user ID
  final String markedByName; // faculty/admin name
  final String status; // 'present', 'absent', 'late'
  final String? notes;

  AttendanceRecord({
    required this.id,
    required this.attendanceDate,
    required this.classId,
    required this.className,
    required this.markedBy,
    required this.markedByName,
    required this.status,
    this.notes,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'] ?? '',
      attendanceDate: (map['attendanceDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      classId: map['classId'] ?? '',
      className: map['className'] ?? '',
      markedBy: map['markedBy'] ?? '',
      markedByName: map['markedByName'] ?? '',
      status: map['status'] ?? 'present',
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'attendanceDate': Timestamp.fromDate(attendanceDate),
      'classId': classId,
      'className': className,
      'markedBy': markedBy,
      'markedByName': markedByName,
      'status': status,
      'notes': notes,
    };
  }
}

/// Model for class packages with session details
class ClassPackage {
  final String id;
  final String name;
  final String description;
  final double price;
  final int totalSessions;
  final int validityDays; // Package validity in days
  final List<String> features;
  final bool isActive;
  final String category; // 'monthly', 'quarterly', 'annual'
  final double? originalPrice; // For discounts
  final bool isRecommended;

  ClassPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.totalSessions,
    required this.validityDays,
    required this.features,
    this.isActive = true,
    required this.category,
    this.originalPrice,
    this.isRecommended = false,
  });

  factory ClassPackage.fromMap(Map<String, dynamic> map) {
    return ClassPackage(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      totalSessions: map['totalSessions'] ?? 0,
      validityDays: map['validityDays'] ?? 30,
      features: List<String>.from(map['features'] ?? []),
      isActive: map['isActive'] ?? true,
      category: map['category'] ?? 'monthly',
      originalPrice: map['originalPrice']?.toDouble(),
      isRecommended: map['isRecommended'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'totalSessions': totalSessions,
      'validityDays': validityDays,
      'features': features,
      'isActive': isActive,
      'category': category,
      'originalPrice': originalPrice,
      'isRecommended': isRecommended,
    };
  }

  // Helper methods
  bool get hasDiscount => originalPrice != null && originalPrice! > price;
  double get discountPercentage {
    if (!hasDiscount) return 0.0;
    return ((originalPrice! - price) / originalPrice! * 100).roundToDouble();
  }

  String get formattedPrice => '₹${price.toStringAsFixed(0)}';
  String get formattedOriginalPrice => originalPrice != null ? '₹${originalPrice!.toStringAsFixed(0)}' : '';
  String get discountText => hasDiscount ? '${discountPercentage.toInt()}% OFF' : '';
}
