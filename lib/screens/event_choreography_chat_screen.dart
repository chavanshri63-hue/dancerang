import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class EventChoreoChatScreen extends StatefulWidget {
  final String bookingId;
  final bool isAdmin;

  const EventChoreoChatScreen({super.key, required this.bookingId, required this.isAdmin});

  @override
  State<EventChoreoChatScreen> createState() => _EventChoreoChatScreenState();
}

class _EventChoreoChatScreenState extends State<EventChoreoChatScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _waNumber;

  @override
  void initState() {
    super.initState();
    _loadWhatsAppNumber();
  }

  Future<void> _loadWhatsAppNumber() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('appSettings').doc('eventChoreo').get();
      setState(() {
        _waNumber = (doc.data() ?? const {})['whatsappNumber'] as String?;
      });
    } catch (_) {}
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream() {
    return FirebaseFirestore.instance
        .collection('eventChoreoBookings')
        .doc(widget.bookingId)
        .collection('messages')
        .orderBy('ts', descending: true)
        .snapshots();
  }

  Future<void> _send() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    final ref = FirebaseFirestore.instance
        .collection('eventChoreoBookings')
        .doc(widget.bookingId)
        .collection('messages')
        .doc();

    await ref.set({
      'id': ref.id,
      'senderId': user.uid,
      'senderRole': widget.isAdmin ? 'admin' : 'client',
      'text': text,
      'ts': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversation'),
        backgroundColor: const Color(0xFF0A0A0A),
        actions: [
          if (_waNumber != null && _waNumber!.trim().isNotEmpty)
            IconButton(
              tooltip: 'Open WhatsApp',
              onPressed: _openWhatsApp,
              icon: const Icon(Icons.chat, color: Colors.greenAccent),
            ),
        ],
      ),
      backgroundColor: const Color(0xFF0A0A0A),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messagesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Failed to load messages', style: TextStyle(color: Colors.white70)),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white70));
                }
                final msgs = snapshot.data?.docs ?? [];
                if (msgs.isEmpty) {
                  return const Center(
                    child: Text('No messages yet', style: TextStyle(color: Colors.white70)),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: msgs.length,
                  itemBuilder: (context, index) {
                    final m = msgs[index].data();
                    final isMine = m['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMine ? const Color(0xFFE53935) : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          m['text'] ?? '',
                          style: TextStyle(color: isMine ? Colors.white : Colors.white),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    if (_waNumber == null || _waNumber!.trim().isEmpty) return;
    final phone = _waNumber!.replaceAll(RegExp(r'[^0-9+]'), '');
    final Uri uri = Uri.parse('https://wa.me/$phone?text=' + Uri.encodeComponent('Hello, regarding booking ${widget.bookingId}'));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open WhatsApp')),
      );
    }
  }
}


