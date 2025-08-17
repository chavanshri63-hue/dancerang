import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_state.dart';

class DashboardContentManagerScreen extends StatefulWidget {
  const DashboardContentManagerScreen({super.key});

  @override
  State<DashboardContentManagerScreen> createState() => _DashboardContentManagerScreenState();
}

class _DashboardContentManagerScreenState extends State<DashboardContentManagerScreen> {
  final _picker = ImagePicker();

  Future<void> _pickBg() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final s = AppState.settings.value.copy();
    s.dashboardBgPath = x.path;
    AppState.settings.value = s;
    await AppState.saveSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Background updated')));
    }
  }

  Future<void> _addCard() async {
    final title = TextEditingController();
    String? path;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add content card'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final x = await _picker.pickImage(source: ImageSource.gallery);
                if (x != null) {
                  path = x.path;
                  setState(() {});
                }
              },
              icon: const Icon(Icons.photo),
              label: const Text('Pick image'),
            ),
            if (path != null) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(File(path!).path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );

    if (ok == true && (title.text.trim().isNotEmpty || (path?.isNotEmpty ?? false))) {
      final s = AppState.settings.value.copy();
      s.bannerItems.insert(0, BannerItem(title: title.text.trim(), path: path));
      AppState.settings.value = s;
      await AppState.saveSettings();
    }
  }

  Future<void> _editCard(int i) async {
    final s = AppState.settings.value.copy();
    final item = s.bannerItems[i];
    final title = TextEditingController(text: item.title ?? '');
    String? path = item.path;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit card'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final x = await _picker.pickImage(source: ImageSource.gallery);
                if (x != null) {
                  path = x.path;
                  setState(() {});
                }
              },
              icon: const Icon(Icons.photo),
              label: const Text('Change image'),
            ),
            if (path != null) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(File(path!).path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              s.bannerItems.removeAt(i);
              AppState.settings.value = s;
              AppState.saveSettings();
              Navigator.pop(context, null);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok == true) {
      s.bannerItems[i] = BannerItem(title: title.text.trim(), path: path);
      AppState.settings.value = s;
      await AppState.saveSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: AppState.settings,
      builder: (_, s, __) {
        final bg = s.dashboardBgPath;
        final hasBg = bg != null && bg.isNotEmpty && File(bg).existsSync();

        return Scaffold(
          appBar: AppBar(
            title: const Text('DanceRang'),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              const Text('Dashboard background', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: hasBg
                      ? Image.file(File(bg!), fit: BoxFit.cover)
                      : Image.asset('assets/images/placeholder_bg.jpg', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickBg,
                icon: const Icon(Icons.wallpaper_rounded),
                label: const Text('Change background image'),
              ),

              const Divider(height: 32),
              const Text('Content cards', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (int i = 0; i < s.bannerItems.length; i++)
                    SizedBox(
                      width: 240,
                      child: InkWell(
                        onTap: () => _editCard(i),
                        child: Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: (s.bannerItems[i].path != null &&
                                          s.bannerItems[i].path!.isNotEmpty &&
                                          File(s.bannerItems[i].path!).existsSync())
                                      ? Image.file(File(s.bannerItems[i].path!), fit: BoxFit.cover)
                                      : Image.asset('assets/images/placeholder_bg.jpg', fit: BoxFit.cover),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                child: Text(s.bannerItems[i].title ?? '—',
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Add new
                  SizedBox(
                    width: 240,
                    child: OutlinedButton.icon(
                      onPressed: _addCard,
                      icon: const Icon(Icons.add_circle_rounded),
                      label: const Text('Add card'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}