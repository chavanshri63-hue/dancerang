import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/glassmorphism_app_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/class_model.dart';
import '../utils/error_handler.dart';
import '../models/package_model.dart';
import '../services/dance_styles_service.dart';
import '../services/branches_service.dart';
import '../services/event_controller.dart';

class AdminClassesManagementScreen extends StatefulWidget {
  const AdminClassesManagementScreen({super.key});

  @override
  State<AdminClassesManagementScreen> createState() => _AdminClassesManagementScreenState();
}

class _AdminClassesManagementScreenState extends State<AdminClassesManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _categoryFilter = 'all';
  String _levelFilter = 'all';
  List<String> _availableCategories = [];
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final danceStyles = await ClassStylesService.getAllStyles();
      _availableCategories = danceStyles.map((style) => style.name).toList();
      // Remove duplicates and ensure unique values
      _availableCategories = _availableCategories.toSet().toList();
      if (mounted) setState(() {});
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'loading categories');
      _availableCategories = ['hiphop', 'bollywood', 'contemporary', 'jazz', 'ballet', 'salsa'];
      if (mounted) setState(() {});
    }
  }


  Stream<QuerySnapshot<Map<String, dynamic>>> _getClassesStream() {
    Query<Map<String, dynamic>> query = _firestore
        .collection('classes');

    if (_categoryFilter != 'all') {
      query = query.where('category', isEqualTo: _categoryFilter);
    }
    if (_levelFilter != 'all') {
      query = query.where('level', isEqualTo: _levelFilter);
    }
    
    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'Classes Management',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Class'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        color: const Color(0xFFE53935),
        child: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _getClassesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white70));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                docs.forEach((doc) {
                  final data = doc.data();
                });
                
                final filtered = docs.where((d) {
                  if (_searchController.text.trim().isEmpty) return true;
                  final data = d.data();
                  final q = _searchController.text.toLowerCase();
                  return (data['name'] ?? '').toString().toLowerCase().contains(q) ||
                         (data['instructor'] ?? '').toString().toLowerCase().contains(q) ||
                         (data['studio'] ?? '').toString().toLowerCase().contains(q);
                }).toList();

                
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No classes found', style: TextStyle(color: Colors.white54)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data();
                    final model = DanceClass.fromMap({
                      ...data,
                      'id': doc.id,
                    });
                    return _buildClassCard(model);
                  },
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final categories = ['all', ..._availableCategories];
    const levels = ['all', 'Beginner', 'Intermediate', 'Advanced'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by name/instructor/studio',
                filled: true,
                fillColor: const Color(0xFF1B1B1B),
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF262626)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: DropdownButton<String>(
                value: _categoryFilter,
                dropdownColor: const Color(0xFF1B1B1B),
                items: categories
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e == 'all' ? 'All' : e,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() => _categoryFilter = v ?? 'all');
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: DropdownButton<String>(
                value: _levelFilter,
                dropdownColor: const Color(0xFF1B1B1B),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'Beginner', child: Text('Beginner', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'Intermediate', child: Text('Intermediate', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'Advanced', child: Text('Advanced', style: TextStyle(color: Colors.white))),
                ],
                onChanged: (v) {
                  setState(() => _levelFilter = v ?? 'all');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(DanceClass c) {
    return Card(
      elevation: 6,
      color: const Color(0xFF1B1B1B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF262626)),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${c.instructor} • ${c.level} • ${c.category}\n${c.formattedDate} ${c.formattedTime} • ${c.studio}\nAvailable Spots: ${c.availableSpotsCount}',
            style: const TextStyle(color: Colors.white70, height: 1.3),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Manage Packages',
              onPressed: () => _openPackagesDialog(c),
              icon: const Icon(Icons.card_giftcard, color: Colors.orange),
            ),
            IconButton(
              tooltip: 'Edit',
              onPressed: () => _openEditDialog(c),
              icon: const Icon(Icons.edit, color: Colors.white70),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(c),
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateDialog() async {
    await showDialog(
      context: context,
      builder: (context) => _ClassEditorDialog(
        onSave: (payload) async {
          try {
            final docRef = await _firestore.collection('classes').add(payload);
            
            // Send notification about new class
            try {
              await _sendNewClassNotification(payload, docRef.id);
            } catch (e, stackTrace) {
              ErrorHandler.handleError(e, stackTrace, context: 'sending new class notification');
            }
            
            if (mounted) Navigator.pop(context);
          } catch (e, stackTrace) {
            ErrorHandler.handleError(e, stackTrace, context: 'creating class');
          }
        },
      ),
    );
  }

  Future<void> _openEditDialog(DanceClass model) async {
    await showDialog(
      context: context,
      builder: (context) => _ClassEditorDialog(
        initial: model,
        onSave: (payload) async {
          try {
            await _firestore.collection('classes').doc(model.id).update(payload);
            // Emit class updated event
            EventController().emitClassUpdated(model.id, payload);
            if (mounted) Navigator.pop(context);
          } catch (e, stackTrace) {
            ErrorHandler.handleError(e, stackTrace, context: 'updating class');
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(DanceClass model) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Class', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "${model.name}"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await _firestore.collection('classes').doc(model.id).delete();
      // Emit class deleted event
      EventController().emitClassDeleted(model.id);
    }
  }

  Future<void> _openPackagesDialog(DanceClass danceClass) async {
    await showDialog(
      context: context,
      builder: (context) => _PackagesManagementDialog(
        danceClass: danceClass,
        onSave: (packages) async {
          try {
            await _firestore.collection('classes').doc(danceClass.id).update({
              'packages': packages.map((p) => p.toMap()).toList(),
            });
            // Emit class updated event
            EventController().emitClassUpdated(danceClass.id, {'packages': packages.map((p) => p.toMap()).toList()});
            if (mounted) {
              Navigator.pop(context);
              setState(() {}); // Refresh the UI to show updated data
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Packages updated successfully!'),
                  backgroundColor: Color(0xFF10B981),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } catch (e, stackTrace) {
            ErrorHandler.handleError(e, stackTrace, context: 'updating packages');
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update packages. Please try again.'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _sendNewClassNotification(Map<String, dynamic> classData, String classId) async {
    try {
      String dateTimeStr = 'TBA';
      if (classData['dateTime'] != null) {
        if (classData['dateTime'] is Timestamp) {
          final date = (classData['dateTime'] as Timestamp).toDate();
          dateTimeStr = '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        } else if (classData['dateTime'] is String) {
          dateTimeStr = classData['dateTime'] as String;
        }
      } else if (classData['days'] != null && classData['startTime'] != null) {
        final days = (classData['days'] as List).join(', ');
        dateTimeStr = '$days ${classData['startTime']}';
      }

      final className = classData['name'] as String? ?? 'New Class';
      final instructor = classData['instructor'] as String? ?? classData['instructorName'] as String? ?? 'Instructor';

      await _firestore.collection('notifications').add({
        'title': '🆕 New Class Available!',
        'body': '"$className" with $instructor - $dateTimeStr',
        'message': '"$className" with $instructor - $dateTimeStr',
        'type': 'new_class',
        'priority': 'high',
        'target': 'students',
        'isScheduled': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'classId': classId,
          'className': className,
          'instructor': instructor,
        },
      });
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'sending new class notification');
    }
  }
}

class _ClassEditorDialog extends StatefulWidget {
  final DanceClass? initial;
  final Future<void> Function(Map<String, dynamic> payload) onSave;
  const _ClassEditorDialog({this.initial, required this.onSave});

  @override
  State<_ClassEditorDialog> createState() => _ClassEditorDialogState();
}

class _ClassEditorDialogState extends State<_ClassEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _instructor = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _spots = TextEditingController();
  final TextEditingController _imageUrl = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _duration = TextEditingController(text: '60 minutes');
  final TextEditingController _numberOfSessions = TextEditingController();
  String _category = 'hiphop';
  String _level = 'Beginner';
  String _selectedBranch = '';
  bool _isAvailable = true;
  bool _uploading = false;
  List<String> _availableCategories = [];
  List<String> _branches = [];
  
  // Days and time selection
  List<String> _selectedDays = [];
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 30);
  final _days = const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadBranches();
    final init = widget.initial;
    if (init != null) {
      _name.text = init.name;
      _instructor.text = init.instructor;
      _price.text = init.price;
      _selectedBranch = init.studio;
      _spots.text = init.availableSpots?.toString() ?? '20';
      _imageUrl.text = init.imageUrl;
      _description.text = init.description;
      _duration.text = init.duration;
      _numberOfSessions.text = init.numberOfSessions?.toString() ?? '';
      _category = _normalizeCategory(init.category);
      _level = init.level;
      _isAvailable = init.isAvailable;
      
      // Load days and time from existing class data
      // Note: This assumes the class data has been migrated to use days/startTime/endTime
      // For now, we'll use default values for existing classes
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _instructor.dispose();
    _price.dispose();
    _spots.dispose();
    _imageUrl.dispose();
    _description.dispose();
    _duration.dispose();
    _numberOfSessions.dispose();
    super.dispose();
  }

  Widget _buildDaysAndTimeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Days',
          style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _days.map((day) {
            final isSelected = _selectedDays.contains(day);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedDays.remove(day);
                  } else {
                    _selectedDays.add(day);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE53935) : const Color(0xFF1B1B1B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFE53935) : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  day,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        
        // Time Selection
        Row(
          children: [
            Expanded(
              child: _buildTimeSelector(
                'Start Time',
                _startTime,
                (time) => setState(() => _startTime = time),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTimeSelector(
                'End Time',
                _endTime,
                (time) => setState(() => _endTime = time),
              ),
            ),
          ],
        ),
        
        // Validation message
        if (_selectedDays.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Please select at least one day',
              style: TextStyle(color: Color(0xFFE53935), fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildTimeSelector(String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return GestureDetector(
      onTap: () async {
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: time,
          builder: (context, child) => Theme(
            data: ThemeData.dark(),
            child: child!,
          ),
        );
        if (pickedTime != null) {
          onChanged(pickedTime);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.access_time, color: Color(0xFFE53935), size: 14),
                const SizedBox(width: 4),
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(isEdit ? 'Edit Class' : 'Add Class', style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _textField('Name', _name),
              _textField('Instructor', _instructor),
              _dropdownField('Category', _category, _availableCategories, (v) => setState(() => _category = v)),
              _dropdownField('Level', _level, ['Beginner','Intermediate','Advanced'], (v) => setState(() => _level = v)),
              _textField('Price', _price),
              _dropdownField('Branch', _selectedBranch, _branches, (v) => setState(() => _selectedBranch = v)),
              // Removed Available Spots input as requested
              const SizedBox.shrink(),
              // Remove raw URL entry; keep only upload button
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: _uploading ? null : _pickAndUploadImage,
                  icon: _uploading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload),
                  label: const Text('Upload Photo'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
                ),
              ),
              _textField('Duration', _duration),
              _textField('Number of Sessions', _numberOfSessions, keyboardType: TextInputType.number),
              _textField('Description', _description, maxLines: 3),
              const SizedBox(height: 12),
              _buildDaysAndTimeSelector(),
              SwitchListTile(
                value: _isAvailable,
                onChanged: (v) => setState(() => _isAvailable = v),
                title: const Text('Available', style: TextStyle(color: Colors.white)),
                contentPadding: EdgeInsets.zero,
                thumbColor: const WidgetStatePropertyAll(Color(0xFFE53935)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
          child: Text(isEdit ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  Widget _textField(String label, TextEditingController c, {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: const Color(0xFF1B1B1B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF262626)),
          ),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Required';
          if (label == 'Available Spots') {
            final spots = int.tryParse(v.trim());
            if (spots == null || spots <= 0) return 'Must be greater than 0';
          }
          return null;
        },
      ),
    );
  }

  Widget _dropdownField(String label, String value, List<String> items, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: const Color(0xFF1B1B1B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF262626)),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
            dropdownColor: const Color(0xFF1B1B1B),
            items: [
              ...items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white)))),
              if (label == 'Category')
                DropdownMenuItem(
                  value: 'ADD_NEW_STYLE',
                  child: Row(
                    children: [
                      const Icon(Icons.add, color: Color(0xFFE53935), size: 16),
                      const SizedBox(width: 8),
                      const Text('Add New Style', style: TextStyle(color: Color(0xFFE53935))),
                    ],
                  ),
                ),
              if (label == 'Branch')
                DropdownMenuItem(
                  value: 'ADD_NEW_BRANCH',
                  child: Row(
                    children: [
                      const Icon(Icons.add, color: Color(0xFFE53935), size: 16),
                      const SizedBox(width: 8),
                      const Text('Add New Branch', style: TextStyle(color: Color(0xFFE53935))),
                    ],
                  ),
                ),
            ],
            onChanged: (v) {
              if (v == 'ADD_NEW_STYLE') {
                _showAddStyleDialog();
              } else if (v == 'ADD_NEW_BRANCH') {
                _showAddBranchDialog();
              } else if (v != null) {
                onChanged(v);
              }
            },
          ),
        ),
      ),
    );
  }

  String _normalizeCategory(String c) {
    final s = c.trim().toLowerCase();
    if (s == 'hip hop' || s == 'hip-hop' || s == 'hiphop') return 'hiphop';
    if (s.contains('bolly')) return 'bollywood';
    if (s.contains('contemp')) return 'contemporary';
    if (s.contains('jazz')) return 'jazz';
    if (s.contains('ballet')) return 'ballet';
    if (s.contains('salsa')) return 'salsa';
    return s;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate days selection
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one day for the class'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedBranch.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a branch for the class'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Create a sample dateTime for the class (using today's date with the start time)
    final now = DateTime.now();
    final classDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _startTime.hour,
      _startTime.minute,
    );

    final payload = {
      'name': _name.text.trim(),
      'instructor': _instructor.text.trim(),
      'price': _price.text.trim(),
      'studio': _selectedBranch.trim(),
      'availableSpots': int.tryParse(_spots.text.trim()) ?? 20,
      'imageUrl': _imageUrl.text.trim(),
      'description': _description.text.trim(),
      'duration': _duration.text.trim(),
      'numberOfSessions': _numberOfSessions.text.trim().isNotEmpty ? int.tryParse(_numberOfSessions.text.trim()) : null,
      'category': _category,
      'level': _level,
      'days': _selectedDays, // Store selected days
      'startTime': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
      'endTime': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
      'dateTime': Timestamp.fromDate(classDateTime), // Add dateTime field for ordering
      'isAvailable': _isAvailable,
      'maxStudents': 20,
      'currentBookings': 0,
      'enrolledCount': 0,
      'participant_count': 0,
      'requirements': <String>[],
      'schedule': <String, dynamic>{},
      'packages': DefaultPackages.getDefaultPackages().map((p) => p.toMap()).toList(),
      // Live features
      'liveNotifications': true,
      'liveAttendance': true,
      'liveMetrics': true,
      'waitlistEnabled': true,
      'socialFeatures': true,
      'analyticsEnabled': true,
    };
    await widget.onSave(payload);
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;
      setState(() => _uploading = true);
      final storage = FirebaseStorage.instance;
      final String path = 'classes/images/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = storage.ref().child(path);
      await ref.putData(await file.readAsBytes());
      final url = await ref.getDownloadURL();
      setState(() {
        _imageUrl.text = url;
        _uploading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image uploaded'), behavior: SnackBarBehavior.floating));
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'uploading class image');
      setState(() => _uploading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image upload failed. Please check your connection and try again.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadCategories() async {
    try {
      final danceStyles = await ClassStylesService.getAllStyles();
      _availableCategories = danceStyles.map((style) => style.name).toList();
      // Remove duplicates and ensure unique values
      _availableCategories = _availableCategories.toSet().toList();
      if (mounted) setState(() {});
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'loading categories in editor');
      _availableCategories = ['hiphop', 'bollywood', 'contemporary', 'jazz', 'ballet', 'salsa'];
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadBranches() async {
    try {
      await BranchesService.initializeDefaultBranches();
      final branches = await BranchesService.getAllBranches();
      final seen = <String>{};
      _branches = branches
          .map((branch) => branch.name.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => e[0].toUpperCase() + e.substring(1))
          .where((e) => seen.add(e.toLowerCase()))
          .toList();
      final classSnapshot = await FirebaseFirestore.instance.collection('classes').get();
      for (final doc in classSnapshot.docs) {
        final studio = (doc.data()['studio'] ?? '').toString().trim();
        if (studio.isNotEmpty && seen.add(studio.toLowerCase())) {
          _branches.add(studio);
        }
      }
      if (_selectedBranch.isNotEmpty && !_branches.contains(_selectedBranch)) {
        _branches.add(_selectedBranch);
      }
      _branches.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (_selectedBranch.isEmpty && _branches.isNotEmpty) {
        _selectedBranch = _branches.first;
      }
      if (mounted) setState(() {});
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'loading branches');
      if (_selectedBranch.isNotEmpty && !_branches.contains(_selectedBranch)) {
        _branches = [_selectedBranch];
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _showAddStyleDialog() async {
    final TextEditingController styleController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Add New Dance Style', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: styleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Style Name',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF2B2B2B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF404040)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              final styleName = styleController.text.trim();
              if (styleName.isNotEmpty) {
                try {
                  final now = DateTime.now();
                  final newStyle = DanceStyle(
                    id: '', // Will be set by Firestore
                    name: styleName,
                    description: '',
                    icon: 'directions_run',
                    color: '#E53935',
                    isActive: true,
                    priority: 0,
                    createdAt: now,
                    updatedAt: now,
                  );
                  
                  await ClassStylesService.addStyle(newStyle);
                  // Reload categories and select the new style
                  await _loadCategories();
                  setState(() {
                    _category = styleName;
                  });
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Style "$styleName" added successfully!'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                } catch (e, stackTrace) {
                  ErrorHandler.handleError(e, stackTrace, context: 'adding dance style');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to add style. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Style'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddBranchDialog() async {
    final TextEditingController branchController = TextEditingController();

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Add New Branch', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: branchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Branch Name',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF2B2B2B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF404040)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              final branchName = branchController.text.trim();
              if (branchName.isNotEmpty) {
                try {
                  final now = DateTime.now();
                  final newBranch = Branch(
                    id: '',
                    name: branchName,
                    isActive: true,
                    priority: 0,
                    createdAt: now,
                    updatedAt: now,
                  );
                  await BranchesService.addBranch(newBranch);
                  await _loadBranches();
                  setState(() {
                    _selectedBranch = branchName;
                  });
                  if (mounted) Navigator.pop(context, true);
                } catch (e, stackTrace) {
                  ErrorHandler.handleError(e, stackTrace, context: 'adding branch');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to add branch. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Branch'),
          ),
        ],
      ),
    );
  }
}

// Packages Management Dialog
class _PackagesManagementDialog extends StatefulWidget {
  final DanceClass danceClass;
  final Future<void> Function(List<ClassPackage> packages) onSave;

  const _PackagesManagementDialog({
    required this.danceClass,
    required this.onSave,
  });

  @override
  State<_PackagesManagementDialog> createState() => _PackagesManagementDialogState();
}

class _PackagesManagementDialogState extends State<_PackagesManagementDialog> {
  late List<ClassPackage> _packages;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _packages = List.from(widget.danceClass.packages);
    if (_packages.isEmpty) {
      _packages = DefaultPackages.getDefaultPackages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          const Icon(Icons.card_giftcard, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Manage Packages - ${widget.danceClass.name}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            // Add Package Button
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _addPackage,
                icon: const Icon(Icons.add),
                label: const Text('Add Package'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Packages List
            Expanded(
              child: ListView.builder(
                itemCount: _packages.length,
                itemBuilder: (context, index) {
                  final package = _packages[index];
                  return _buildPackageCard(package, index);
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _savePackages,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Save Packages'),
                    if (_packages.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.save,
                          size: 16,
                          color: Color(0xFFE53935),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPackageCard(ClassPackage package, int index) {
    return Card(
      elevation: 4,
      color: const Color(0xFF2B2B2B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: package.isRecommended
            ? const BorderSide(color: Color(0xFFE53935), width: 2)
            : const BorderSide(color: Color(0xFF404040)),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: package.isRecommended ? const Color(0xFFE53935) : Colors.grey[700],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${package.classCount == -1 ? '∞' : package.classCount}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              package.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            if (package.isRecommended)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'RECOMMENDED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              package.description,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Wrap(
              children: [
                Text(
                  package.formattedPrice,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (package.hasDiscount) ...[
                  const SizedBox(width: 8),
                  Text(
                    package.formattedOriginalPrice,
                    style: const TextStyle(
                      color: Colors.white54,
                      decoration: TextDecoration.lineThrough,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    package.discountText,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: SizedBox(
          width: 70,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _editPackage(index),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white70, size: 14),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _deletePackage(index),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red[700],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addPackage() {
    _editPackage(-1); // -1 indicates new package
  }

  void _editPackage(int index) {
    final isNew = index == -1;
    final package = isNew ? null : _packages[index];
    
    showDialog(
      context: context,
      builder: (context) => _PackageEditorDialog(
        package: package,
        onSave: (editedPackage) {
          setState(() {
            if (isNew) {
              _packages.add(editedPackage);
            } else {
              _packages[index] = editedPackage;
            }
            // Sort by sortOrder
            _packages.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          });
        },
      ),
    );
  }

  void _deletePackage(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text('Delete Package', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${_packages[index].name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _packages.removeAt(index);
              });
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _savePackages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onSave(_packages);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Packages saved successfully!'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'saving packages');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save packages. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// Package Editor Dialog
class _PackageEditorDialog extends StatefulWidget {
  final ClassPackage? package;
  final Function(ClassPackage) onSave;

  const _PackageEditorDialog({
    this.package,
    required this.onSave,
  });

  @override
  State<_PackageEditorDialog> createState() => _PackageEditorDialogState();
}

class _PackageEditorDialogState extends State<_PackageEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _originalPriceController = TextEditingController();
  final TextEditingController _classCountController = TextEditingController();
  final TextEditingController _validForController = TextEditingController();
  final TextEditingController _featureController = TextEditingController();
  
  List<String> _features = [];
  bool _isRecommended = false;
  bool _isActive = true;
  int _sortOrder = 0;

  @override
  void initState() {
    super.initState();
    if (widget.package != null) {
      final p = widget.package!;
      _nameController.text = p.name;
      _descriptionController.text = p.description;
      _priceController.text = p.price;
      _originalPriceController.text = p.originalPrice ?? '';
      _classCountController.text = p.classCount == -1 ? 'unlimited' : p.classCount.toString();
      _validForController.text = p.validFor ?? '';
      _features = List.from(p.features);
      _isRecommended = p.isRecommended;
      _isActive = p.isActive;
      _sortOrder = p.sortOrder;
    } else {
      _classCountController.text = '1';
      _sortOrder = 100; // Default high sort order for new packages
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _classCountController.dispose();
    _validForController.dispose();
    _featureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.package != null;
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        isEdit ? 'Edit Package' : 'Add Package',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _textField('Package Name', _nameController),
                _textField('Description', _descriptionController, maxLines: 2),
                Row(
                  children: [
                    Expanded(child: _textField('Price', _priceController)),
                    const SizedBox(width: 8),
                    Expanded(child: _textField('Original Price (Optional)', _originalPriceController)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _textField('Class Count (or "unlimited")', _classCountController)),
                    const SizedBox(width: 8),
                    Expanded(child: _textField('Valid For (e.g., "1 month")', _validForController)),
                  ],
                ),
                _textField('Sort Order', TextEditingController(text: _sortOrder.toString())),
                
                // Features Section
                const Text(
                  'Features',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _textField('Add Feature', _featureController)),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addFeature,
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  children: _features.map((feature) => Chip(
                    label: Text(feature, style: const TextStyle(fontSize: 12)),
                    onDeleted: () => _removeFeature(feature),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  )).toList(),
                ),
                
                const SizedBox(height: 16),
                
                // Toggle switches
                SwitchListTile(
                  value: _isRecommended,
                  onChanged: (v) => setState(() => _isRecommended = v),
                  title: const Text('Recommended', style: TextStyle(color: Colors.white)),
                  thumbColor: const WidgetStatePropertyAll(Color(0xFFE53935)),
                ),
                SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text('Active', style: TextStyle(color: Colors.white)),
                  thumbColor: const WidgetStatePropertyAll(Color(0xFFE53935)),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
          ),
          child: Text(isEdit ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  Widget _textField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: const Color(0xFF2B2B2B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF404040)),
          ),
        ),
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
    );
  }

  void _addFeature() {
    final feature = _featureController.text.trim();
    if (feature.isNotEmpty && !_features.contains(feature)) {
      setState(() {
        _features.add(feature);
        _featureController.clear();
      });
    }
  }

  void _removeFeature(String feature) {
    setState(() {
      _features.remove(feature);
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    
    final classCount = _classCountController.text.toLowerCase() == 'unlimited' 
        ? -1 
        : int.tryParse(_classCountController.text) ?? 1;
    
    final package = ClassPackage(
      id: widget.package?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      price: _priceController.text.trim(),
      originalPrice: _originalPriceController.text.trim().isEmpty 
          ? null 
          : _originalPriceController.text.trim(),
      classCount: classCount,
      features: _features,
      isRecommended: _isRecommended,
      isActive: _isActive,
      sortOrder: _sortOrder,
      validFor: _validForController.text.trim().isEmpty 
          ? null 
          : _validForController.text.trim(),
    );
    
    widget.onSave(package);
    Navigator.pop(context);
  }
}


