import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/dance_styles_service.dart';
import '../services/event_controller.dart';
import '../services/live_notification_service.dart';

class AddEditClassScreen extends StatefulWidget {
  final String? classId;
  const AddEditClassScreen({super.key, this.classId});

  @override
  State<AddEditClassScreen> createState() => _AddEditClassScreenState();
}

class _AddEditClassScreenState extends State<AddEditClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _instructor = TextEditingController();
  final _price = TextEditingController();
  final _studio = TextEditingController();
  final _spot = TextEditingController();
  final _numberOfSessions = TextEditingController();
  String _level = 'Beginner';
  String _category = 'Bollywood';
  String _ageGroup = 'kids'; // 'kids' | 'adults'
  String _selectedFacultyId = '';
  String _selectedFacultyName = '';
  bool _isManualInstructorEntry = false;
  
  // Days and time selection
  List<String> _selectedDays = [];
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 30);

  final _levels = const ['Beginner', 'Intermediate', 'Advanced'];
  final _ageGroups = const ['kids', 'adults'];
  List<String> _categories = [];
  final _days = const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  bool _loading = false;
  List<Map<String, dynamic>> _facultyList = [];

  @override
  void initState() {
    super.initState();
    _loadFacultyList();
    _loadCategories();
    _checkCurrentUserRole();
  }

  @override
  void dispose() {
    _name.dispose();
    _instructor.dispose();
    _price.dispose();
    _studio.dispose();
    _spot.dispose();
    _numberOfSessions.dispose();
    super.dispose();
  }

  Future<void> _loadFacultyList() async {
    try {
      final facultySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Faculty')
          .get();
      
      
      setState(() {
        _facultyList = facultySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown Faculty',
          };
        }).toList();
      });
      
    } catch (e) {
    }
  }

  Future<void> _loadCategories() async {
    try {
      final danceStyles = await DanceStylesService.getAllStyles();
      // Extract names and normalize, trim, and dedupe case-insensitively
      final seen = <String>{};
      _categories = danceStyles
          .map((style) => style.name.trim())
          .where((e) => e.isNotEmpty)
          .map((e) => e[0].toUpperCase() + e.substring(1))
          .where((e) => seen.add(e.toLowerCase()))
          .toList();
      // Ensure a stable order
      _categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      // Ensure current selection is valid
      if (!_categories.contains(_category)) {
        _category = _categories.isNotEmpty ? _categories.first : 'Bollywood';
      }
      if (mounted) setState(() {});
    } catch (e) {
      // Fallback to default categories
      _categories = ['Bollywood', 'Hip Hop', 'Contemporary', 'Jazz', 'Ballet', 'Salsa'];
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
                  
                  await DanceStylesService.addStyle(newStyle);
                  // Reload categories and select the new style
                  await _loadCategories();
                  setState(() {
                    _category = styleName;
                  });
                  Navigator.pop(context, true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to add style: $e'),
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

  Future<void> _checkCurrentUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() ?? {};
          final role = userData['role']?.toString().toLowerCase();
          final userName = userData['name'] ?? 'Unknown';
          
          // If current user is faculty, auto-select themselves
          if (role?.toLowerCase() == 'faculty') {
            setState(() {
              _selectedFacultyId = user.uid;
              _selectedFacultyName = userName;
            });
          }
        }
      } catch (e) {
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B1B),
        foregroundColor: Colors.white,
        title: Text(widget.classId == null ? 'Add Class' : 'Edit Class'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(_name, 'Class Name', Icons.school, validator: (v)=> v==null||v.trim().isEmpty? 'Required': null),
              const SizedBox(height: 12),
              _instructorSelectionWidget(),
              const SizedBox(height: 12),
              _field(_price, 'Price (₹)', Icons.currency_rupee, keyboardType: TextInputType.number, validator: (v)=> v==null||v.trim().isEmpty? 'Required': null),
              const SizedBox(height: 12),
              _field(_studio, 'Studio', Icons.location_city, validator: (v)=> v==null||v.trim().isEmpty? 'Required': null),
              const SizedBox(height: 12),
              // Removed Available Spots field as requested
              const SizedBox.shrink(),
              const SizedBox(height: 12),
              _dropdown('Level', _levels, _level, (v)=> setState(()=> _level = v!)),
              const SizedBox(height: 12),
              _dropdown('Category', _categories, _category, (v)=> setState(()=> _category = v!)),
              const SizedBox(height: 12),
              _dropdown('Age Group', _ageGroups, _ageGroup, (v)=> setState(()=> _ageGroup = v!)),
              const SizedBox(height: 12),
              _field(_numberOfSessions, 'Number of Sessions', Icons.numbers, keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _daysAndTimeSelector(context),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading? null : _save,
                  icon: const Icon(Icons.save),
                  label: Text(widget.classId == null ? 'Create Class' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFE53935)),
        filled: true,
        fillColor: const Color(0xFF1B1B1B),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _dropdown(String label, List<String> items, String value, ValueChanged<String?> onChanged) {
    // Deduplicate exact duplicates to avoid DropdownButton assertion
    final unique = <String>{};
    final itemList = items.where((e) => unique.add(e)).toList();
    // Ensure the provided value exists
    final safeValue = itemList.contains(value) ? value : (itemList.isNotEmpty ? itemList.first : null);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFF1B1B1B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          isExpanded: true,
          dropdownColor: const Color(0xFF1B1B1B),
          style: const TextStyle(color: Colors.white),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFE53935)),
          items: [
            ...itemList.map((e)=> DropdownMenuItem(value: e, child: Text(e))),
            if (label == 'Category') 
              const DropdownMenuItem(
                value: 'ADD_NEW_STYLE',
                child: Row(
                  children: [
                    const Icon(Icons.add, color: Color(0xFFE53935), size: 16),
                    const SizedBox(width: 8),
                    const Text('Add New Style', style: TextStyle(color: Color(0xFFE53935))),
                  ],
                ),
              ),
          ],
          onChanged: (String? newValue) {
            if (newValue == 'ADD_NEW_STYLE') {
              _showAddStyleDialog();
            } else {
              onChanged(newValue);
            }
          },
        ),
      ),
    );
  }

  Widget _daysAndTimeSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Days Selection
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE53935) : const Color(0xFF1B1B1B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFE53935) : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  day,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        
        // Time Selection
        Row(
          children: [
            Expanded(
              child: _timeSelector(
                'Start Time',
                _startTime,
                (time) => setState(() => _startTime = time),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _timeSelector(
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

  Widget _timeSelector(String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return GestureDetector(
      onTap: () async {
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (pickedTime != null) {
          onChanged(pickedTime);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, color: Color(0xFFE53935), size: 18),
                const SizedBox(width: 8),
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
    
    setState(()=> _loading = true);
    try {
      // Create a sample dateTime for the class (using today's date with the start time)
      final now = DateTime.now();
      final classDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        _startTime.hour,
        _startTime.minute,
      );

      final data = {
        'name': _name.text.trim(),
        'instructor': _isManualInstructorEntry ? _instructor.text.trim() : _selectedFacultyId,
        'instructorName': _isManualInstructorEntry ? _instructor.text.trim() : _selectedFacultyName,
        'instructorId': _isManualInstructorEntry ? null : _selectedFacultyId,
        'isManualInstructor': _isManualInstructorEntry,
        'price': '₹${_price.text.trim()}',
        'studio': _studio.text.trim(),
        'availableSpots': int.tryParse(_spot.text.trim()) ?? 0,
        'level': _level,
        'category': _category,
          'ageGroup': _ageGroup,
        'numberOfSessions': _numberOfSessions.text.trim().isNotEmpty ? int.tryParse(_numberOfSessions.text.trim()) : null,
        'days': _selectedDays, // Store selected days
        'startTime': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        'endTime': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        'dateTime': Timestamp.fromDate(classDateTime), // Add dateTime field for ordering
        'isAvailable': true,
        'maxStudents': 20,
        'currentBookings': 0,
        'enrolledCount': 0, // Add enrolled count
        'imageUrl': '',
        'updated_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      };

      if (widget.classId == null) {
        final docRef = await FirebaseFirestore.instance.collection('classes').add(data);
        
        // Emit class added event
        EventController().emitClassAdded(docRef.id, data);
        
        // Notification is sent from admin_classes_management_screen.dart, no need to send here
      } else {
        await FirebaseFirestore.instance.collection('classes').doc(widget.classId).set(data, SetOptions(merge: true));
        // Emit class updated event
        EventController().emitClassUpdated(widget.classId!, data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save class. Please check your connection and try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(()=> _loading = false);
    }
  }

  Widget _instructorSelectionWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle between dropdown and manual entry
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isManualInstructorEntry = false;
                    _instructor.clear();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: !_isManualInstructorEntry ? const Color(0xFFE53935) : const Color(0xFF374151),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    border: Border.all(
                      color: !_isManualInstructorEntry ? const Color(0xFFE53935) : const Color(0xFF374151),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.list,
                        color: !_isManualInstructorEntry ? Colors.white : Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Select Faculty',
                        style: TextStyle(
                          color: !_isManualInstructorEntry ? Colors.white : Colors.white70,
                          fontWeight: !_isManualInstructorEntry ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isManualInstructorEntry = true;
                    _selectedFacultyId = '';
                    _selectedFacultyName = '';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _isManualInstructorEntry ? const Color(0xFFE53935) : const Color(0xFF374151),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    border: Border.all(
                      color: _isManualInstructorEntry ? const Color(0xFFE53935) : const Color(0xFF374151),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.edit,
                        color: _isManualInstructorEntry ? Colors.white : Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Enter Name',
                        style: TextStyle(
                          color: _isManualInstructorEntry ? Colors.white : Colors.white70,
                          fontWeight: _isManualInstructorEntry ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Show either dropdown or text field based on selection
        if (_isManualInstructorEntry)
          _field(
            _instructor, 
            'Instructor Name', 
            Icons.person, 
            validator: (v) => v == null || v.trim().isEmpty ? 'Please enter instructor name' : null
          )
        else
          _facultyDropdown(),
      ],
    );
  }

  Widget _facultyDropdown() {
    if (_facultyList.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF374151)),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.person, color: Colors.white70),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No faculty found. Switch to "Enter Name" to add manually.',
                  style: TextStyle(color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedFacultyId.isEmpty ? null : _selectedFacultyId,
        decoration: const InputDecoration(
          labelText: 'Instructor',
          labelStyle: TextStyle(color: Colors.white70),
          prefixIcon: Icon(Icons.person, color: Colors.white70),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        dropdownColor: const Color(0xFF1B1B1B),
        style: const TextStyle(color: Colors.white),
        hint: const Text(
          'Select Instructor',
          style: TextStyle(color: Colors.white70),
        ),
        items: _facultyList.map((faculty) {
          return DropdownMenuItem<String>(
            value: faculty['id'],
            child: Text(
              faculty['name']!,
              style: const TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
        onChanged: (String? value) {
          if (value != null) {
            final selectedFaculty = _facultyList.firstWhere((f) => f['id'] == value);
            setState(() {
              _selectedFacultyId = value;
              _selectedFacultyName = selectedFaculty['name']!;
            });
          }
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select an instructor';
          }
          return null;
        },
      ),
    );
  }
}


