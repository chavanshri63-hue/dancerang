import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../widgets/glassmorphism_app_bar.dart';

class AdminAboutManagementScreen extends StatefulWidget {
  const AdminAboutManagementScreen({super.key});

  @override
  State<AdminAboutManagementScreen> createState() => _AdminAboutManagementScreenState();
}

class _AdminAboutManagementScreenState extends State<AdminAboutManagementScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _aboutData;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Track which founder is being uploaded
  int? _uploadingFounderIndex;
  bool _isUploadingLogo = false;

  // Controllers for form fields
  late TextEditingController _studioNameController;
  late TextEditingController _taglineController;
  late TextEditingController _descriptionController;
  late TextEditingController _foundedYearController;
  late TextEditingController _locationController;
  late TextEditingController _contactEmailController;
  late TextEditingController _contactPhoneController;

  // Founder controllers
  late List<TextEditingController> _founderNameControllers;
  late List<TextEditingController> _founderRoleControllers;
  late List<TextEditingController> _founderBioControllers;
  late List<List<TextEditingController>> _founderAchievementControllers;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadAboutData();
  }

  void _initializeControllers() {
    _studioNameController = TextEditingController();
    _taglineController = TextEditingController();
    _descriptionController = TextEditingController();
    _foundedYearController = TextEditingController();
    _locationController = TextEditingController();
    _contactEmailController = TextEditingController();
    _contactPhoneController = TextEditingController();
    
    _founderNameControllers = [];
    _founderRoleControllers = [];
    _founderBioControllers = [];
    _founderAchievementControllers = [];
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _studioNameController.dispose();
    _taglineController.dispose();
    _descriptionController.dispose();
    _foundedYearController.dispose();
    _locationController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    
    for (var controller in _founderNameControllers) controller.dispose();
    for (var controller in _founderRoleControllers) controller.dispose();
    for (var controller in _founderBioControllers) controller.dispose();
    for (var controllers in _founderAchievementControllers) {
      for (var controller in controllers) controller.dispose();
    }
  }

  Future<void> _loadAboutData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('aboutUs')
          .get();
      
      Map<String, dynamic> data;
      if (doc.exists) {
        data = doc.data()!;
      } else {
        data = _getDefaultAboutData();
      }
      
      setState(() {
        _aboutData = data;
        _populateControllers(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _aboutData = _getDefaultAboutData();
        _populateControllers(_aboutData!);
        _isLoading = false;
      });
    }
  }

  void _populateControllers(Map<String, dynamic> data) {
    // Clear existing controllers first
    _disposeControllers();
    _initializeControllers();
    
    // Populate basic fields
    _studioNameController.text = data['studioName'] ?? '';
    _taglineController.text = data['tagline'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _foundedYearController.text = data['foundedYear'] ?? '';
    _locationController.text = data['location'] ?? '';
    _contactEmailController.text = data['contactEmail'] ?? '';
    _contactPhoneController.text = data['contactPhone'] ?? '';

    // Populate founder data
    final founders = data['founders'] as List<dynamic>? ?? [];
    for (int i = 0; i < founders.length; i++) {
      final founder = founders[i];
      _founderNameControllers.add(TextEditingController(text: founder['name'] ?? ''));
      _founderRoleControllers.add(TextEditingController(text: founder['role'] ?? ''));
      _founderBioControllers.add(TextEditingController(text: founder['bio'] ?? ''));
      
      final achievements = founder['achievements'] as List<dynamic>? ?? [];
      List<TextEditingController> achievementControllers = [];
      for (String achievement in achievements) {
        achievementControllers.add(TextEditingController(text: achievement));
      }
      if (achievementControllers.isEmpty) {
        achievementControllers.add(TextEditingController());
      }
      _founderAchievementControllers.add(achievementControllers);
    }
    
    // Ensure at least one founder
    if (_founderNameControllers.isEmpty) {
      _founderNameControllers.add(TextEditingController());
      _founderRoleControllers.add(TextEditingController());
      _founderBioControllers.add(TextEditingController());
      _founderAchievementControllers.add([TextEditingController()]);
    }
  }

  Map<String, dynamic> _getDefaultAboutData() {
    return {
      'studioName': 'DanceRang',
      'tagline': 'Step into Excellence',
      'description': 'DanceRang is a premier dance academy dedicated to nurturing talent and passion for dance.',
      'foundedYear': '2020',
      'location': 'Mumbai, India',
      'contactEmail': 'info@dancerang.com',
      'contactPhone': '+91 98765 43210',
      'logo': '',
      'founders': [
        {
          'name': 'Priya Sharma',
          'role': 'Co-Founder & Artistic Director',
          'photo': '', // Empty photo URL - will show placeholder icon
          'achievements': ['15+ years of professional dance experience', 'Former principal dancer at Bollywood Dance Company'],
          'bio': 'Priya started dancing at the age of 5 and has never looked back.',
        },
        {
          'name': 'Arjun Patel',
          'role': 'Co-Founder & Technical Director',
          'photo': '', // Empty photo URL - will show placeholder icon
          'achievements': ['12+ years in dance education and management', 'MBA in Arts Management from NID'],
          'bio': 'Arjun combines his business acumen with his love for dance.',
        },
      ],
    };
  }

  Future<void> _saveAboutData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final data = _buildDataFromControllers();
      await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('aboutUs')
          .set(data);
      
      setState(() {
        _aboutData = data;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('About Us data saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Return true to indicate successful save
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _buildDataFromControllers() {
    final founders = <Map<String, dynamic>>[];
    
    for (int i = 0; i < _founderNameControllers.length; i++) {
      final achievements = _founderAchievementControllers[i]
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
      
      founders.add({
        'name': _founderNameControllers[i].text.trim(),
        'role': _founderRoleControllers[i].text.trim(),
        'bio': _founderBioControllers[i].text.trim(),
        'achievements': achievements,
        'photo': (_aboutData?['founders'] != null && 
                  i < _aboutData!['founders'].length) 
                  ? (_aboutData!['founders'][i]?['photo'] ?? '') 
                  : '',
      });
    }

    return {
      'studioName': _studioNameController.text.trim(),
      'tagline': _taglineController.text.trim(),
      'description': _descriptionController.text.trim(),
      'foundedYear': _foundedYearController.text.trim(),
      'location': _locationController.text.trim(),
      'contactEmail': _contactEmailController.text.trim(),
      'contactPhone': _contactPhoneController.text.trim(),
      'founders': founders,
      'studioHighlights': _aboutData?['studioHighlights'] ?? [],
      'awards': _aboutData?['awards'] ?? [],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'About Us Management',
        onLeadingPressed: () => Navigator.pop(context),
        actions: [
          IconButton(
            icon: _isSaving 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save, color: Colors.white),
            onPressed: _isSaving ? null : _saveAboutData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Studio Information Section
                    _buildSectionHeader('Studio Information'),
                    _buildStudioInfoSection(),
                    const SizedBox(height: 24),
                    
                    // Founders Section
                    _buildSectionHeader('Founders Information'),
                    _buildFoundersSection(),
                    const SizedBox(height: 24),
                    
                    // Contact Information Section
                    _buildSectionHeader('Contact Information'),
                    _buildContactSection(),
                    const SizedBox(height: 80), // Space for FAB
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        onPressed: _addFounder,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFFE53935),
        ),
      ),
    );
  }

  Widget _buildStudioInfoSection() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Studio Logo Upload
            _buildLogoUploadSection(),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _studioNameController,
              label: 'Studio Name',
              icon: Icons.business,
              validator: (value) => value?.isEmpty == true ? 'Studio name is required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _taglineController,
              label: 'Tagline',
              icon: Icons.format_quote,
              validator: (value) => value?.isEmpty == true ? 'Tagline is required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              icon: Icons.description,
              maxLines: 4,
              validator: (value) => value?.isEmpty == true ? 'Description is required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _foundedYearController,
                    label: 'Founded Year',
                    icon: Icons.calendar_today,
                    keyboardType: TextInputType.number,
                    validator: (value) => value?.isEmpty == true ? 'Founded year is required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _locationController,
                    label: 'Location',
                    icon: Icons.location_on,
                    validator: (value) => value?.isEmpty == true ? 'Location is required' : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoundersSection() {
    return Column(
      children: List.generate(_founderNameControllers.length, (index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Founder ${index + 1}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeFounder(index),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Founder Photo
                Center(
                  child: GestureDetector(
                    onTap: _uploadingFounderIndex == index ? null : () => _pickFounderPhoto(index),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _uploadingFounderIndex == index 
                              ? Colors.orange 
                              : const Color(0xFF4F46E5), 
                          width: 2,
                        ),
                        image: _aboutData?['founders'] != null && 
                               index < _aboutData!['founders'].length &&
                               _aboutData!['founders'][index]?['photo'] != null && 
                               _aboutData!['founders'][index]['photo'].toString().isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(_aboutData!['founders'][index]['photo']),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _uploadingFounderIndex == index
                          ? const CircularProgressIndicator(
                              color: Colors.orange,
                              strokeWidth: 3,
                            )
                          : _aboutData?['founders'] == null || 
                            index >= _aboutData!['founders'].length ||
                            _aboutData!['founders'][index]?['photo'] == null || 
                            _aboutData!['founders'][index]['photo'].toString().isEmpty
                              ? const Icon(Icons.add_a_photo, size: 40, color: Color(0xFF4F46E5))
                              : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  controller: _founderNameControllers[index],
                  label: 'Founder Name',
                  icon: Icons.person,
                  validator: (value) => value?.isEmpty == true ? 'Founder name is required' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _founderRoleControllers[index],
                  label: 'Role/Position',
                  icon: Icons.work,
                  validator: (value) => value?.isEmpty == true ? 'Role is required' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _founderBioControllers[index],
                  label: 'Bio',
                  icon: Icons.info,
                  maxLines: 3,
                  validator: (value) => value?.isEmpty == true ? 'Bio is required' : null,
                ),
                const SizedBox(height: 16),
                
                // Achievements
                Row(
                  children: [
                    const Text(
                      'Achievements',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF9FAFB),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add, color: Color(0xFF4F46E5)),
                      onPressed: () => _addAchievement(index),
                    ),
                  ],
                ),
                ..._founderAchievementControllers[index].asMap().entries.map((entry) {
                  final achievementIndex = entry.key;
                  final controller = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: controller,
                            label: 'Achievement ${achievementIndex + 1}',
                            icon: Icons.star,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.red),
                          onPressed: () => _removeAchievement(index, achievementIndex),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildContactSection() {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF66BB6A).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTextField(
              controller: _contactEmailController,
              label: 'Contact Email',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) => value?.isEmpty == true ? 'Email is required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _contactPhoneController,
              label: 'Contact Phone',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (value) => value?.isEmpty == true ? 'Phone is required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _locationController,
              label: 'Location',
              icon: Icons.location_on,
              validator: (value) => value?.isEmpty == true ? 'Location is required' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoUploadSection() {
    return Column(
      children: [
        const Text(
          'Studio Logo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE53935),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _uploadStudioLogo,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _isUploadingLogo ? Colors.orange : const Color(0xFFE53935),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53935).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isUploadingLogo
                ? Container(
                    color: const Color(0xFFE53935).withOpacity(0.1),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE53935),
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : (_aboutData?['logo'] != null && _aboutData!['logo'].toString().isNotEmpty)
                    ? ClipOval(
                        child: Image.network(
                          _aboutData!['logo'],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: const Color(0xFFE53935).withOpacity(0.1),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFE53935),
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: const Color(0xFFE53935).withOpacity(0.1),
                              child: const Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: Color(0xFFE53935),
                              ),
                            );
                          },
                        ),
                      )
                    : Container(
                        color: const Color(0xFFE53935).withOpacity(0.1),
                        child: const Icon(
                          Icons.add_a_photo,
                          size: 40,
                          color: Color(0xFFE53935),
                        ),
                      ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap to upload logo',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Color(0xFFF9FAFB)),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFE53935)),
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }

  void _addFounder() {
    setState(() {
      _founderNameControllers.add(TextEditingController());
      _founderRoleControllers.add(TextEditingController());
      _founderBioControllers.add(TextEditingController());
      _founderAchievementControllers.add([TextEditingController()]);
    });
  }

  void _removeFounder(int index) {
    if (_founderNameControllers.length > 1) {
      setState(() {
        _founderNameControllers[index].dispose();
        _founderRoleControllers[index].dispose();
        _founderBioControllers[index].dispose();
        for (var controller in _founderAchievementControllers[index]) {
          controller.dispose();
        }
        
        _founderNameControllers.removeAt(index);
        _founderRoleControllers.removeAt(index);
        _founderBioControllers.removeAt(index);
        _founderAchievementControllers.removeAt(index);
      });
    }
  }

  void _addAchievement(int founderIndex) {
    setState(() {
      _founderAchievementControllers[founderIndex].add(TextEditingController());
    });
  }

  void _removeAchievement(int founderIndex, int achievementIndex) {
    if (_founderAchievementControllers[founderIndex].length > 1) {
      setState(() {
        _founderAchievementControllers[founderIndex][achievementIndex].dispose();
        _founderAchievementControllers[founderIndex].removeAt(achievementIndex);
      });
    }
  }

  Future<void> _uploadStudioLogo() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image == null) return;
      
      setState(() {
        _isUploadingLogo = true;
      });
      
      // Upload to Firebase Storage
      final String fileName = 'studio_logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child('about_us/$fileName');
      
      final UploadTask uploadTask = ref.putFile(File(image.path));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Update about data with new logo URL
      final updatedData = Map<String, dynamic>.from(_aboutData!);
      updatedData['logo'] = downloadUrl;
      
      setState(() {
        _aboutData = updatedData;
        _isUploadingLogo = false;
      });
      
      // Save to Firestore using update to preserve existing data
      await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('aboutUs')
          .update({'logo': downloadUrl});
      
      
      // Refresh the data to ensure UI updates
      await _loadAboutData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Studio logo uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      setState(() {
        _isUploadingLogo = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading logo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickFounderPhoto(int founderIndex) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _uploadingFounderIndex = founderIndex;
        });

        // Show loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 16),
                Text('Uploading image...'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );

        // Upload image to Firebase Storage
        final String fileName = 'founder_${founderIndex}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Reference ref = _storage.ref().child('about_us/founders/$fileName');
        
        final UploadTask uploadTask = ref.putFile(File(image.path));
        final TaskSnapshot snapshot = await uploadTask;
        final String downloadUrl = await snapshot.ref.getDownloadURL();

        // Update the founder's photo URL in the data
        setState(() {
          if (_aboutData != null && _aboutData!['founders'] != null) {
            _aboutData!['founders'][founderIndex]['photo'] = downloadUrl;
          }
          _uploadingFounderIndex = null;
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _uploadingFounderIndex = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
