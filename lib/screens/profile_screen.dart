import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../widgets/glassmorphism_app_bar.dart';
import '../services/payment_service.dart';
import 'profile_setup_screen.dart';
import 'settings_screen.dart';
import 'help_support_screen.dart';
import 'admin_dashboard_screen.dart';
import 'login_screen.dart';
import 'user_progress_screen.dart';
import '../config/demo_session.dart';
import '../utils/error_handler.dart';

class ProfileScreen extends StatefulWidget {
  final String role; // 'student' | 'faculty' | 'admin'
  const ProfileScreen({super.key, required this.role});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  UserProfile? _profile;
  String _currentRole = '';
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.role;
    _loadProfile();
    
    // Listen to payment success events for real-time updates
    _paymentRefreshSubscription = PaymentService.refreshStream.listen((event) {
      if (event['type'] == 'payment_success' && mounted) {
        setState(() {
          // Force rebuild when payment succeeds
        });
      }
    });
  }

  @override
  void dispose() {
    _paymentRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    if (DemoSession.isActive) {
      setState(() {
        _currentRole = 'demo';
        _profile = UserProfile(
          name: 'Demo',
          email: 'demo@dancerang.com',
          phone: '+91 00000 00000',
          role: 'Demo',
          id: 'DEMO001',
          joinDate: DateTime.now(),
          profileImage: null,
          additionalInfo: const {
            'level': 'Demo',
            'favorite_dance_style': 'Not Set',
          },
        );
        _isLoading = false;
      });
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get real-time user data from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final userData = doc.data()!;
        final role = userData['role'] ?? 'Student';
        _currentRole = role.toLowerCase();
        
        setState(() {
          _profile = _getRealProfile(userData, role);
          _isLoading = false;
        });
      } else {
        // Create profile from Firebase Auth data if no Firestore data
        setState(() {
          _profile = _createProfileFromAuth(FirebaseAuth.instance.currentUser);
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'loading profile');
      setState(() {
        _profile = _createProfileFromAuth(FirebaseAuth.instance.currentUser);
        _isLoading = false;
      });
    }
  }

  UserProfile _getRealProfile(Map<String, dynamic> userData, String role) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = userData['name'] ?? user?.displayName ?? 'DanceRang User';
    final userEmail = (userData['email'] as String?) ?? user?.email ?? 'user@dancerang.com';
    final userPhone = userData['phone'] ?? user?.phoneNumber ?? '+91 00000 00000';
    final joinDate = userData['createdAt']?.toDate() ?? user?.metadata.creationTime ?? DateTime.now();
    final profileImage = userData['profilePhoto'] ?? userData['photoUrl'] ?? user?.photoURL;
    
    switch (role.toLowerCase()) {
      case 'student':
        return UserProfile(
          name: userName,
          email: userEmail,
          phone: userPhone,
          role: 'Student',
          id: user?.uid ?? 'STU001',
          joinDate: joinDate,
          profileImage: profileImage,
          additionalInfo: {
            'classes_enrolled': userData['classes_enrolled'] ?? 0,
            'attendance_percentage': userData['attendance_percentage'] ?? 0,
            'favorite_dance_style': userData['favorite_dance_style'] ?? 'Not specified',
            'level': userData['level'] ?? 'Beginner',
            'address': userData['address'],
            'bio': userData['bio'],
            'dob': userData['dob'],
          },
        );
      case 'faculty':
        return UserProfile(
          name: userName,
          email: userEmail,
          phone: userPhone,
          role: 'Faculty',
          id: user?.uid ?? 'FAC001',
          joinDate: joinDate,
          profileImage: profileImage,
          additionalInfo: {
            'classes_teaching': userData['classes_teaching'] ?? 0,
            'students_count': userData['students_count'] ?? 0,
            'specialization': userData['specialization'] ?? 'Not specified',
            'experience_years': userData['experience_years'] ?? 0,
            'qualification': userData['qualification'] ?? 'Not specified',
            'address': userData['address'],
            'bio': userData['bio'],
            'dob': userData['dob'],
          },
        );
      case 'admin':
        return UserProfile(
          name: userName,
          email: userEmail,
          phone: userPhone,
          role: 'Admin',
          id: user?.uid ?? '',
          joinDate: joinDate,
          profileImage: profileImage,
          additionalInfo: {
            'address': userData['address'],
            'bio': userData['bio'],
            'dob': userData['dob'],
          },
        );
      default:
        return UserProfile(
          name: userName,
          email: userEmail,
          phone: userPhone,
          role: 'Student',
          id: user?.uid ?? '',
          joinDate: joinDate,
          profileImage: profileImage,
          additionalInfo: {
            'classes_enrolled': userData['classes_enrolled'] ?? 0,
            'attendance_percentage': userData['attendance_percentage'] ?? 0,
            'favorite_dance_style': userData['favorite_dance_style'] ?? 'Not specified',
            'level': userData['level'] ?? 'Beginner',
            'address': userData['address'],
            'bio': userData['bio'],
            'dob': userData['dob'],
          },
        );
    }
  }

  UserProfile _createProfileFromAuth(User? user) {
    final userName = user?.displayName ?? 'DanceRang User';
    final userEmail = user?.email ?? 'user@dancerang.com';
    final userPhone = user?.phoneNumber ?? '+91 00000 00000';
    
    switch (widget.role) {
      case 'student':
        return UserProfile(
          name: userName,
          email: userEmail,
          phone: userPhone,
          role: 'Student',
          id: user?.uid ?? 'STU001',
          joinDate: user?.metadata.creationTime ?? DateTime.now(),
          profileImage: user?.photoURL,
          additionalInfo: {
            'classes_enrolled': 0,
            'attendance_percentage': 0,
            'favorite_dance_style': 'Not Set',
            'level': 'Beginner',
          },
        );
      case 'faculty':
        return UserProfile(
          name: userName,
          email: userEmail,
          phone: userPhone,
          role: 'Faculty',
          id: user?.uid ?? 'FAC001',
          joinDate: user?.metadata.creationTime ?? DateTime.now(),
          profileImage: user?.photoURL,
          additionalInfo: {
            'classes_teaching': 0,
            'students_count': 0,
            'specialization': 'Not Set',
            'experience_years': 0,
            'qualification': 'Not Set',
          },
        );
      case 'admin':
        return UserProfile(
          name: userName,
          email: userEmail,
          phone: userPhone,
          role: 'Admin',
          id: user?.uid ?? 'ADM001',
          joinDate: user?.metadata.creationTime ?? DateTime.now(),
          profileImage: user?.photoURL,
          additionalInfo: {
            'total_students': 0,
            'total_faculty': 0,
            'total_classes': 0,
            'academy_established': 2020,
          },
        );
      default:
        return UserProfile(
          name: userName,
          email: userEmail,
          phone: userPhone,
          role: 'Student',
          id: user?.uid ?? 'STU001',
          joinDate: user?.metadata.creationTime ?? DateTime.now(),
          profileImage: user?.photoURL,
          additionalInfo: {
            'classes_enrolled': 0,
            'attendance_percentage': 0,
            'favorite_dance_style': 'Not Set',
            'level': 'Beginner',
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'Profile',
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFE53935),
              ),
            )
          : _profile == null
              ? _buildErrorState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 24),
                      _buildProfileInfo(),
                      const SizedBox(height: 24),
                      _buildRoleSpecificInfo(),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      elevation: 8,
      shadowColor: const Color(0xFFE53935).withOpacity(0.2),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFFE53935).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withOpacity(0.8),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _openAvatarViewer,
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFE53935).withOpacity(0.2),
                          const Color(0xFFD32F2F).withOpacity(0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: const Color(0xFFE53935).withOpacity(0.3),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE53935).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _profile!.profileImage != null && _profile!.profileImage!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              _profile!.profileImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  _getRoleIcon(),
                                  size: 60,
                                  color: const Color(0xFFE53935),
                                );
                              },
                            ),
                          )
                        : Icon(
                            _getRoleIcon(),
                            size: 60,
                            color: const Color(0xFFE53935),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.open_in_full,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _profile!.name,
                    style: const TextStyle(
                      color: Color(0xFFF9FAFB),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE53935).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          _profile!.role.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Text(
                          'ID: ${_profile!.id}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.email, size: 14, color: Colors.white70),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _profile!.email,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 14, color: Colors.white70),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _profile!.phone,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Member since ${_profile!.joinDate.year}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Card(
      elevation: 6,
      shadowColor: const Color(0xFFE53935).withOpacity( 0.18),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFFE53935).withOpacity( 0.26),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFE53935).withOpacity(0.12),
              const Color(0xFF4F46E5).withOpacity(0.10),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity( 0.2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity( 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow(Icons.email, 'Email', _profile!.email, Colors.white),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.phone, 'Phone', _profile!.phone, Colors.white),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.badge, 'ID', _profile!.id, Colors.white),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.calendar_today, 'Join Date', 
                '${_profile!.joinDate.day}/${_profile!.joinDate.month}/${_profile!.joinDate.year}', Colors.white),
            const SizedBox(height: 12),
            if ((_profile!.additionalInfo['address'] as String?) != null && (_profile!.additionalInfo['address'] as String).trim().isNotEmpty)
              _buildInfoRow(Icons.home, 'Address', (_profile!.additionalInfo['address'] as String).trim(), Colors.white),
            if ((_profile!.additionalInfo['address'] as String?) != null && (_profile!.additionalInfo['address'] as String).trim().isNotEmpty)
              const SizedBox(height: 12),
            if ((_profile!.additionalInfo['dob'] as String?) != null && (_profile!.additionalInfo['dob'] as String).trim().isNotEmpty)
              _buildInfoRow(
                Icons.cake,
                'Date of Birth',
                (() {
                  try {
                    final parsed = DateTime.tryParse((_profile!.additionalInfo['dob'] as String).trim());
                    if (parsed != null) {
                      return '${parsed.day}/${parsed.month}/${parsed.year}';
                    }
                  } catch (_) {}
                  return (_profile!.additionalInfo['dob'] as String).trim();
                })(),
                Colors.white,
              ),
            if ((_profile!.additionalInfo['dob'] as String?) != null && (_profile!.additionalInfo['dob'] as String).trim().isNotEmpty)
              const SizedBox(height: 12),
            if ((_profile!.additionalInfo['bio'] as String?) != null && (_profile!.additionalInfo['bio'] as String).trim().isNotEmpty)
              _buildInfoRow(Icons.info_outline, 'Bio', (_profile!.additionalInfo['bio'] as String).trim(), Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSpecificInfo() {
    if (_currentRole.toLowerCase() == 'student') {
      // Remove student statistics section for student role
      return const SizedBox.shrink();
    }
    return Card(
      elevation: 6,
      shadowColor: const Color(0xFF4F46E5).withOpacity( 0.15),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFF4F46E5).withOpacity( 0.22),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF4F46E5).withOpacity(0.12),
              const Color(0xFF10B981).withOpacity(0.10),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity( 0.2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity( 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getRoleSpecificIcon(),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _getRoleSpecificTitle(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildRealTimeRoleSpecificRows(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (_currentRole.toLowerCase() == 'admin')
          _buildActionButton(
            icon: Icons.dashboard_customize,
            title: 'Admin Dashboard',
            subtitle: 'Manage app settings and view summaries',
            onTap: _openAdminDashboard,
          ),
        if (_currentRole.toLowerCase() == 'admin') const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.edit,
          title: 'Edit Profile',
          subtitle: 'Update your personal information',
          onTap: _editProfile,
        ),
        // Removed Settings for all roles as requested
        const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.help_outline,
          title: 'Help & Support',
          subtitle: 'Get help and contact support',
          onTap: _openHelp,
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.logout,
          title: 'Logout',
          subtitle: 'Sign out of your account',
          onTap: _logout,
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, [Color? textColor]) {
    final color = textColor ?? const Color(0xFFF9FAFB);
    Color? iconHue;
    // Map small icons to themed hues
    if (icon == Icons.email || icon == Icons.badge) {
      iconHue = const Color(0xFF4F46E5); // Indigo for identity
    } else if (icon == Icons.phone) {
      iconHue = const Color(0xFF22C55E); // Success green for phone
    } else if (icon == Icons.calendar_today || icon == Icons.cake) {
      iconHue = const Color(0xFFF59E0B); // Amber for dates
    } else if (icon == Icons.home || icon == Icons.location_on) {
      iconHue = const Color(0xFF14B8A6); // Teal for address/location
    } else if (icon == Icons.info_outline) {
      iconHue = const Color(0xFF60A5FA); // Soft blue for info
    } else if (icon == Icons.school || icon == Icons.class_) {
      iconHue = const Color(0xFF6366F1); // Indigo for classes/school
    } else if (icon == Icons.trending_up) {
      iconHue = const Color(0xFF10B981); // Green for attendance/progress
    } else if (icon == Icons.people) {
      iconHue = const Color(0xFF60A5FA); // Blue for people counts
    } else if (icon == Icons.star) {
      iconHue = const Color(0xFFF59E0B); // Amber for level/ratings
    } else if (icon == Icons.work) {
      iconHue = const Color(0xFF14B8A6); // Teal for work/experience
    } else if (icon == Icons.favorite) {
      iconHue = const Color(0xFFF43F5E); // Rose for favorites
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (iconHue ?? color).withOpacity(0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: iconHue ?? color.withOpacity(0.9),
            size: 14,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildRealTimeRoleSpecificRows() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    
    switch (_currentRole) {
      case 'student':
        return _buildStudentRealTimeStats(user.uid);
      case 'faculty':
        return _buildFacultyRealTimeStats(user.uid);
      case 'admin':
        return _buildAdminRealTimeStats();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStudentRealTimeStats(String userId) {
    return Column(
      children: [
        // Classes Enrolled - Real-time
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('class_enrollments')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: 'active')
              .snapshots(),
          builder: (context, snapshot) {
            final enrolledCount = snapshot.data?.docs.length ?? 0;
            return _buildInfoRow(Icons.school, 'Classes Enrolled', '$enrolledCount');
          },
        ),
        const SizedBox(height: 12),
        
        // Subscription Status - Real-time
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('subscriptions')
              .where('status', isEqualTo: 'active')
              .where('endDate', isGreaterThan: Timestamp.now())
              .snapshots(),
          builder: (context, snapshot) {
            final hasActiveSubscription = snapshot.data?.docs.isNotEmpty ?? false;
            final subscriptionStatus = hasActiveSubscription ? 'Active' : 'Inactive';
            final statusColor = hasActiveSubscription ? Colors.green : Colors.red;
            return _buildInfoRow(Icons.video_library, 'Video Access', subscriptionStatus, statusColor);
          },
        ),
        const SizedBox(height: 12),
        
        // Attendance - Real-time calculation
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('attendance')
              .where('userId', isEqualTo: userId)
              .snapshots(),
          builder: (context, snapshot) {
            final totalSessions = snapshot.data?.docs.length ?? 0;
            final presentSessions = snapshot.data?.docs.where((doc) => 
              doc.data()['status'] == 'present').length ?? 0;
            final attendancePercent = totalSessions > 0 ? 
              ((presentSessions / totalSessions) * 100).round() : 0;
            return _buildInfoRow(Icons.trending_up, 'Attendance', '$attendancePercent%');
          },
        ),
        const SizedBox(height: 12),
        
        // Static info from profile
        _buildInfoRow(Icons.favorite, 'Favorite Style', _profile!.additionalInfo['favorite_dance_style']!, Colors.white),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.star, 'Level', _profile!.additionalInfo['level']!, Colors.white),
      ],
    );
  }

  Widget _buildFacultyRealTimeStats(String userId) {
    return Column(
      children: [
        // Classes Teaching - Real-time
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('classes')
              .where('instructorId', isEqualTo: userId)
              .snapshots(),
          builder: (context, snapshot) {
            final teachingCount = snapshot.data?.docs.length ?? 0;
            return _buildInfoRow(Icons.school, 'Classes Teaching', '$teachingCount');
          },
        ),
        const SizedBox(height: 12),
        
        // Total Students - Real-time
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('enrollments')
              .where('instructorId', isEqualTo: userId)
              .where('status', isEqualTo: 'enrolled')
              .snapshots(),
          builder: (context, snapshot) {
            final studentCount = snapshot.data?.docs.length ?? 0;
            return _buildInfoRow(Icons.people, 'Total Students', '$studentCount');
          },
        ),
        const SizedBox(height: 12),
        
        // Static info from profile
        _buildInfoRow(Icons.star, 'Specialization', _profile!.additionalInfo['specialization']!, Colors.white),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.work, 'Experience', '${_profile!.additionalInfo['experience_years']} years', Colors.white),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.school, 'Qualification', _profile!.additionalInfo['qualification']!, Colors.white),
      ],
    );
  }

  Widget _buildAdminRealTimeStats() {
    return Column(
      children: [
        // Total Students - Real-time
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .snapshots(),
          builder: (context, snapshot) {
            final users = snapshot.data?.docs ?? [];
            final studentCount = users.where((doc) {
              final role = doc.data()['role'] ?? '';
              return role.toString().toLowerCase() == 'student';
            }).length;
            return _buildInfoRow(Icons.people, 'Total Students', '$studentCount');
          },
        ),
        const SizedBox(height: 12),
        
        // Total Faculty - Real-time
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .snapshots(),
          builder: (context, snapshot) {
            final users = snapshot.data?.docs ?? [];
            final facultyCount = users.where((doc) {
              final role = doc.data()['role'] ?? '';
              return role.toString().toLowerCase() == 'faculty';
            }).length;
            return _buildInfoRow(Icons.school, 'Total Faculty', '$facultyCount');
          },
        ),
        const SizedBox(height: 12),
        
        // Total Classes - Real-time
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('classes')
              .where('isAvailable', isEqualTo: true)
              .snapshots(),
          builder: (context, snapshot) {
            final classCount = snapshot.data?.docs.length ?? 0;
            return _buildInfoRow(Icons.class_, 'Total Classes', '$classCount');
          },
        ),
        const SizedBox(height: 12),
        
        // Static info from profile
        _buildInfoRow(Icons.calendar_today, 'Academy Established', '${_profile!.additionalInfo['academy_established']}', Colors.white),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    Color iconColor;
    Color backgroundColor;
    
    if (isDestructive) {
      iconColor = const Color(0xFFEF4444);
      backgroundColor = const Color(0xFFEF4444).withOpacity( 0.15);
    } else if (title == 'Edit Profile') {
      iconColor = const Color(0xFF10B981);
      backgroundColor = const Color(0xFF10B981).withOpacity( 0.15);
    } else if (title == 'Settings') {
      iconColor = const Color(0xFF4F46E5);
      backgroundColor = const Color(0xFF4F46E5).withOpacity( 0.15);
    } else if (title == 'Help & Support') {
      iconColor = const Color(0xFFFF9800);
      backgroundColor = const Color(0xFFFF9800).withOpacity( 0.15);
    } else {
      iconColor = const Color(0xFFE53935);
      backgroundColor = const Color(0xFFE53935).withOpacity( 0.15);
    }
    
    return Card(
      elevation: 4,
      shadowColor: iconColor.withOpacity( 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: iconColor.withOpacity( 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDestructive ? iconColor : const Color(0xFFF9FAFB),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white54,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withOpacity( 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 64,
              color: Color(0xFFE53935),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Error Loading Profile',
            style: TextStyle(
              color: Color(0xFFF9FAFB),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Unable to load profile information',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRoleIcon() {
    switch (_currentRole) {
      case 'student':
        return Icons.school;
      case 'faculty':
        return Icons.person_outline;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
    }
  }

  IconData _getRoleSpecificIcon() {
    switch (_currentRole) {
      case 'student':
        return Icons.school;
      case 'faculty':
        return Icons.person_outline;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.info;
    }
  }

  String _getRoleSpecificTitle() {
    switch (_currentRole) {
      case 'student':
        return 'Student Statistics';
      case 'faculty':
        return 'Teaching Information';
      case 'admin':
        return 'Academy Overview';
      default:
        return 'Additional Information';
    }
  }

  void _editProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileSetupScreen(
          phoneNumber: _profile?.phone ?? '',
          isEditing: true,
        ),
      ),
    ).then((_) {
      // Refresh profile after returning from edit
      _loadProfile();
    });
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _openHelp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HelpSupportScreen(),
      ),
    );
  }

  void _openAvatarViewer() {
    final imageUrl = _profile?.profileImage;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.transparent,
            child: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.contain)
                    : Icon(_getRoleIcon(), size: 120, color: const Color(0xFFE53935)),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openAdminDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminDashboardScreen(),
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Logout',
          style: TextStyle(color: Color(0xFFF9FAFB)),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              DemoSession.isActive = false;
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class UserProfile {
  final String name;
  final String email;
  final String phone;
  final String role;
  final String id;
  final DateTime joinDate;
  final String? profileImage;
  final Map<String, dynamic> additionalInfo;

  UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.id,
    required this.joinDate,
    this.profileImage,
    required this.additionalInfo,
  });
}
