import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../widgets/glassmorphism_app_bar.dart';
import '../utils/error_handler.dart';

class GalleryScreen extends StatefulWidget {
  final String role;

  const GalleryScreen({
    super.key,
    required this.role,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  bool _isLoading = false;
  String _selectedCategory = 'All';
  String _selectedMediaType = 'Photo';
  String _selectedCategoryForUpload = 'Performances';
  XFile? _selectedFile;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FocusNode _descriptionFocusNode = FocusNode();
  StreamSubscription<TaskSnapshot>? _uploadSubscription;
  
  // Admin management state
  bool _isAdminMode = false;
  Set<String> _selectedItems = <String>{};
  bool _isSelecting = false;
  Map<String, dynamic>? _editingItem;
  final TextEditingController _editTitleController = TextEditingController();
  final TextEditingController _editDescriptionController = TextEditingController();
  String _editCategory = 'Performances';

  final List<String> _categories = [
    'All',
    'Performances',
    'Classes',
    'Workshops',
    'Events',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _descriptionFocusNode.dispose();
    _editTitleController.dispose();
    _editDescriptionController.dispose();
    _uploadSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: _isAdminMode ? 'Admin Gallery' : 'Gallery',
        actions: [
          if (widget.role.toLowerCase() == 'admin') ...[
            if (_isAdminMode) ...[
              if (_isSelecting) ...[
                IconButton(
                  onPressed: _selectAllItems,
                  icon: const Icon(Icons.select_all, color: Colors.white70),
                  tooltip: 'Select All',
                ),
                IconButton(
                  onPressed: _deleteSelectedItems,
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete Selected',
                ),
              ],
              IconButton(
                onPressed: _toggleSelectMode,
                icon: Icon(
                  _isSelecting ? Icons.close : Icons.checklist,
                  color: _isSelecting ? Colors.red : Colors.white70,
                ),
                tooltip: _isSelecting ? 'Exit Select Mode' : 'Select Items',
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
            IconButton(
              onPressed: _addMedia,
              icon: const Icon(Icons.add, color: Colors.white70),
              tooltip: 'Add Media',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            )
          : RefreshIndicator(
              onRefresh: _refreshGallery,
              color: const Color(0xFFE53935),
              child: Column(
              children: [
                _buildCategoryFilter(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('gallery')
                        .orderBy('uploadedAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.white70));
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white70)),
                        );
                      }
                      final docs = snapshot.data?.docs ?? [];
                      final filtered = (_selectedCategory == 'All')
                          ? docs
                          : docs.where((d) => (d.data()['category'] ?? '') == _selectedCategory).toList();
                      if (filtered.isEmpty) {
                        return const Center(
                          child: Text('No media yet', style: TextStyle(color: Colors.white54)),
                        );
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final data = filtered[index].data();
                          final docId = filtered[index].id;
                          return _buildFirestoreGalleryItem(data, docId);
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

  void _openVideoPlayer(String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _InlineVideoPlayer(url: url, title: title),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              backgroundColor: Colors.white.withOpacity( 0.1),
              selectedColor: const Color(0xFFE53935).withOpacity( 0.2),
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFFE53935)
                    : Colors.white.withOpacity( 0.2),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGalleryItem(Map<String, dynamic> item) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity( 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withOpacity( 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withOpacity( 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      item['accentColor'].withOpacity( 0.3),
                      item['accentColor'].withOpacity( 0.1),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        item['icon'],
                        size: 40,
                        color: item['accentColor'],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: item['accentColor'],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${item['count']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['subtitle'],
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirestoreGalleryItem(Map<String, dynamic> item, String docId) {
    final String title = (item['title'] ?? '').toString();
    final String description = (item['description'] ?? '').toString();
    final String mediaType = (item['mediaType'] ?? 'Photo').toString();
    final String url = (item['url'] ?? '').toString();
    final String category = (item['category'] ?? '').toString();
    final bool isSelected = _selectedItems.contains(docId);

    return GestureDetector(
      onTap: () {
        if (_isSelecting && widget.role.toLowerCase() == 'admin') {
          _toggleItemSelection(docId);
        } else if (mediaType == 'Video' && url.isNotEmpty) {
          _openVideoPlayer(url, title);
        }
      },
      onLongPress: () {
        if (widget.role.toLowerCase() == 'admin' && !_isSelecting) {
          _toggleSelectMode();
          _toggleItemSelection(docId);
        }
      },
      child: Card(
        elevation: 6,
        color: isSelected ? const Color(0xFFE53935).withOpacity(0.1) : const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? const Color(0xFFE53935) : const Color(0xFF262626),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                height: 115,
                width: double.infinity,
                color: const Color(0xFF111111),
                child: Stack(
                  children: [
                    // Media content
                    (mediaType == 'Photo' && url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://')))
                        ? Image.network(
                            url, 
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.white30,
                                  size: 48,
                                ),
                              );
                            },
                          )
                        : (mediaType == 'Video' && url.isNotEmpty)
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(
                                    color: const Color(0xFF111111),
                                    child: const Center(
                                      child: Icon(
                                        Icons.videocam,
                                        color: Colors.white30,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                  const Center(
                                    child: Icon(
                                      Icons.play_circle_fill,
                                      color: Color(0xFFE53935),
                                      size: 48,
                                    ),
                                  ),
                                ],
                              )
                            : const Center(
                                child: Icon(
                                  Icons.photo,
                                  color: Colors.white70,
                                  size: 48,
                                ),
                              ),
                    
                    // Selection indicator
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE53935),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    
                    // Admin controls overlay
                    if (widget.role.toLowerCase() == 'admin' && _isAdminMode && !_isSelecting)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => _editItem(item, docId),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _deleteItem(docId, title),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity( 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity( 0.15)),
                          ),
                          child: Text(
                            mediaType, 
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity( 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity( 0.15)),
                          ),
                          child: Text(
                            category, 
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getGalleryItems() {
    final allItems = [
      {
        'title': 'Annual Recital',
        'subtitle': 'Contemporary & Bollywood',
        'icon': Icons.event,
        'accentColor': const Color(0xFF4F46E5),
        'count': 24,
        'category': 'Performances',
      },
      {
        'title': 'Bollywood Classes',
        'subtitle': 'Beginner to Advanced',
        'icon': Icons.school,
        'accentColor': const Color(0xFF10B981),
        'count': 18,
        'category': 'Classes',
      },
      {
        'title': 'Hip-Hop Workshop',
        'subtitle': 'Street Dance Styles',
        'icon': Icons.event_available,
        'accentColor': const Color(0xFFFF9800),
        'count': 12,
        'category': 'Workshops',
      },
      {
        'title': 'Wedding Performance',
        'subtitle': 'Traditional & Modern',
        'icon': Icons.favorite,
        'accentColor': const Color(0xFFE53935),
        'count': 8,
        'category': 'Events',
      },
      {
        'title': 'Contemporary Dance',
        'subtitle': 'Modern Expression',
        'icon': Icons.directions_run,
        'accentColor': const Color(0xFF42A5F5),
        'count': 15,
        'category': 'Classes',
      },
      {
        'title': 'Cultural Festival',
        'subtitle': 'Classical & Folk',
        'icon': Icons.celebration,
        'accentColor': const Color(0xFF9C27B0),
        'count': 20,
        'category': 'Events',
      },
    ];

    if (_selectedCategory == 'All') {
      return allItems;
    }

    return allItems
        .where((item) => item['category'] == _selectedCategory)
        .toList();
  }

  void _addMedia() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black54, // Semi-transparent background
      isDismissible: true,
      enableDrag: true,
      builder: (context) => _buildAddMediaForm(),
    );
  }

  Widget _buildAddMediaForm() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background barrier
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Modal content
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                // Dismiss keyboard when tapping outside text fields
                FocusScope.of(context).unfocus();
              },
              child: Container(
                height: MediaQuery.of(context).size.height * 0.9,
                decoration: const BoxDecoration(
                  color: Color(0xFF1B1B1B),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
          child: Column(
            children: [
              // Fixed header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Text(
                      'Add Media',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        // Dismiss keyboard first
                        FocusScope.of(context).unfocus();
                        // Then close the modal
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Color(0xFFE53935),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMediaTypeSelector(),
                      const SizedBox(height: 20),
                      _buildMediaUploadSection(),
                      const SizedBox(height: 20),
                      _buildMediaDetailsForm(),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _uploadMedia,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE53935),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Upload Media',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Add extra padding at bottom to ensure content is visible above keyboard
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTypeSelector() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity( 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withOpacity( 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withOpacity( 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Media Type',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMediaTypeOption('photo', 'Photo', Icons.photo),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMediaTypeOption('video', 'Video', Icons.videocam),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaTypeOption(String type, String title, IconData icon) {
    final isSelected = _selectedMediaType == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMediaType = title;
          _selectedFile = null; // Clear selected file when changing type
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected: $title'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFE53935).withOpacity( 0.2)
              : Colors.white.withOpacity( 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFFE53935)
                : Colors.white.withOpacity( 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFE53935) : Colors.white70,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFFE53935) : Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              const Icon(
                Icons.check_circle,
                color: Color(0xFFE53935),
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMediaUploadSection() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity( 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withOpacity( 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withOpacity( 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload Media',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _selectMedia,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity( 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity( 0.2),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _selectedFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_upload,
                              color: Colors.white70,
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to select $_selectedMediaType',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedMediaType == 'Photo' 
                                  ? 'From Gallery or Camera'
                                  : 'From Gallery or Camera',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedMediaType == 'Photo' 
                                  ? Icons.image 
                                  : Icons.videocam,
                              color: const Color(0xFF10B981),
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedFile!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to change',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaDetailsForm() {
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity( 0.1),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.white.withOpacity( 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withOpacity( 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Media Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildTitleField(),
              const SizedBox(height: 12),
              _buildDescriptionField(),
              const SizedBox(height: 12),
              _buildCategoryDropdown(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Title',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'Enter media title',
            hintStyle: TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Colors.white30),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Colors.white30),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFE53935)),
            ),
          ),
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          focusNode: _descriptionFocusNode,
          maxLines: 4,
          minLines: 3,
          textInputAction: TextInputAction.done,
          keyboardType: TextInputType.multiline,
          onFieldSubmitted: (_) {
            // Dismiss keyboard when user presses done
            FocusScope.of(context).unfocus();
          },
          onTap: () {
            // Ensure the field is visible when tapped
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                Scrollable.ensureVisible(
                  context,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  alignment: 0.2, // Show field in upper area
                );
              }
            });
          },
          decoration: InputDecoration(
            hintText: 'Enter media description',
            hintStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white10,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Colors.white30),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Colors.white30),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFE53935)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: IconButton(
              icon: const Icon(Icons.keyboard_hide, color: Colors.white70),
              onPressed: () {
                FocusScope.of(context).unfocus();
              },
              tooltip: 'Hide keyboard',
            ),
          ),
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity( 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity( 0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategoryForUpload,
              isExpanded: true,
              dropdownColor: const Color(0xFF2B2B2B),
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
              items: _categories.where((category) => category != 'All').map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedCategoryForUpload = newValue;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  void _selectMedia() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1B1B1B),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Media Source',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickFromGallery();
                    },
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickFromCamera();
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _uploadMedia() async {
    if (_isLoading) return;

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a file first'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    UploadTask? activeUploadTask;
    bool uploadCancelled = false;

    try {
      final file = File(_selectedFile!.path);
      final fileSize = await file.length();
      final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      
      _UploadProgressDialogState? progressDialogState;
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return _UploadProgressDialog(
                fileName: _selectedFile!.name,
                fileSize: fileSizeMB,
                mediaType: _selectedMediaType,
                onStateCreated: (state) => progressDialogState = state,
                onCancel: _selectedMediaType == 'Video' ? () {
                  uploadCancelled = true;
                  activeUploadTask?.cancel();
                } : null,
              );
            },
          );
        },
      );

      if (_selectedMediaType == 'Video') {
        WakelockPlus.enable();
      }

      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${_selectedFile!.name}';
      final Reference ref = FirebaseStorage.instance
          .ref()
          .child('gallery')
          .child(_selectedCategoryForUpload.toLowerCase())
          .child(fileName);

      activeUploadTask = ref.putFile(
        File(_selectedFile!.path),
        SettableMetadata(
          contentType: _selectedMediaType == 'Photo' 
              ? 'image/jpeg' 
              : 'video/mp4',
        ),
      );

      _uploadSubscription = activeUploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.totalBytes > 0) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          if (progress.isFinite && progressDialogState != null) {
            progressDialogState!.updateProgress(progress);
          }
        }
      });

      final TaskSnapshot snapshot = await activeUploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await _uploadSubscription?.cancel();

      try {
        await FirebaseFirestore.instance.collection('gallery').add({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'category': _selectedCategoryForUpload,
          'mediaType': _selectedMediaType,
          'url': downloadUrl,
          'uploadedAt': FieldValue.serverTimestamp(),
          'uploadedBy': 'admin',
        });
      } catch (firestoreError, stackTrace) {
        ErrorHandler.handleError(firestoreError, stackTrace, context: 'saving gallery item to Firestore');
        try {
          await ref.delete();
        } catch (e, stackTrace) {
          ErrorHandler.handleError(e, stackTrace, context: 'cleaning up uploaded file');
        }
        rethrow;
      }

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);

      _selectedFile = null;
      _titleController.clear();
      _descriptionController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedMediaType} uploaded successfully!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _refreshGallery();

    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'uploading media');
      await _uploadSubscription?.cancel();
      
      if (mounted) Navigator.pop(context);
      
      if (mounted && !uploadCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload media. Please check your connection and try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted && uploadCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload cancelled'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (_selectedMediaType == 'Video') {
        WakelockPlus.disable();
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      XFile? file;
      
      if (_selectedMediaType == 'Photo') {
        file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
      } else {
        file = await picker.pickVideo(source: ImageSource.gallery);
      }
      
      if (file != null) {
        setState(() {
          _selectedFile = file;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedMediaType} selected successfully!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'selecting media from gallery');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting media: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      XFile? file;
      
      if (_selectedMediaType == 'Photo') {
        file = await picker.pickImage(source: ImageSource.camera, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
      } else {
        file = await picker.pickVideo(source: ImageSource.camera);
      }
      
      if (file != null) {
        setState(() {
          _selectedFile = file;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedMediaType} captured successfully!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'capturing media from camera');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error capturing media: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _refreshGallery() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
    });
  }

  // Admin management methods
  void _toggleAdminMode() {
    setState(() {
      _isAdminMode = !_isAdminMode;
      if (!_isAdminMode) {
        _isSelecting = false;
        _selectedItems.clear();
      }
    });
  }

  void _toggleSelectMode() {
    setState(() {
      _isSelecting = !_isSelecting;
      if (!_isSelecting) {
        _selectedItems.clear();
      }
    });
  }

  void _toggleItemSelection(String docId) {
    setState(() {
      if (_selectedItems.contains(docId)) {
        _selectedItems.remove(docId);
      } else {
        _selectedItems.add(docId);
      }
    });
  }

  void _selectAllItems() {
    setState(() {
      // This would need to be implemented with the current filtered items
      // For now, we'll show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select all functionality will be implemented with filtered items'),
          backgroundColor: Colors.orange,
        ),
      );
    });
  }

  Future<void> _deleteSelectedItems() async {
    if (_selectedItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text(
          'Delete Selected Items',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete ${_selectedItems.length} item(s)? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final deletedCount = _selectedItems.length;
        for (String docId in _selectedItems) {
          try {
            final doc = await FirebaseFirestore.instance.collection('gallery').doc(docId).get();
            if (doc.exists) {
              final url = doc.data()?['url'] as String?;
              if (url != null && url.isNotEmpty) {
                try {
                  await FirebaseStorage.instance.refFromURL(url).delete();
                } catch (e, stackTrace) { ErrorHandler.handleError(e, stackTrace, context: 'deleting storage file during bulk delete'); }
              }
            }
          } catch (e, stackTrace) { ErrorHandler.handleError(e, stackTrace, context: 'fetching gallery item for bulk delete'); }
          await FirebaseFirestore.instance.collection('gallery').doc(docId).delete();
        }

        setState(() {
          _selectedItems.clear();
          _isSelecting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$deletedCount item(s) deleted successfully'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } catch (e, stackTrace) {
        ErrorHandler.handleError(e, stackTrace, context: 'deleting selected gallery items');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteItem(String docId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        title: const Text(
          'Delete Item',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "$title"? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        try {
          final doc = await FirebaseFirestore.instance.collection('gallery').doc(docId).get();
          if (doc.exists) {
            final url = doc.data()?['url'] as String?;
            if (url != null && url.isNotEmpty) {
              try {
                await FirebaseStorage.instance.refFromURL(url).delete();
              } catch (e, stackTrace) { ErrorHandler.handleError(e, stackTrace, context: 'deleting storage file'); }
            }
          }
        } catch (e, stackTrace) { ErrorHandler.handleError(e, stackTrace, context: 'fetching gallery item for delete'); }
        await FirebaseFirestore.instance.collection('gallery').doc(docId).delete();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item deleted successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } catch (e, stackTrace) {
        ErrorHandler.handleError(e, stackTrace, context: 'deleting gallery item');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _editItem(Map<String, dynamic> item, String docId) {
    _editingItem = item;
    _editTitleController.text = item['title'] ?? '';
    _editDescriptionController.text = item['description'] ?? '';
    _editCategory = item['category'] ?? 'Performances';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black54,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => _buildEditMediaForm(docId),
    );
  }

  Widget _buildEditMediaForm(String docId) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background barrier
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              color: Colors.transparent,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Modal content
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              child: Container(
                height: MediaQuery.of(context).size.height * 0.6,
                decoration: const BoxDecoration(
                  color: Color(0xFF1B1B1B),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    // Fixed header
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const Text(
                            'Edit Media',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _saveEdit(docId),
                            child: const Text(
                              'Save',
                              style: TextStyle(
                                color: Color(0xFFE53935),
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildEditTitleField(),
                            const SizedBox(height: 20),
                            _buildEditDescriptionField(),
                            const SizedBox(height: 20),
                            _buildEditCategoryDropdown(),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Title',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _editTitleController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'Enter media title',
            hintStyle: TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Colors.white30),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Colors.white30),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFE53935)),
            ),
          ),
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildEditDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _editDescriptionController,
          maxLines: 4,
          minLines: 3,
          textInputAction: TextInputAction.done,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText: 'Enter media description',
            hintStyle: TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Colors.white30),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Colors.white30),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFE53935)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildEditCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _editCategory,
              isExpanded: true,
              dropdownColor: const Color(0xFF2B2B2B),
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
              items: _categories.where((category) => category != 'All').map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _editCategory = newValue;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveEdit(String docId) async {
    if (_editTitleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('gallery').doc(docId).update({
        'title': _editTitleController.text.trim(),
        'description': _editDescriptionController.text.trim(),
        'category': _editCategory,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Media updated successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e, stackTrace) {
      ErrorHandler.handleError(e, stackTrace, context: 'updating gallery media');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating media: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

class _InlineVideoPlayer extends StatefulWidget {
  final String url;
  final String title;
  const _InlineVideoPlayer({required this.url, required this.title});

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _showControls = true;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
            _totalDuration = _controller.value.duration;
          });
          _controller.play();
          _startProgressListener();
        }
      });
  }

  void _startProgressListener() {
    _controller.addListener(() {
      if (mounted) {
        setState(() {
          _currentPosition = _controller.value.position;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _seekTo(Duration position) {
    _controller.seekTo(position);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(title: widget.title),
      body: _initialized
          ? GestureDetector(
              onTap: () {
                setState(() {
                  _showControls = !_showControls;
                });
              },
              child: Stack(
                children: [
                  // Video Player
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 80, // Reduced space for controls
                    child: VideoPlayer(_controller),
                  ),
                  
                  // Controls Overlay
                  if (_showControls)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity( 0.7),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Progress Bar
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: const Color(0xFFE53935),
                                  inactiveTrackColor: Colors.white.withOpacity( 0.3),
                                  thumbColor: const Color(0xFFE53935),
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                  trackHeight: 4,
                                ),
                                child: Slider(
                                  value: _currentPosition.inMilliseconds.toDouble(),
                                  max: _totalDuration.inMilliseconds.toDouble(),
                                  onChanged: (value) {
                                    _seekTo(Duration(milliseconds: value.toInt()));
                                  },
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Time and Controls Row
                              Row(
                                children: [
                                  // Left side - Time
                                  Expanded(
                                    child: Row(
                                      children: [
                                        // Current Time
                                        Text(
                                          _formatDuration(_currentPosition),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Spacer(),
                                      ],
                                    ),
                                  ),
                                  
                                  // Center - Play/Pause Button
                                  IconButton(
                                    onPressed: _togglePlayPause,
                                    icon: Icon(
                                      _controller.value.isPlaying
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_filled,
                                      color: const Color(0xFFE53935),
                                      size: 48,
                                    ),
                                  ),
                                  
                                  // Right side - Duration
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Spacer(),
                                        // Total Duration
                                        Text(
                                          _formatDuration(_totalDuration),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          : const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            ),
    );
  }
}

class _UploadProgressDialog extends StatefulWidget {
  final String fileName;
  final String fileSize;
  final String mediaType;
  final Function(_UploadProgressDialogState)? onStateCreated;
  final VoidCallback? onCancel;

  const _UploadProgressDialog({
    required this.fileName,
    required this.fileSize,
    required this.mediaType,
    this.onStateCreated,
    this.onCancel,
  });

  @override
  State<_UploadProgressDialog> createState() => _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<_UploadProgressDialog> {
  double _progress = 0.0;
  String _status = 'Preparing upload...';

  @override
  void initState() {
    super.initState();
    widget.onStateCreated?.call(this);
  }

  void updateProgress(double progress) {
    if (mounted) {
      final safeProgress = (progress.isFinite ? progress : 0.0).clamp(0.0, 1.0);
      setState(() {
        _progress = safeProgress;
        if (safeProgress < 1.0) {
          _status = 'Uploading... ${(safeProgress * 100).toInt()}%';
        } else {
          _status = 'Finalizing...';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1B1B1B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.mediaType == 'Photo' ? Icons.image : Icons.videocam,
              color: const Color(0xFFE53935),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Uploading ${widget.mediaType}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.fileName,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.fileSize} MB',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE53935)),
              minHeight: 8,
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toInt()}%',
              style: const TextStyle(
                color: Color(0xFFE53935),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.mediaType == 'Video') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Videos take longer to upload due to file size',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onCancel != null) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text(
                    'Cancel Upload',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
