import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/class_item.dart';
import '../widgets/section_scaffold.dart';

class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});

  bool get _isAdmin => AppState.currentRole == 'admin';

  @override
  Widget build(BuildContext context) {
    return DRSectionScaffold(
      sectionTitle: 'Classes',
      actions: [
        if (_isAdmin)
          IconButton(
            tooltip: 'Add class',
            onPressed: () => Navigator.pushNamed(context, '/class/editor'),
            icon: const Icon(Icons.add_circle_rounded),
          ),
      ],
      child: ValueListenableBuilder<List<ClassItem>>(
        valueListenable: AppState.classes,
        builder: (_, list, __) {
          if (list.isEmpty) {
            return const Text('No classes yet.');
          }
          return Column(
            children: [
              for (int i = 0; i < list.length; i++) ...[
                _ClassTile(item: list[i], index: i, isAdmin: _isAdmin),
                const SizedBox(height: 10),
              ]
            ],
          );
        },
      ),
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({
    required this.item,
    required this.index,
    required this.isAdmin,
  });

  final ClassItem item;
  final int index;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${item.days}   ·   ${item.timeLabel}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAdmin)
              IconButton(
                tooltip: 'Edit',
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/class/editor',
                  arguments: {'index': index, 'item': item},
                ),
                icon: const Icon(Icons.edit_rounded),
              ),
            if (isAdmin)
              IconButton(
                tooltip: 'Delete',
                onPressed: () => AppState.removeClassAt(index),
                icon: const Icon(Icons.delete_forever_rounded),
              ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
        onTap: () => Navigator.pushNamed(
          context,
          '/class/detail',
          arguments: item,
        ),
      ),
    );
  }
}