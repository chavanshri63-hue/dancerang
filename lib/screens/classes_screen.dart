// lib/screens/classes_screen.dart
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/class_item.dart';
import '../models/member.dart';

class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DanceRang'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<List<ClassItem>>(
          valueListenable: AppState.classes,
          builder: (_, list, __) {
            if (list.isEmpty) return const Text('No classes yet.');

            return ValueListenableBuilder<UserRole>(
              valueListenable: AppState.role,
              builder: (_, role, __) {
                final isAdmin = role == UserRole.admin;
                return Column(
                  children: [
                    for (int i = 0; i < list.length; i++) ...[
                      _ClassTile(item: list[i], index: i, isAdmin: isAdmin),
                      const SizedBox(height: 10),
                    ]
                  ],
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: ValueListenableBuilder<UserRole>(
        valueListenable: AppState.role,
        builder: (_, r, __) => r == UserRole.admin
            ? FloatingActionButton(
                onPressed: () => Navigator.pushNamed(context, '/class/editor'),
                child: const Icon(Icons.add),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({required this.item, required this.index, required this.isAdmin});
  final ClassItem item;
  final int index;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${item.days}   ·   ${item.timeLabel}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAdmin)
              IconButton(
                tooltip: 'Edit',
                onPressed: () => Navigator.pushNamed(
                  context, '/class/editor',
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
        onTap: () => Navigator.pushNamed(context, '/class/detail', arguments: item),
      ),
    );
  }
}