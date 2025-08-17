import 'dart:io';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/workshop_item.dart';
import '../services/payments_service.dart';
import '../widgets/section_scaffold.dart';

class WorkshopsScreen extends StatelessWidget {
  const WorkshopsScreen({super.key});

  bool get _isAdmin => AppState.currentRole.value == UserRole.admin;

  @override
  Widget build(BuildContext context) {
    return DRSectionScaffold(
      sectionTitle: 'Workshops',
      actions: [
        if (_isAdmin)
          IconButton(
            tooltip: 'Add workshop',
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add_rounded),
          ),
      ],
      child: ValueListenableBuilder<List<WorkshopItem>>(
        valueListenable: AppState.workshops,
        builder: (_, items, __) {
          if (items.isEmpty) return const Text('No workshops yet.');
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (int i = 0; i < items.length; i++)
                _WorkshopCard(
                  item: items[i],
                  index: i,
                  onEdit: _openEditor,
                ),
            ],
          );
        },
      ),
    );
  }

  // ---------- CREATE / EDIT ----------
  Future<void> _openEditor(BuildContext context,
      {WorkshopItem? existing, int? index}) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final date = TextEditingController(text: existing?.date ?? '');
    final price = TextEditingController(
        text: existing == null ? '799' : existing!.price.toString());
    final hostName = TextEditingController(text: existing?.hostName ?? '');
    final hostImage = TextEditingController(text: existing?.hostImage ?? '');
    final registered = TextEditingController(
        text: (existing?.registered ?? const <String>[]).join(', '));

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add workshop' : 'Edit workshop'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: date, decoration: const InputDecoration(labelText: 'Date label')),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price (₹)'),
              ),
              TextField(controller: hostName, decoration: const InputDecoration(labelText: 'Host name')),
              TextField(controller: hostImage, decoration: const InputDecoration(labelText: 'Host image (file path optional)')),
              TextField(
                controller: registered,
                decoration: const InputDecoration(labelText: 'Registered (comma separated)'),
              ),
            ],
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () {
                AppState.deleteWorkshop(existing.id);
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
      final w = WorkshopItem(
        id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: title.text.trim(),
        date: date.text.trim(),
        price: int.tryParse(price.text.trim()) ?? 0,
        hostName: hostName.text.trim(),
        hostImage: hostImage.text.trim(),
        registered: registered.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      );

      if (existing == null) {
        AppState.addWorkshop(w);
      } else {
        AppState.updateWorkshop(index!, w);
      }
    }
  }
}

class _WorkshopCard extends StatelessWidget {
  const _WorkshopCard({required this.item, required this.index, required this.onEdit});
  final WorkshopItem item;
  final int index;
  final Future<void> Function(BuildContext, {WorkshopItem? existing, int? index}) onEdit;

  @override
  Widget build(BuildContext context) {
    final registeredCount = item.registered.length;
    final registeredPeek = item.registered.take(3).join(', ');

    return SizedBox(
      width: 250,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _HostAvatar(path: item.hostImage),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(item.date),
                      ],
                    ),
                  ),
                  Text('₹${item.price}'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.group_rounded, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      registeredCount == 0 ? 'No registrations' : '$registeredPeek${registeredCount > 3 ? '…' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await PaymentsService.openUpi(
                          upiId: AppState.defaultUpiId,
                          name: item.title,
                          amount: item.price,
                          note: item.date,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ok ? 'Opening payment app…' : 'No UPI app found')),
                          );
                        }
                      },
                      icon: const Icon(Icons.payment_rounded),
                      label: const Text('Join & Pay'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<String>(
                    valueListenable: AppState.memberName,
                    builder: (_, name, __) => IconButton.filledTonal(
                      tooltip: 'Register/Unregister',
                      onPressed: () => AppState.toggleRegisterForWorkshop(item.id, name),
                      icon: const Icon(Icons.how_to_reg_rounded),
                    ),
                  ),
                  if (AppState.currentRole.value == UserRole.admin) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () => onEdit(context, existing: item, index: index),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HostAvatar extends StatelessWidget {
  const _HostAvatar({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    if (path.isNotEmpty && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(path), width: 56, height: 56, fit: BoxFit.cover),
      );
    }
    return const CircleAvatar(
      radius: 28,
      child: Icon(Icons.person),
    );
  }
}