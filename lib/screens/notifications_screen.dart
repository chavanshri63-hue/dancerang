import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../widgets/glassmorphism_app_bar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationData> _notifications = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _notificationsSubscription;

  @override
  void initState() {
    super.initState();
    _setupNotificationsListener();
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  void _setupNotificationsListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _notifications = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Listen to real-time updates
    _notificationsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final notifications = snapshot.docs.map((doc) {
        final data = doc.data();
        return NotificationData(
          id: doc.id,
          title: data['title'] ?? 'Notification',
          message: data['body'] ?? data['message'] ?? '',
          timestamp: data['createdAt']?.toDate() ?? DateTime.now(),
          isRead: data['read'] ?? data['isRead'] ?? false,
          type: _parseNotificationType(data['type'] ?? 'general'),
          priority: _parseNotificationPriority(data['priority'] ?? 'normal'),
          sentTo: data['sentTo'],
        );
      }).toList();

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    }, onError: (error) {
      setState(() {
        _notifications = [];
        _isLoading = false;
      });
    });
  }

  Future<void> _refreshNotifications() async {
    // Cancel existing subscription and re-setup
    _notificationsSubscription?.cancel();
    _setupNotificationsListener();
  }

  /// Mark notification as read
  Future<void> _markAsRead(String notificationId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});

      // Update local state
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = NotificationData(
            id: _notifications[index].id,
            title: _notifications[index].title,
            message: _notifications[index].message,
            timestamp: _notifications[index].timestamp,
            isRead: true,
            type: _notifications[index].type,
            priority: _notifications[index].priority,
            sentTo: _notifications[index].sentTo,
          );
        }
      });
    } catch (e) {
    }
  }

  /// Mark all notifications as read
  Future<void> _markAllAsRead() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final notification in _notifications.where((n) => !n.isRead)) {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .doc(notification.id);
        batch.update(docRef, {'read': true});
      }
      await batch.commit();

      // Update local state
      setState(() {
        _notifications = _notifications.map((n) => NotificationData(
          id: n.id,
          title: n.title,
          message: n.message,
          timestamp: n.timestamp,
          isRead: true,
          type: n.type,
          priority: n.priority,
          sentTo: n.sentTo,
        )).toList();
      });
    } catch (e) {
    }
  }

  NotificationType _parseNotificationType(String type) {
    switch (type.toLowerCase()) {
      case 'class':
      case 'workshop':
      case 'payment':
        return NotificationType.success;
      case 'system':
        return NotificationType.info;
      case 'warning':
        return NotificationType.warning;
      case 'error':
        return NotificationType.error;
      default:
        return NotificationType.info;
    }
  }

  NotificationPriority _parseNotificationPriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return NotificationPriority.high;
      case 'medium':
        return NotificationPriority.medium;
      case 'low':
        return NotificationPriority.low;
      default:
        return NotificationPriority.medium;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'Notifications',
        onLeadingPressed: () => Navigator.pop(context),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            IconButton(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, color: Colors.white70),
              tooltip: 'Mark all as read',
            ),
        ],
      ),
      body: _buildReceivedNotificationsTab(),
    );
  }

  Widget _buildReceivedNotificationsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white70,
        ),
      );
    }

    if (_notifications.isEmpty) {
      return _buildEmptyState(
        icon: Icons.notifications_outlined,
        title: 'No Notifications',
        subtitle: 'You don\'t have any notifications yet',
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      color: const Color(0xFFE53935),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationCard(notification, isReceived: true);
        },
      ),
    );
  }

  // Removed sent tab – screen now shows only received notifications

  Widget _buildNotificationCard(NotificationData notification, {required bool isReceived}) {
    return Card(
      elevation: 4,
      shadowColor: _getNotificationColor(notification.type).withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getNotificationColor(notification.type).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isReceived && !notification.isRead) {
            _markAsRead(notification.id);
          }
          _viewNotificationDetails(notification);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getNotificationColor(notification.type).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getNotificationIcon(notification.type),
                      color: _getNotificationColor(notification.type),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            color: const Color(0xFFF9FAFB),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTimestamp(notification.timestamp),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!notification.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white70,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                notification.message,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (notification.sentTo != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE53935).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'To: ${notification.sentTo}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildPriorityChip(notification.priority),
                  const Spacer(),
                  if (isReceived && !notification.isRead)
                    TextButton.icon(
                      onPressed: () => _markAsRead(notification.id),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Mark as Read'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFE53935),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChip(NotificationPriority priority) {
    Color color;
    String label;
    
    switch (priority) {
      case NotificationPriority.high:
        color = const Color(0xFFEF4444);
        label = 'High';
        break;
      case NotificationPriority.medium:
        color = const Color(0xFFFF9800);
        label = 'Medium';
        break;
      case NotificationPriority.low:
        color = const Color(0xFF10B981);
        label = 'Low';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 64,
              color: const Color(0xFFE53935).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFF9FAFB),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return const Color(0xFF10B981);
      case NotificationType.warning:
        return const Color(0xFFFF9800);
      case NotificationType.error:
        return const Color(0xFFEF4444);
      case NotificationType.info:
        return const Color(0xFF4F46E5);
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.error:
        return Icons.error;
      case NotificationType.info:
        return Icons.info;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  // Removed manual send action from this screen

  void _viewNotificationDetails(NotificationData notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          notification.title,
          style: const TextStyle(color: Color(0xFFF9FAFB)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.message,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              'Time: ${_formatTimestamp(notification.timestamp)}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (notification.sentTo != null)
              Text(
                'To: ${notification.sentTo}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

}

class NotificationData {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  bool isRead;
  final NotificationPriority priority;
  final String? sentTo;

  NotificationData({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    required this.isRead,
    required this.priority,
    this.sentTo,
  });
}

enum NotificationType {
  success,
  warning,
  error,
  info,
}

enum NotificationPriority {
  high,
  medium,
  low,
}
