import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';

class UpdatesScreen extends StatefulWidget {
  final String role;

  const UpdatesScreen({
    super.key,
    required this.role,
  });

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  bool _isLoading = false;
  bool _isAdminMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: _isAdminMode ? 'Admin Updates' : 'Updates & Announcements',
        actions: [
          if (widget.role.toLowerCase() == 'admin') ...[
            if (_isAdminMode) ...[
              IconButton(
                onPressed: _addAnnouncement,
                icon: const Icon(Icons.add, color: Colors.white70),
                tooltip: 'Add Announcement',
              ),
            ],
            IconButton(
              onPressed: _toggleAdminMode,
              icon: Icon(
                _isAdminMode ? Icons.visibility : Icons.admin_panel_settings,
                color: _isAdminMode ? Colors.orange : Colors.white70,
              ),
              tooltip: _isAdminMode ? 'Exit Admin Mode' : 'Admin Mode',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            )
          : RefreshIndicator(
              onRefresh: _refreshUpdates,
              color: Colors.white70,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('announcements')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white70),
                    );
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState();
                  }

                  final announcements = snapshot.data?.docs ?? [];
                  
                  if (announcements.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: announcements.length,
                    itemBuilder: (context, index) {
                      final doc = announcements[index];
                      final data = doc.data();
                      return _buildAnnouncementCard(
                        doc.id,
                        data,
                        isAdminMode: _isAdminMode,
                      );
                    },
                  );
                },
              ),
            ),
    );
  }

  Widget _buildAnnouncementCard(
    String docId,
    Map<String, dynamic> data, {
    required bool isAdminMode,
  }) {
    final title = data['title'] ?? 'Untitled';
    final description = data['description'] ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final iconType = data['iconType'] ?? 'event';
    final isImportant = data['isImportant'] ?? false;
    final colorHex = data['colorHex'] ?? '0xFF4F46E5';
    
    final timeAgo = _getTimeAgo(createdAt);
    final icon = _getIconFromType(iconType);
    final accentColor = Color(int.parse(colorHex.toString()));

    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
      ),
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
                    color: accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isImportant)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'IMPORTANT',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isAdminMode) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                    onSelected: (value) => _handleAnnouncementAction(value, docId, data),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Error Loading Updates',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Failed to load announcements',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshUpdates,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.campaign_outlined, color: Colors.white70, size: 64),
          const SizedBox(height: 16),
          const Text(
            'No Announcements Yet',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check back later for updates',
            style: TextStyle(color: Colors.white70),
          ),
          if (widget.role.toLowerCase() == 'admin') ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addAnnouncement,
              icon: const Icon(Icons.add),
              label: const Text('Add First Announcement'),
            ),
          ],
        ],
      ),
    );
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    final now = DateTime.now();
    final createdAt = timestamp.toDate();
    final difference = now.difference(createdAt);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${(difference.inDays / 7).floor()} weeks ago';
    }
  }

  IconData _getIconFromType(String iconType) {
    switch (iconType) {
      case 'event':
        return Icons.event;
      case 'calendar':
        return Icons.calendar_today;
      case 'person':
        return Icons.person_add;
      case 'payment':
        return Icons.payment;
      case 'home':
        return Icons.home_repair_service;
      case 'warning':
        return Icons.warning;
      case 'info':
        return Icons.info;
      default:
        return Icons.campaign;
    }
  }

  void _toggleAdminMode() {
    setState(() {
      _isAdminMode = !_isAdminMode;
    });
  }

  void _addAnnouncement() {
    showDialog(
      context: context,
      builder: (context) => _AnnouncementDialog(
        onSave: (title, description, iconType, colorHex, isImportant) async {
          try {
            await FirebaseFirestore.instance.collection('announcements').add({
              'title': title,
              'description': description,
              'iconType': iconType,
              'colorHex': colorHex,
              'isImportant': isImportant,
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': FirebaseAuth.instance.currentUser?.uid,
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Announcement added successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error adding announcement: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _handleAnnouncementAction(String action, String docId, Map<String, dynamic> data) {
    switch (action) {
      case 'edit':
        _editAnnouncement(docId, data);
        break;
      case 'delete':
        _deleteAnnouncement(docId);
        break;
    }
  }

  void _editAnnouncement(String docId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => _AnnouncementDialog(
        initialTitle: data['title'] ?? '',
        initialDescription: data['description'] ?? '',
        initialIconType: data['iconType'] ?? 'event',
        initialColorHex: data['colorHex'] ?? '0xFF4F46E5',
        initialIsImportant: data['isImportant'] ?? false,
        onSave: (title, description, iconType, colorHex, isImportant) async {
          try {
            await FirebaseFirestore.instance.collection('announcements').doc(docId).update({
              'title': title,
              'description': description,
              'iconType': iconType,
              'colorHex': colorHex,
              'isImportant': isImportant,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Announcement updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error updating announcement: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _deleteAnnouncement(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text(
          'Delete Announcement',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this announcement?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('announcements').doc(docId).delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Announcement deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting announcement: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _refreshUpdates() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate refresh delay
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });
  }
}

class _AnnouncementDialog extends StatefulWidget {
  final String? initialTitle;
  final String? initialDescription;
  final String? initialIconType;
  final String? initialColorHex;
  final bool? initialIsImportant;
  final Function(String, String, String, String, bool) onSave;

  const _AnnouncementDialog({
    this.initialTitle,
    this.initialDescription,
    this.initialIconType,
    this.initialColorHex,
    this.initialIsImportant,
    required this.onSave,
  });

  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedIconType = 'event';
  String _selectedColorHex = '0xFF4F46E5';
  bool _isImportant = false;

  final List<Map<String, dynamic>> _iconOptions = [
    {'type': 'event', 'icon': Icons.event, 'label': 'Event'},
    {'type': 'calendar', 'icon': Icons.calendar_today, 'label': 'Calendar'},
    {'type': 'person', 'icon': Icons.person_add, 'label': 'Person'},
    {'type': 'payment', 'icon': Icons.payment, 'label': 'Payment'},
    {'type': 'home', 'icon': Icons.home_repair_service, 'label': 'Home'},
    {'type': 'warning', 'icon': Icons.warning, 'label': 'Warning'},
    {'type': 'info', 'icon': Icons.info, 'label': 'Info'},
  ];

  final List<Map<String, dynamic>> _colorOptions = [
    {'hex': '0xFF4F46E5', 'color': Color(0xFF4F46E5), 'label': 'Purple'},
    {'hex': '0xFF10B981', 'color': Color(0xFF10B981), 'label': 'Green'},
    {'hex': '0xFFFF9800', 'color': Color(0xFFFF9800), 'label': 'Orange'},
    {'hex': '0xFF42A5F5', 'color': Color(0xFF42A5F5), 'label': 'Blue'},
    {'hex': '0xFFE53935', 'color': Color(0xFFE53935), 'label': 'Red'},
    {'hex': '0xFF9C27B0', 'color': Color(0xFF9C27B0), 'label': 'Pink'},
  ];

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.initialTitle ?? '';
    _descriptionController.text = widget.initialDescription ?? '';
    _selectedIconType = widget.initialIconType ?? 'event';
    _selectedColorHex = widget.initialColorHex ?? '0xFF4F46E5';
    _isImportant = widget.initialIsImportant ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: Text(
        widget.initialTitle != null ? 'Edit Announcement' : 'Add Announcement',
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.trim().isEmpty == true ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) => value?.trim().isEmpty == true ? 'Description is required' : null,
              ),
              const SizedBox(height: 16),
              const Text('Icon Type', style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _iconOptions.map((option) {
                  final isSelected = _selectedIconType == option['type'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIconType = option['type']),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey,
                        ),
                      ),
                      child: Icon(
                        option['icon'] as IconData,
                        color: isSelected ? Colors.blue : Colors.white70,
                        size: 20,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Color', style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _colorOptions.map((option) {
                  final isSelected = _selectedColorHex == option['hex'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorHex = option['hex']),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: option['color'] as Color,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isImportant,
                    onChanged: (value) => setState(() => _isImportant = value ?? false),
                    activeColor: Colors.red,
                  ),
                  const Text('Mark as Important', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(widget.initialTitle != null ? 'Update' : 'Add'),
        ),
      ],
    );
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      widget.onSave(
        _titleController.text.trim(),
        _descriptionController.text.trim(),
        _selectedIconType,
        _selectedColorHex,
        _isImportant,
      );
      Navigator.pop(context);
    }
  }
}