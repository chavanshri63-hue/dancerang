import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminFeedScreen extends StatefulWidget {
  const AdminFeedScreen({super.key});
  @override
  State<AdminFeedScreen> createState() => _AdminFeedScreenState();
}

class _AdminFeedScreenState extends State<AdminFeedScreen> {
  final TextEditingController _caption = TextEditingController();
  bool _isUploading = false;

  Future<void> _pickAndUpload({required bool isVideo}) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await (isVideo
          ? picker.pickVideo(source: ImageSource.gallery)
          : picker.pickImage(source: ImageSource.gallery, imageQuality: 90));
      if (picked == null) return;

      setState(() => _isUploading = true);

      final file = File(picked.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final path = isVideo ? 'feed_media/videos/$fileName' : 'feed_media/images/$fileName';
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('feed').add({
        'type': isVideo ? 'video' : 'image',
        'url': url,
        'caption': _caption.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _caption.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post added to feed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload post. Please check your connection and try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        title: const Text('Manage Feed', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF0A0A0A),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Description (Optional)',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _caption,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Write a description for your post...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : () => _pickAndUpload(isVideo: false),
                        icon: const Icon(Icons.image),
                        label: const Text('Upload Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : () => _pickAndUpload(isVideo: true),
                        icon: const Icon(Icons.videocam),
                        label: const Text('Upload Video'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isUploading) const LinearProgressIndicator(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('feed')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white70));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No posts yet', style: TextStyle(color: Colors.white70)));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, i) {
                    final m = docs[i].data();
                    final isImage = (m['type'] ?? 'image') == 'image';
                    final url = m['url'] as String? ?? '';
                    final caption = m['caption'] as String? ?? '';
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: isImage
                                ? ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    child: Image.network(url, fit: BoxFit.cover),
                                  )
                                : Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Container(color: Colors.black26),
                                      const Center(child: Icon(Icons.play_circle_fill, size: 56, color: Colors.white70)),
                                    ],
                                  ),
                          ),
                          // Description/Caption below photo
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              caption.isNotEmpty ? caption : 'No description',
                              style: TextStyle(
                                color: caption.isNotEmpty ? Colors.white : Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                onPressed: () async {
                                  // Delete post
                                  await docs[i].reference.delete();
                                },
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                              )
                            ],
                          )
                        ],
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: docs.length,
                );
              },
            ),
          )
        ],
      ),
    );
  }
}


