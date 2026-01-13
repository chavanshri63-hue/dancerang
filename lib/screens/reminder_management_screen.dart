import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';

class ReminderManagementScreen extends StatefulWidget {
  const ReminderManagementScreen({super.key});

  @override
  State<ReminderManagementScreen> createState() => _ReminderManagementScreenState();
}

class _ReminderManagementScreenState extends State<ReminderManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reminders = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _selectedType = 'payment';
  String _selectedTarget = 'all';

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('reminders')
          .where('createdBy', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> reminders = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        reminders.add({
          'id': doc.id,
          'title': data['title'] ?? '',
          'message': data['message'] ?? '',
          'type': data['type'] ?? 'general',
          'target': data['target'] ?? 'all',
          'scheduledFor': data['scheduledFor'],
          'status': data['status'] ?? 'pending',
          'createdAt': data['createdAt'],
        });
      }

      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading reminders: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'Reminder Management',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateReminderDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Create Reminder Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showCreateReminderDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Create New Reminder'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Reminders List
                  _buildRemindersList(),
                ],
              ),
            ),
    );
  }

  Widget _buildRemindersList() {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Reminders',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (_reminders.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No reminders created yet',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _reminders.length,
                itemBuilder: (context, index) {
                  final reminder = _reminders[index];
                  return _buildReminderItem(reminder);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderItem(Map<String, dynamic> reminder) {
    final status = reminder['status'] as String;
    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'sent':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        break;
      case 'scheduled':
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.schedule;
        break;
      case 'failed':
        statusColor = const Color(0xFFE53935);
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.white70;
        statusIcon = Icons.help;
    }

    final scheduledFor = reminder['scheduledFor'] as Timestamp?;
    final scheduledDate = scheduledFor?.toDate() ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reminder['title'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleReminderAction(value, reminder),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                  child: const Icon(Icons.more_vert, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reminder['message'],
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.category, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${reminder['type']} • ${reminder['target']}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                Icon(Icons.schedule, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Create Reminder', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Reminder Title',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Reminder Message',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Reminder Type',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: const [
                  DropdownMenuItem(value: 'payment', child: Text('Payment')),
                  DropdownMenuItem(value: 'class', child: Text('Class')),
                  DropdownMenuItem(value: 'general', child: Text('General')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedTarget,
                decoration: const InputDecoration(
                  labelText: 'Target Audience',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Students')),
                  DropdownMenuItem(value: 'specific', child: Text('Specific Students')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedTarget = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
                          });
                        }
                      },
                      child: Text(
                        _selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            : 'Select Date',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            _selectedTime = time;
                          });
                        }
                      },
                      child: Text(
                        _selectedTime != null
                            ? '${_selectedTime!.hour}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                            : 'Select Time',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: _createReminder,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _createReminder() async {
    if (_titleController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final scheduledDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      await FirebaseFirestore.instance.collection('reminders').add({
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'type': _selectedType,
        'target': _selectedTarget,
        'scheduledFor': Timestamp.fromDate(scheduledDateTime),
        'status': 'scheduled',
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Clear form
      _titleController.clear();
      _messageController.clear();
      setState(() {
        _selectedDate = null;
        _selectedTime = null;
        _selectedType = 'payment';
        _selectedTarget = 'all';
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _loadReminders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating reminder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleReminderAction(String action, Map<String, dynamic> reminder) {
    switch (action) {
      case 'edit':
        _showEditReminderDialog(reminder);
        break;
      case 'delete':
        _deleteReminder(reminder['id']);
        break;
    }
  }

  void _showEditReminderDialog(Map<String, dynamic> reminder) {
    // Populate controllers with existing data
    _titleController.text = reminder['title'] ?? '';
    _messageController.text = reminder['message'] ?? '';
    _selectedType = reminder['type'] ?? 'payment';
    _selectedTarget = reminder['target'] ?? 'all';
    
    // Parse scheduled date and time
    final scheduledFor = (reminder['scheduledFor'] as Timestamp?)?.toDate();
    if (scheduledFor != null) {
      _selectedDate = scheduledFor;
      _selectedTime = TimeOfDay.fromDateTime(scheduledFor);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Edit Reminder', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Reminder Title',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE53935)),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Reminder Message',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE53935)),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Reminder Type',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE53935)),
                  ),
                ),
                dropdownColor: const Color(0xFF1B1B1B),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'payment', child: Text('Payment')),
                  DropdownMenuItem(value: 'class', child: Text('Class')),
                  DropdownMenuItem(value: 'general', child: Text('General')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedTarget,
                decoration: const InputDecoration(
                  labelText: 'Target Audience',
                  labelStyle: TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE53935)),
                  ),
                ),
                dropdownColor: const Color(0xFF1B1B1B),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Students')),
                  DropdownMenuItem(value: 'specific', child: Text('Specific Students')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedTarget = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
                          });
                        }
                      },
                      child: Text(
                        _selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            : 'Select Date',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            _selectedTime = time;
                          });
                        }
                      },
                      child: Text(
                        _selectedTime != null
                            ? '${_selectedTime!.hour}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                            : 'Select Time',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _titleController.clear();
              _messageController.clear();
              setState(() {
                _selectedDate = null;
                _selectedTime = null;
                _selectedType = 'payment';
                _selectedTarget = 'all';
              });
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => _updateReminder(reminder['id']),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateReminder(String reminderId) async {
    if (_titleController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time')),
      );
      return;
    }

    try {
      final scheduledDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      await FirebaseFirestore.instance.collection('reminders').doc(reminderId).update({
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'type': _selectedType,
        'target': _selectedTarget,
        'scheduledFor': Timestamp.fromDate(scheduledDateTime),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Clear form
      _titleController.clear();
      _messageController.clear();
      setState(() {
        _selectedDate = null;
        _selectedTime = null;
        _selectedType = 'payment';
        _selectedTarget = 'all';
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _loadReminders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating reminder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteReminder(String reminderId) async {
    try {
      await FirebaseFirestore.instance.collection('reminders').doc(reminderId).delete();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadReminders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting reminder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
