import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';

class NotificationsManagementScreen extends StatefulWidget {
  const NotificationsManagementScreen({super.key});

  @override
  State<NotificationsManagementScreen> createState() => _NotificationsManagementScreenState();
}

class _NotificationsManagementScreenState extends State<NotificationsManagementScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _selectedType = 'general';
  String _selectedTarget = 'all';
  bool _isScheduled = false;
  DateTime _scheduledDate = DateTime.now();

  final List<String> _notificationTypes = [
    'general',
    'new_video',
    'live_class',
    'subscription',
    'promotion',
    'reminder',
  ];

  final List<String> _targetAudiences = [
    'all',
    'students',
    'faculty',
    'subscribers',
    'non_subscribers',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'Notifications',
        actions: [
          IconButton(
            icon: const Icon(Icons.send, color: Colors.white),
            onPressed: _sendNotification,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildNotificationForm(),
            const SizedBox(height: 24),
            _buildRecentNotifications(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationForm() {
    return Card(
      elevation: 6,
      shadowColor: const Color(0xFF4F46E5).withOpacity(0.15),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF4F46E5).withOpacity(0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send Notification',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // Title Field
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Notification Title',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Message Field
            TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notification Message',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Notification Type
            DropdownButtonFormField<String>(
              value: _selectedType,
              dropdownColor: const Color(0xFF1B1B1B),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Notification Type',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                ),
              ),
              items: _notificationTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.replaceAll('_', ' ').toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value ?? 'general';
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Target Audience
            DropdownButtonFormField<String>(
              value: _selectedTarget,
              dropdownColor: const Color(0xFF1B1B1B),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Target Audience',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                ),
              ),
              items: _targetAudiences.map((target) {
                return DropdownMenuItem(
                  value: target,
                  child: Text(target.replaceAll('_', ' ').toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTarget = value ?? 'all';
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Schedule Toggle
            SwitchListTile(
              title: const Text('Schedule Notification', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Send at a specific time', style: TextStyle(color: Colors.white70)),
              value: _isScheduled,
              onChanged: (value) {
                setState(() {
                  _isScheduled = value;
                });
              },
              activeColor: const Color(0xFF4F46E5),
            ),
            
            if (_isScheduled) ...[
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Scheduled Date & Time', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  '${_scheduledDate.day}/${_scheduledDate.month}/${_scheduledDate.year} ${_scheduledDate.hour}:${_scheduledDate.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: const Icon(Icons.calendar_today, color: Color(0xFF4F46E5)),
                onTap: _selectDateTime,
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Send Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sendNotification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Send Notification',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentNotifications() {
    return Card(
      elevation: 6,
      shadowColor: const Color(0xFF4F46E5).withOpacity(0.15),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF4F46E5).withOpacity(0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Notifications',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .orderBy('createdAt', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
                }
                
                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No notifications sent yet',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final title = (data['title'] ?? '').toString();
                    final message = (data['message'] ?? '').toString();
                    final type = (data['type'] ?? 'general').toString();
                    final target = (data['target'] ?? 'all').toString();
                    final createdAt = data['createdAt'] as Timestamp?;
                    final isScheduled = data['isScheduled'] == true;
                    final scheduledFor = data['scheduledFor'] as Timestamp?;
                    final status = (data['status'] ?? 'sent').toString();
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B1B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(status),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  type.replaceAll('_', ' ').toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF4F46E5),
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  target.replaceAll('_', ' ').toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatDate(createdAt?.toDate() ?? DateTime.now()),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'sent':
        return const Color(0xFF10B981);
      case 'scheduled':
        return const Color(0xFFF59E0B);
      case 'failed':
        return const Color(0xFFE53935);
      default:
        return const Color(0xFF4F46E5);
    }
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4F46E5),
              onPrimary: Colors.white,
              surface: Color(0xFF1B1B1B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_scheduledDate),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF4F46E5),
                onPrimary: Colors.white,
                surface: Color(0xFF1B1B1B),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _scheduledDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _sendNotification() async {
    if (_titleController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Color(0xFFE53935),
        ),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final title = _titleController.text.trim();
      final message = _messageController.text.trim();

      // Check for duplicate notification (same title + message in last 1 hour)
      if (!_isScheduled) {
        final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
        final duplicateCheck = await FirebaseFirestore.instance
            .collection('notifications')
            .where('title', isEqualTo: title)
            .where('message', isEqualTo: message)
            .where('createdBy', isEqualTo: user.uid)
            .where('createdAt', isGreaterThan: Timestamp.fromDate(oneHourAgo))
            .limit(1)
            .get();

        if (duplicateCheck.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Similar notification was sent recently. Please wait before sending again.'),
              backgroundColor: Color(0xFFFF9800),
            ),
          );
          return;
        }
      }

      final notificationData = {
        'title': title,
        'body': message,
        'message': message,
        'type': _selectedType,
        'target': _selectedTarget,
        'isScheduled': _isScheduled,
        'status': _isScheduled ? 'scheduled' : 'sent',
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'priority': 'normal',
        if (_isScheduled) 'scheduledFor': Timestamp.fromDate(_scheduledDate),
      };

      await FirebaseFirestore.instance
          .collection('notifications')
          .add(notificationData);

      // FCM sending will be handled by cloud function or scheduled job
      // For now, notification is saved to Firestore for processing

      // Clear form
      _titleController.clear();
      _messageController.clear();
      setState(() {
        _selectedType = 'general';
        _selectedTarget = 'all';
        _isScheduled = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification sent successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send notification: ${e.toString()}'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
