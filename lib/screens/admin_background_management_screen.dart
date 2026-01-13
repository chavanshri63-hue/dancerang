import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/admin_service.dart';
import '../widgets/glassmorphism_app_bar.dart';
import '../models/banner_model.dart';

class AdminBackgroundManagementScreen extends StatefulWidget {
  const AdminBackgroundManagementScreen({super.key});

  @override
  State<AdminBackgroundManagementScreen> createState() => _AdminBackgroundManagementScreenState();
}

class _AdminBackgroundManagementScreenState extends State<AdminBackgroundManagementScreen> {
  Map<String, String?> _backgroundImages = {};
  bool _isLoading = true;
  String? _errorMessage;
  final ScrollController _scrollController = ScrollController();

  // Banners (Storage JSON)
  bool _loadingBanners = true;
  List<AppBanner> _banners = [];

  // Theme colors
  static const Color primaryRed = Color(0xFFE53935);
  static const Color charcoal = Color(0xFF1B1B1B);
  static const Color darkGray = Color(0xFF0A0A0A);
  static const Color lightGray = Color(0xFFF9FAFB);

  @override
  void initState() {
    super.initState();
    _loadBackgroundImages();
    _loadBanners();
    
    // Check if coming from banner management route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeName = ModalRoute.of(context)?.settings.name;
      if (routeName == '/banner-management') {
        _scrollToBanners();
      }
    });
  }

  void _scrollToBanners() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          800.0, // Approximate position of banners section
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadBackgroundImages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final images = await AdminService.getBackgroundImages();
      setState(() {
        _backgroundImages = images;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading background images: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateBackgroundImage(String screenName) async {
    try {
      final XFile? imageFile = await AdminService.pickImage();
      if (imageFile == null) return;

      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Upload image
      final String? imageUrl = await AdminService.uploadBackgroundImage(
        imageFile: imageFile,
        screenName: screenName,
      );

      if (imageUrl != null) {
        // Update in Firestore
        final success = await AdminService.updateBackgroundImage(
          screenName: screenName,
          imageUrl: imageUrl,
        );

        if (success) {
          setState(() {
            _backgroundImages[screenName] = imageUrl;
          });
          _showSnackBar('Background updated successfully!', isSuccess: true);
        } else {
          _showSnackBar('Failed to update background', isSuccess: false);
        }
      } else {
        _showSnackBar('Failed to upload image', isSuccess: false);
      }

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showSnackBar('Error updating background: $e', isSuccess: false);
      }
    }
  }

  Future<void> _removeBackgroundImage(String screenName) async {
    try {
      final success = await AdminService.removeBackgroundImage(
        screenName: screenName,
      );

      if (success) {
        setState(() {
          _backgroundImages[screenName] = null;
        });
        _showSnackBar('Background removed successfully!', isSuccess: true);
      } else {
        _showSnackBar('Failed to remove background', isSuccess: false);
      }
    } catch (e) {
      _showSnackBar('Error removing background: $e', isSuccess: false);
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : primaryRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkGray,
      appBar: const GlassmorphismAppBar(
        title: 'Background Management',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Color(0xFFE53935)),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadBackgroundImages,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manage Screen Backgrounds',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Upload and manage background images for different screens',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...AdminService.getAvailableScreens().map((screenName) {
                        final displayName = AdminService.getScreenDisplayNames()[screenName]!;
                        final imageUrl = _backgroundImages[screenName];
                        
                        return _buildScreenCard(screenName, displayName, imageUrl);
                      }),

                      const SizedBox(height: 24),
                      const Text(
                        'Manage Banners',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Add, edit and reorder app banners', style: TextStyle(color: Colors.white70)),
                          ElevatedButton.icon(
                            onPressed: _addBanner,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Banner'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _loadingBanners
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
                          : Column(
                              children: _banners.asMap().entries.map((entry) {
                                final i = entry.key;
                                final b = entry.value;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 8,
                                  shadowColor: Colors.black.withValues(alpha: 0.1),
                                  color: Theme.of(context).cardColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE53935).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.image, color: Color(0xFFE53935), size: 20),
                                    ),
                                    title: Text(b.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                    subtitle: Text(b.imageUrl, style: const TextStyle(color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.arrow_upward, color: Colors.white70),
                                          onPressed: i == 0 ? null : () => _moveBanner(i, -1),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.arrow_downward, color: Colors.white70),
                                          onPressed: i == _banners.length - 1 ? null : () => _moveBanner(i, 1),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.white70),
                                          onPressed: () => _editBanner(i),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.white70),
                                          onPressed: () => _deleteBanner(i),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildScreenCard(String screenName, String displayName, String? imageUrl) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
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
                    color: const Color(0xFFE53935).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getScreenIcon(screenName),
                    color: const Color(0xFFE53935),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (imageUrl != null && imageUrl.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Set',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateBackgroundImage(screenName),
                    icon: const Icon(Icons.upload, size: 18),
                    label: Text((imageUrl != null && imageUrl.isNotEmpty) ? 'Change' : 'Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (imageUrl != null && imageUrl.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _removeBackgroundImage(screenName),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE53935),
                        side: const BorderSide(color: Color(0xFFE53935)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getScreenIcon(String screenName) {
    switch (screenName) {
      case 'loginScreen':
        return Icons.login;
      case 'homeScreen':
        return Icons.home;
      case 'classesScreen':
        return Icons.school;
      case 'studioScreen':
        return Icons.apartment;
      case 'onlineScreen':
        return Icons.play_circle;
      case 'profileScreen':
        return Icons.person;
      default:
        return Icons.screen_share;
    }
  }

  Future<void> _loadBanners() async {
    setState(() => _loadingBanners = true);
    final jsonList = await AdminService.readBannersJson();
    final items = jsonList.map((e) => AppBanner.fromMap(e)).toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));
    setState(() {
      _banners = items;
      _loadingBanners = false;
    });
  }

  Future<void> _saveBanners() async {
    final ok = await AdminService.writeBannersJson(_banners.map((e) => e.toMap()).toList());
    if (ok) {
      _showSnackBar('Banners saved', isSuccess: true);
    } else {
      _showSnackBar('Failed to save banners');
    }
  }

  Future<void> _addBanner() async {
    final controllers = _BannerControllers();
    String? imageUrl;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: charcoal,
          title: const Text('Add Banner', style: TextStyle(color: lightGray)),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: controllers.title, decoration: const InputDecoration(hintText: 'Title'), style: const TextStyle(color: lightGray)),
                const SizedBox(height: 8),
                TextField(controller: controllers.ctaText, decoration: const InputDecoration(hintText: 'CTA Text (optional)'), style: const TextStyle(color: lightGray)),
                const SizedBox(height: 8),
                TextField(controller: controllers.ctaLink, decoration: const InputDecoration(hintText: 'CTA Link (optional)'), style: const TextStyle(color: lightGray)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final x = await AdminService.pickImage();
                    if (x != null) {
                      final url = await AdminService.uploadBannerImage(x);
                      if (url != null) {
                        imageUrl = url;
                        _showSnackBar('Image selected');
                      }
                    }
                  },
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Upload Image'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if ((controllers.title.text).trim().isEmpty || imageUrl == null) return;
                _banners.add(AppBanner(title: controllers.title.text.trim(), imageUrl: imageUrl!, ctaText: controllers.ctaText.text.trim().isEmpty ? null : controllers.ctaText.text.trim(), ctaLink: controllers.ctaLink.text.trim().isEmpty ? null : controllers.ctaLink.text.trim(), isActive: true, sort: _banners.length));
                Navigator.pop(context);
                _saveBanners();
                setState(() {});
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editBanner(int index) async {
    final b = _banners[index];
    final controllers = _BannerControllers.from(b);
    String imageUrl = b.imageUrl;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: charcoal,
          title: const Text('Edit Banner', style: TextStyle(color: lightGray)),
          content: SingleChildScrollView(
            child: Column(children: [
              TextField(controller: controllers.title, decoration: const InputDecoration(hintText: 'Title'), style: const TextStyle(color: lightGray)),
              const SizedBox(height: 8),
              TextField(controller: controllers.ctaText, decoration: const InputDecoration(hintText: 'CTA Text (optional)'), style: const TextStyle(color: lightGray)),
              const SizedBox(height: 8),
              TextField(controller: controllers.ctaLink, decoration: const InputDecoration(hintText: 'CTA Link (optional)'), style: const TextStyle(color: lightGray)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final x = await AdminService.pickImage();
                  if (x != null) {
                    final url = await AdminService.uploadBannerImage(x);
                    if (url != null) {
                      imageUrl = url;
                      _showSnackBar('Image updated');
                    }
                  }
                },
                icon: const Icon(Icons.file_upload),
                label: const Text('Replace Image'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                _banners[index] = AppBanner(
                  title: controllers.title.text.trim(),
                  imageUrl: imageUrl,
                  ctaText: controllers.ctaText.text.trim().isEmpty ? null : controllers.ctaText.text.trim(),
                  ctaLink: controllers.ctaLink.text.trim().isEmpty ? null : controllers.ctaLink.text.trim(),
                  isActive: true,
                  sort: index,
                );
                Navigator.pop(context);
                _saveBanners();
                setState(() {});
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteBanner(int index) async {
    _banners.removeAt(index);
    for (int i = 0; i < _banners.length; i++) {
      _banners[i] = AppBanner(
        title: _banners[i].title,
        imageUrl: _banners[i].imageUrl,
        ctaText: _banners[i].ctaText,
        ctaLink: _banners[i].ctaLink,
        isActive: _banners[i].isActive,
        sort: i,
      );
    }
    await _saveBanners();
    setState(() {});
  }

  void _moveBanner(int index, int delta) async {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _banners.length) return;
    final item = _banners.removeAt(index);
    _banners.insert(newIndex, item);
    for (int i = 0; i < _banners.length; i++) {
      _banners[i] = AppBanner(
        title: _banners[i].title,
        imageUrl: _banners[i].imageUrl,
        ctaText: _banners[i].ctaText,
        ctaLink: _banners[i].ctaLink,
        isActive: _banners[i].isActive,
        sort: i,
      );
    }
    await _saveBanners();
    setState(() {});
  }
}

class _BannerControllers {
  final TextEditingController title = TextEditingController();
  final TextEditingController ctaText = TextEditingController();
  final TextEditingController ctaLink = TextEditingController();
  _BannerControllers();
  _BannerControllers.from(AppBanner b) {
    title.text = b.title;
    ctaText.text = b.ctaText ?? '';
    ctaLink.text = b.ctaLink ?? '';
  }
}
