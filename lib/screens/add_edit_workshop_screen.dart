import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/workshop_service.dart';
import '../widgets/glassmorphism_app_bar.dart';

class AddEditWorkshopScreen extends StatefulWidget {
  final AddEditWorkshopData? workshop; // null for add, AddEditWorkshopData for edit
  
  const AddEditWorkshopScreen({super.key, this.workshop});
  
  @override
  State<AddEditWorkshopScreen> createState() => _AddEditWorkshopScreenState();
}

class _AddEditWorkshopScreenState extends State<AddEditWorkshopScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _instructorController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  
  String _selectedCategory = 'Contemporary';
  String _selectedLevel = 'Beginner';
  String _selectedDuration = '2 hours';
  File? _selectedImage;
  String? _imageUrl;
  bool _isLoading = false;
  bool _isSaving = false;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    if (widget.workshop != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final workshop = widget.workshop!;
    _titleController.text = workshop.title;
    _instructorController.text = workshop.instructor;
    _dateController.text = workshop.date;
    _timeController.text = workshop.time;
    _priceController.text = workshop.price.toString();
    _descriptionController.text = workshop.description;
    _locationController.text = workshop.location;
    _maxParticipantsController.text = workshop.maxParticipants.toString();
    _selectedCategory = workshop.category;
    _selectedLevel = workshop.level;
    _selectedDuration = workshop.duration;
    _imageUrl = workshop.imageUrl;
    
    // Parse date and time from existing data
    _parseExistingDateTime();
  }

  void _parseExistingDateTime() {
    // Parse date from existing data
    try {
      final dateText = _dateController.text;
      if (dateText.isNotEmpty) {
        // Try to parse common date formats
        final now = DateTime.now();
        _selectedDate = now; // Default to current date if parsing fails
      }
    } catch (e) {
      _selectedDate = DateTime.now();
    }

    // Parse time from existing data
    try {
      final timeText = _timeController.text;
      if (timeText.isNotEmpty) {
        // Try to parse time like "6:00 PM - 8:00 PM"
        final parts = timeText.split(' - ');
        if (parts.length == 2) {
          _startTime = _parseTimeOfDay(parts[0].trim());
          _endTime = _parseTimeOfDay(parts[1].trim());
        }
      }
    } catch (e) {
      _startTime = const TimeOfDay(hour: 18, minute: 0); // 6:00 PM
      _endTime = const TimeOfDay(hour: 20, minute: 0); // 8:00 PM
    }
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final isPM = timeStr.toUpperCase().contains('PM');
      final timePart = timeStr.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = timePart.split(':');
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      
      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;
      
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return const TimeOfDay(hour: 18, minute: 0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructorController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.workshop != null;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: isEdit ? 'Edit Workshop' : 'Add Workshop',
        onLeadingPressed: () => Navigator.pop(context),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Section
                    _buildImageSection(),
                    const SizedBox(height: 24),
                    
                    // Basic Information
                    _buildSectionTitle('Basic Information'),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _titleController,
                      label: 'Workshop Title',
                      hint: 'Enter workshop title',
                      validator: (value) => value?.trim().isEmpty == true ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _instructorController,
                      label: 'Instructor Name',
                      hint: 'Enter instructor name',
                      validator: (value) => value?.trim().isEmpty == true ? 'Instructor name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateField(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTimeField(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _priceController,
                            label: 'Price (₹)',
                            hint: 'Enter price',
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value?.trim().isEmpty == true) return 'Price is required';
                              if (int.tryParse(value!) == null || int.parse(value) <= 0) {
                                return 'Enter valid price';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _maxParticipantsController,
                            label: 'Max Participants',
                            hint: 'Enter max participants',
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value?.trim().isEmpty == true) return 'Max participants is required';
                              if (int.tryParse(value!) == null || int.parse(value) <= 0) {
                                return 'Enter valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Workshop Details
                    _buildSectionTitle('Workshop Details'),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Enter workshop description',
                      maxLines: 3,
                      validator: (value) => value?.trim().isEmpty == true ? 'Description is required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTextField(
                      controller: _locationController,
                      label: 'Location',
                      hint: 'Enter workshop location',
                      validator: (value) => value?.trim().isEmpty == true ? 'Location is required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Dropdowns
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            label: 'Category',
                            value: _selectedCategory,
                            items: WorkshopService.getWorkshopCategories(),
                            onChanged: (value) => setState(() => _selectedCategory = value!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdown(
                            label: 'Level',
                            value: _selectedLevel,
                            items: WorkshopService.getWorkshopLevels(),
                            onChanged: (value) => setState(() => _selectedLevel = value!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    _buildDropdown(
                      label: 'Duration',
                      value: _selectedDuration,
                      items: WorkshopService.getWorkshopDurations(),
                      onChanged: (value) => setState(() => _selectedDuration = value!),
                    ),
                    const SizedBox(height: 32),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveWorkshop,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEdit ? 'Update Workshop' : 'Add Workshop',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Workshop Image',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF9FAFB),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 200,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF262626),
                  width: 2,
                ),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : _imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            _imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.image,
                              size: 50,
                              color: Colors.white70,
                            ),
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 40,
                              color: Colors.white70,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tap to add image',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFFF9FAFB),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF9FAFB),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Color(0xFFF9FAFB)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFA3A3A3)),
            filled: true,
            fillColor: const Color(0xFF1B1B1B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF262626)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF262626)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF9FAFB),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B1B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1B1B1B),
              style: const TextStyle(color: Color(0xFFF9FAFB)),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFA3A3A3)),
              onChanged: onChanged,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _imageUrl = null; // Clear existing URL when new image is selected
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveWorkshop() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate date and time
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select start and end time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Format date and time
      final formattedDate = _formatDate(_selectedDate!);
      final formattedTime = _formatTime(_startTime!, _endTime!);

      final result = widget.workshop == null
          ? await WorkshopService.addWorkshop(
              title: _titleController.text.trim(),
              instructor: _instructorController.text.trim(),
              date: formattedDate,
              time: formattedTime,
              price: int.parse(_priceController.text.trim()),
              description: _descriptionController.text.trim(),
              category: _selectedCategory,
              level: _selectedLevel,
              location: _locationController.text.trim(),
              duration: _selectedDuration,
              maxParticipants: int.parse(_maxParticipantsController.text.trim()),
              imageFile: _selectedImage,
              imageUrl: _imageUrl,
            )
          : await WorkshopService.updateWorkshop(
              workshopId: widget.workshop!.id,
              title: _titleController.text.trim(),
              instructor: _instructorController.text.trim(),
              date: formattedDate,
              time: formattedTime,
              price: int.parse(_priceController.text.trim()),
              description: _descriptionController.text.trim(),
              category: _selectedCategory,
              level: _selectedLevel,
              location: _locationController.text.trim(),
              duration: _selectedDuration,
              maxParticipants: int.parse(_maxParticipantsController.text.trim()),
              imageFile: _selectedImage,
              imageUrl: _imageUrl,
            );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate success
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save workshop. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF9FAFB),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Color(0xFFA3A3A3),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedDate != null
                        ? _formatDate(_selectedDate!)
                        : 'Select Date',
                    style: TextStyle(
                      color: _selectedDate != null
                          ? const Color(0xFFF9FAFB)
                          : const Color(0xFFA3A3A3),
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  color: Color(0xFFA3A3A3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Time',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF9FAFB),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectTime,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time,
                  color: Color(0xFFA3A3A3),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _startTime != null && _endTime != null
                        ? _formatTime(_startTime!, _endTime!)
                        : 'Select Time',
                    style: TextStyle(
                      color: _startTime != null && _endTime != null
                          ? const Color(0xFFF9FAFB)
                          : const Color(0xFFA3A3A3),
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  color: Color(0xFFA3A3A3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE53935),
              onPrimary: Colors.white,
              surface: Color(0xFF1B1B1B),
              onSurface: Color(0xFFF9FAFB),
            ),
            dialogBackgroundColor: const Color(0xFF1B1B1B),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    // Select start time
    final TimeOfDay? startPicked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 18, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE53935),
              onPrimary: Colors.white,
              surface: Color(0xFF1B1B1B),
              onSurface: Color(0xFFF9FAFB),
            ),
            dialogBackgroundColor: const Color(0xFF1B1B1B),
          ),
          child: child!,
        );
      },
    );

    if (startPicked != null) {
      // Select end time
      final TimeOfDay? endPicked = await showTimePicker(
        context: context,
        initialTime: _endTime ?? TimeOfDay(hour: startPicked.hour + 2, minute: startPicked.minute),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFFE53935),
                onPrimary: Colors.white,
                surface: Color(0xFF1B1B1B),
                onSurface: Color(0xFFF9FAFB),
              ),
              dialogBackgroundColor: const Color(0xFF1B1B1B),
            ),
            child: child!,
          );
        },
      );

      if (endPicked != null) {
        setState(() {
          _startTime = startPicked;
          _endTime = endPicked;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(TimeOfDay startTime, TimeOfDay endTime) {
    final startStr = _formatTimeOfDay(startTime);
    final endStr = _formatTimeOfDay(endTime);
    return '$startStr - $endStr';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:${minute} $period';
  }
}

// WorkshopData class for AddEditWorkshopScreen
class AddEditWorkshopData {
  final String id;
  final String title;
  final String instructor;
  final String date;
  final String time;
  final int price;
  final String imageUrl;
  final String description;
  final int maxParticipants;
  final int currentParticipants;
  final bool isEnrolled;
  final String category;
  final String level;
  final String location;
  final String duration;
  final String? paymentStatus;

  AddEditWorkshopData({
    required this.id,
    required this.title,
    required this.instructor,
    required this.date,
    required this.time,
    required this.price,
    required this.imageUrl,
    required this.description,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.isEnrolled,
    required this.category,
    required this.level,
    required this.location,
    required this.duration,
    this.paymentStatus,
  });
}
