// lib/models/member.dart

/// App roles
enum UserRole { student, faculty, admin }

extension UserRoleX on UserRole {
  String get name => toString().split('.').last;

  static UserRole fromAny(Object? v) {
    final s = (v ?? '').toString().toLowerCase();
    switch (s) {
      case 'faculty':
        return UserRole.faculty;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.student;
    }
  }
}