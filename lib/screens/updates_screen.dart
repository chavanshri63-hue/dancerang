import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_state.dart';
import '../models/update_item.dart';
import '../widgets/section_scaffold.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});
  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  final _picker = ImagePicker();

  Future<void> _openEditor({int? index}) async {
    final existing = (index != null) ? AppState.updates.value[index] : null;
    final titleC = TextEditingController(text: existing?.title ?? "");
    final descC = TextEditingController(text: existing?.description ?? "");
    String? pickedPath = existing?.imagePath;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final inset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, inset + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text(index == null ? 'New update' : 'Edit update',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 8),
              TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: descC, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final x = await _picker.pickImage(source: ImageSource.gallery);
                      if (x != null) setState(() => pickedPath = x.path);
                    },
                    icon: const Icon(Icons.photo),
                    label: const Text('Add photo'),
                  ),
                  const SizedBox(width: 12),
                  if (pickedPath != null)
                    Expanded(
                      child: Text(File(pickedPath!).path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (titleC.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Title required')));
                      return;
                    }
                    final now = DateTime.now();
                    if (index == null) {
                      AppState.addUpdate(UpdateItem(
                        id: now.microsecondsSinceEpoch.toString(),
                        title: titleC.text.trim(),
                        description: descC.text.trim().isEmpty ? null : descC.text.trim(),
                        imagePath: pickedPath,
                        createdAt: now,
                      ));
                    } else {
                      final edited = existing!.copyWith(
                        title: titleC.text.trim(),
                        description: descC.text.trim().isEmpty ? null : descC.text.trim(),
                        imagePath: pickedPath,
                      );
                      AppState.editUpdateAt(index, edited);
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text(index == null ? 'Post update' : 'Save changes'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = AppState.currentRole.value;
    final canEdit = role == UserRole.admin || role == UserRole.faculty;

    return DRSectionScaffold(
      sectionTitle: 'Updates',
      actions: [
        if (canEdit)
          IconButton(
            tooltip: 'New update',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
          ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.pushNamed(context, '/notifications'),
          icon: const Icon(Icons.notifications_rounded),
        ),
      ],
      child: ValueListenableBuilder<List<UpdateItem>>(
        valueListenable: AppState.updates,
        builder: (_, list, __) {
          if (list.isEmpty) return const Text('No updates yet.');
          return Column(
            children: [
              for (int i = 0; i < list.length; i++) ...[
                _UpdateTile(
                  item: list[i],
                  canEdit: canEdit,
                  onEdit: () => _openEditor(index: i),
                  onDelete: () => AppState.removeUpdateAt(i),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _UpdateTile extends StatelessWidget {
  const _UpdateTile({required this.item, required this.canEdit, required this.onEdit, required this.onDelete});
  final UpdateItem item;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: (item.imagePath != null)
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(item.imagePath!), width: 48, height: 48, fit: BoxFit.cover),
              )
            : const Icon(Icons.campaign_rounded, size: 32),
        title: Text(item.title),
        subtitle: Text([
          if (item.description?.isNotEmpty == true) item.description!,
          "Posted ${item.createdAt}",
        ].join('\n')),
        isThreeLine: true,
        trailing: canEdit
            ? PopupMenuButton(
                itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              )
            : null,
      ),
    );
  }
}