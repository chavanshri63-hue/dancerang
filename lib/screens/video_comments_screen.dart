import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';

class VideoCommentsScreen extends StatefulWidget {
  final String videoId;
  final String videoTitle;

  const VideoCommentsScreen({
    super.key,
    required this.videoId,
    required this.videoTitle,
  });

  @override
  State<VideoCommentsScreen> createState() => _VideoCommentsScreenState();
}

class _VideoCommentsScreenState extends State<VideoCommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: GlassmorphismAppBar(
        title: 'Comments',
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareVideo,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('onlineVideos')
                  .doc(widget.videoId)
                  .collection('comments')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
                }
                
                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final commentData = docs[index].data();
                    final commentId = docs[index].id;
                    
                    return _CommentCard(
                      commentId: commentId,
                      commentData: commentData,
                      videoId: widget.videoId,
                    );
                  },
                );
              },
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Comments Yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share your thoughts!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _addComment,
            icon: const Icon(Icons.send, color: Color(0xFF4F46E5)),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5).withOpacity(0.2),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      final userName = userData?['name'] ?? 'Anonymous';
      final userProfilePic = userData?['profilePicture'] ?? '';

      await FirebaseFirestore.instance
          .collection('onlineVideos')
          .doc(widget.videoId)
          .collection('comments')
          .add({
        'userId': user.uid,
        'userName': userName,
        'userProfilePic': userProfilePic,
        'comment': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'replies': 0,
      });

      _commentController.clear();
      
      // Scroll to top to show new comment
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add comment: ${e.toString()}'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  void _shareVideo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B1B1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildShareOption(Icons.download, 'Download', () {
                  Navigator.pop(context);
                }),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF4F46E5), size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CommentCard extends StatefulWidget {
  final String commentId;
  final Map<String, dynamic> commentData;
  final String videoId;

  const _CommentCard({
    required this.commentId,
    required this.commentData,
    required this.videoId,
  });

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  bool _isLiked = false;
  int _likes = 0;

  @override
  void initState() {
    super.initState();
    _likes = widget.commentData['likes'] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.commentData['userName'] ?? 'Anonymous';
    final userProfilePic = widget.commentData['userProfilePic'] ?? '';
    final comment = widget.commentData['comment'] ?? '';
    final createdAt = widget.commentData['createdAt'] as Timestamp?;
    final userId = widget.commentData['userId'] ?? '';

    return Card(
      elevation: 4,
      shadowColor: const Color(0xFF4F46E5).withOpacity(0.15),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF4F46E5).withOpacity(0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF4F46E5).withOpacity(0.2),
                  backgroundImage: userProfilePic.isNotEmpty
                      ? NetworkImage(userProfilePic)
                      : null,
                  child: userProfilePic.isEmpty
                      ? Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'A',
                          style: const TextStyle(
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          _formatDate(createdAt.toDate()),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (userId == FirebaseAuth.instance.currentUser?.uid)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteComment();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              comment,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                InkWell(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? const Color(0xFFE53935) : Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_likes',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: () {
                    // TODO: Implement reply functionality
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.reply, color: Colors.white70, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Reply',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
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
    );
  }

  Future<void> _toggleLike() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final increment = _isLiked ? -1 : 1;
      
      await FirebaseFirestore.instance
          .collection('onlineVideos')
          .doc(widget.videoId)
          .collection('comments')
          .doc(widget.commentId)
          .update({
        'likes': FieldValue.increment(increment),
      });

      setState(() {
        _isLiked = !_isLiked;
        _likes += increment;
      });
    } catch (e) {
    }
  }

  Future<void> _deleteComment() async {
    try {
      await FirebaseFirestore.instance
          .collection('onlineVideos')
          .doc(widget.videoId)
          .collection('comments')
          .doc(widget.commentId)
          .delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete comment: ${e.toString()}'),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
