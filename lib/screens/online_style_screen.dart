import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/video_item.dart';

class OnlineStyleScreen extends StatefulWidget {
  final String style;
  const OnlineStyleScreen({super.key, required this.style});

  @override
  State<OnlineStyleScreen> createState() => _OnlineStyleScreenState();
}

class _OnlineStyleScreenState extends State<OnlineStyleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _addVideo(String category) async {
    if (AppState.currentRole.value != UserRole.admin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admin can post videos')),
      );
      return;
    }
    final title = TextEditingController();
    final url = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(controller: url, decoration: const InputDecoration(labelText: 'URL')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );

    if (ok == true && title.text.trim().isNotEmpty && url.text.trim().isNotEmpty) {
      AppState.addVideo(
        style: widget.style,
        category: category,
        item: VideoItem(title: title.text.trim(), url: url.text.trim()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.style),
        bottom: TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'Foundation'), Tab(text: 'Choreography')],
        ),
        actions: [
          IconButton(
            tooltip: 'Add video (Admin)',
            onPressed: () => _addVideo(_tab.index == 0 ? 'Foundation' : 'Choreography'),
            icon: const Icon(Icons.add_circle_rounded),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _VideoList(style: widget.style, category: 'Foundation'),
          _VideoList(style: widget.style, category: 'Choreography'),
        ],
      ),
    );
  }
}

class _VideoList extends StatelessWidget {
  final String style;
  final String category;
  const _VideoList({required this.style, required this.category});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppState.videos,
      builder: (_, map, __) {
        final data = map as Map<String, Map<String, List<VideoItem>>>;
        final list = (data[style]?[category]) ?? const <VideoItem>[];
        if (list.isEmpty) return const Center(child: Text('No videos yet'));
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final v = list[i];
            final key = AppState.videoKey(style, category, v.title);
            final isSaved = AppState.isBookmarked(key);

            return Card(
              child: ListTile(
                leading: const Icon(Icons.play_circle_fill_rounded),
                title: Text(v.title),
                subtitle: Text(v.url),
                trailing: IconButton(
                  tooltip: isSaved ? 'Remove bookmark' : 'Bookmark',
                  onPressed: () => AppState.toggleBookmark(key),
                  icon: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                ),
                onTap: () {
                  ScaffoldMessenger.of(_).showSnackBar(
                    SnackBar(content: Text('Open player for "${v.title}"')),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}