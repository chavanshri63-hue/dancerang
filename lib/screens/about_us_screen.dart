import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../widgets/glassmorphism_app_bar.dart';
import 'admin_about_management_screen.dart';

class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({super.key});

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _aboutData;
  bool _isAdmin = false;
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isUploadingLogo = false;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
    _loadAboutData();
  }

  Future<void> _checkAdminRole() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      setState(() {
        _isAdmin = false;
      });
      return;
    }
    
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        final userData = userDoc.data();
        setState(() {
          _isAdmin = userData?['role'] == 'admin';
        });
      } catch (e) {
        setState(() {
          _isAdmin = false;
        });
      }
    }
  }

  Future<void> _loadAboutData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('aboutUs')
          .get();
      
      if (doc.exists) {
        setState(() {
          _aboutData = doc.data();
          _isLoading = false;
        });
        } else {
          // Set default data if no data exists
          setState(() {
            _aboutData = _getDefaultAboutData();
            _isLoading = false;
          });
          // Only save default data to Firestore if user is admin
          if (_isAdmin) {
            await _saveAboutData(_getDefaultAboutData());
          }
        }
    } catch (e) {
      setState(() {
        _aboutData = _getDefaultAboutData();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _getDefaultAboutData() {
    return {
      'studioName': 'DanceRang',
      'tagline': 'Step into Excellence',
      'description': 'DanceRang is a premier dance academy dedicated to nurturing talent and passion for dance. We believe in the power of movement to transform lives and bring people together through the universal language of dance.',
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
          'achievements': [
            '15+ years of professional dance experience',
            'Former principal dancer at Bollywood Dance Company',
            'Choreographed for 50+ stage productions',
            'Winner of National Dance Championship 2018',
            'Mentored 500+ students over the years',
            'Specializes in Bollywood, Contemporary, and Jazz',
          ],
          'bio': 'Priya started dancing at the age of 5 and has never looked back. Her passion for dance and teaching has inspired countless students to pursue their dreams in the world of dance.',
        },
        {
          'name': 'Arjun Patel',
          'role': 'Co-Founder & Technical Director',
          'photo': '', // Empty photo URL - will show placeholder icon
          'achievements': [
            '12+ years in dance education and management',
            'MBA in Arts Management from NID',
            'Former dance instructor at Shiamak Davar Institute',
            'Organized 100+ dance workshops and events',
            'Expert in Hip-Hop, Breaking, and Street Dance',
            'Certified in Dance Therapy and Movement Analysis',
          ],
          'bio': 'Arjun combines his business acumen with his love for dance to create innovative programs that make dance accessible to everyone, regardless of age or skill level.',
        },
      ],
      'studioHighlights': [
        'State-of-the-art dance studios with professional flooring',
        'Experienced and certified instructors',
        'Flexible class timings for working professionals',
        'Regular performance opportunities and recitals',
        'Online classes available for remote learning',
        'Special programs for children and seniors',
      ],
      'awards': [
        'Best Dance Academy Mumbai 2023',
        'Excellence in Dance Education Award 2022',
        'Community Impact Award 2021',
        'Student Choice Award 2020-2023',
      ],
    };
  }

  Future<void> _saveAboutData(Map<String, dynamic> data) async {
    try {
      // Only save if user is admin
      if (!_isAdmin) {
        return;
      }
      
      await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('aboutUs')
          .set(data);
    } catch (e) {
      // Don't show error to user, just log it
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'About Us',
        onLeadingPressed: () => Navigator.pop(context),
        actions: _isAdmin ? [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: _editAboutData,
          ),
        ] : null,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('appSettings')
            .doc('aboutUs')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading about data: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final aboutData = snapshot.data?.data() ?? _getDefaultAboutData();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Studio Header
                _buildStudioHeader(aboutData),
                const SizedBox(height: 24),
                
                // Studio Description
                _buildStudioDescription(aboutData),
                const SizedBox(height: 24),
                
                // Founders Section
                _buildFoundersSection(aboutData),
                const SizedBox(height: 24),
                
                // Studio Highlights
                _buildStudioHighlights(aboutData),
                const SizedBox(height: 24),
                
                // Contact Information
                _buildContactSection(aboutData),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStudioHeader(Map<String, dynamic> data) {
    return Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            alignment: Alignment.center,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo Section
              GestureDetector(
                onTap: _isAdmin && !_isUploadingLogo ? _uploadLogo : null,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isAdmin ? const Color(0xFFE53935) : const Color(0xFFE53935).withOpacity(0.6),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE53935).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: _isUploadingLogo
                      ? Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE53935).withOpacity(0.1),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFE53935),
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      : (data['logo'] != null && data['logo'].toString().isNotEmpty)
                          ? ClipOval(
                              child: Image.network(
                                data['logo'],
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFE53935).withOpacity(0.1),
                                    ),
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
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFE53935).withOpacity(0.1),
                                    ),
                                    child: Icon(
                                      _isAdmin ? Icons.add_a_photo : Icons.directions_run,
                                      size: 70,
                                      color: const Color(0xFFE53935),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFE53935).withOpacity(0.1),
                              ),
                              child: Icon(
                                _isAdmin ? Icons.add_a_photo : Icons.directions_run,
                                size: 70,
                                color: const Color(0xFFE53935),
                              ),
                            ),
                ),
              ),
              if (_isAdmin) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Tap to upload logo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                data['studioName'] ?? 'DanceRang',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFF9FAFB),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data['tagline'] ?? 'Step into Excellence',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        data['location'] ?? 'Mumbai, India',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Since ${data['foundedYear'] ?? '2020'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
      ),
          ),
    );
  }

  Widget _buildStudioDescription(Map<String, dynamic> data) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Our Story',
              style: TextStyle(
                color: Color(0xFFE53935),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              data['description'] ?? '',
              style: const TextStyle(
                color: Color(0xFFF9FAFB),
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoundersSection(Map<String, dynamic> data) {
    final founders = data['founders'] as List<dynamic>;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Meet Our Founders',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF9FAFB),
          ),
        ),
        const SizedBox(height: 16),
        ...founders.map((founder) => _buildFounderCard(founder)),
      ],
    );
  }

  Widget _buildFounderCard(Map<String, dynamic> founder) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
            // Founder Photo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE53935),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE53935).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: (founder['photo'] != null && founder['photo'].toString().isNotEmpty)
                    ? Image.network(
                        founder['photo'],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: const Color(0xFFE53935).withValues(alpha: 0.1),
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
                            color: const Color(0xFFE53935).withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.person,
                              size: 60,
                              color: Color(0xFFE53935),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: const Color(0xFFE53935).withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.person,
                          size: 60,
                          color: Color(0xFFE53935),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Founder Name & Role
            Text(
              founder['name'] ?? '',
              style: const TextStyle(
                color: Color(0xFFF9FAFB),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              founder['role'] ?? '',
              style: const TextStyle(
                color: Color(0xFFE53935),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            // Bio
            Text(
              founder['bio'] ?? '',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Achievements
            const Text(
              'Achievements',
              style: TextStyle(
                color: Color(0xFFF9FAFB),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...(founder['achievements'] as List<dynamic>).map((achievement) => 
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        achievement,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
      ),
    );
  }

  Widget _buildStudioHighlights(Map<String, dynamic> data) {
    final highlights = data['studioHighlights'] as List<dynamic>;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Why Choose DanceRang?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF9FAFB),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFF66BB6A).withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: highlights.map((highlight) => 
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF66BB6A).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Color(0xFF66BB6A),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          highlight,
                          style: const TextStyle(
                            color: Color(0xFFF9FAFB),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAwardsSection(Map<String, dynamic> data) {
    final awards = data['awards'] as List<dynamic>;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Awards & Recognition',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF9FAFB),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: awards.map((award) => 
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          color: Colors.amber,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          award,
                          style: const TextStyle(
                            color: Color(0xFFF9FAFB),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection(Map<String, dynamic> data) {
    return Card(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFF66BB6A).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Get in Touch',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildContactItem(
              Icons.email,
              'Email',
              data['contactEmail'] ?? 'info@dancerang.com',
              onTap: () => _launchEmail(data['contactEmail'] ?? 'info@dancerang.com'),
              iconColor: const Color(0xFFE53935), // Red for email
            ),
            const SizedBox(height: 12),
            _buildContactItem(
              Icons.phone,
              'Phone',
              data['contactPhone'] ?? '+91 98765 43210',
              onTap: () => _launchPhone(data['contactPhone'] ?? '+91 98765 43210'),
              iconColor: const Color(0xFF4CAF50), // Green for phone
            ),
            const SizedBox(height: 12),
            _buildContactItem(
              Icons.location_on,
              'Location',
              data['location'] ?? 'Mumbai, India',
              onTap: () => _launchLocation(data['location'] ?? 'Mumbai, India'),
              iconColor: const Color(0xFF2196F3), // Blue for location
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value, {VoidCallback? onTap, Color? iconColor}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: onTap != null 
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? Colors.white70).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor ?? Colors.white70, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: onTap != null 
                          ? Colors.white
                          : const Color(0xFFF9FAFB),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withValues(alpha: 0.5),
                size: 16,
              ),
          ],
        ),
      ),
    );
  }


  void _editAboutData() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminAboutManagementScreen(),
      ),
    );
    // Data will auto-refresh via StreamBuilder
  }

  Future<void> _launchEmail(String email) async {
    try {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: email,
        query: 'subject=DanceRang Inquiry&body=Hello DanceRang Team,',
      );
      
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        _showErrorSnackBar('Could not open email app');
      }
    } catch (e) {
      _showErrorSnackBar('Error opening email: $e');
    }
  }

  Future<void> _launchPhone(String phone) async {
    try {
      // Clean phone number (remove spaces, dashes, etc.)
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      final Uri phoneUri = Uri(scheme: 'tel', path: cleanPhone);
      
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showErrorSnackBar('Could not open phone app');
      }
    } catch (e) {
      _showErrorSnackBar('Error opening phone: $e');
    }
  }

  Future<void> _launchLocation(String location) async {
    try {
      // Create a search query for the location
      final String encodedLocation = Uri.encodeComponent(location);
      final Uri mapUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedLocation');
      
      if (await canLaunchUrl(mapUri)) {
        await launchUrl(mapUri, mode: LaunchMode.externalApplication);
      } else {
        _showErrorSnackBar('Could not open maps app');
      }
    } catch (e) {
      _showErrorSnackBar('Error opening maps: $e');
    }
  }

  Future<void> _uploadLogo() async {
    if (!_isAdmin) return;
    
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
      final String fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child('about_us/$fileName');
      
      final UploadTask uploadTask = ref.putFile(File(image.path));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Save to Firestore using update to preserve existing data
      await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('aboutUs')
          .update({'logo': downloadUrl});
      
      // Data will auto-refresh via StreamBuilder
      
      setState(() {
        _isUploadingLogo = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logo uploaded successfully!'),
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
