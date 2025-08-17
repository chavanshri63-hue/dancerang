// lib/screens/class_detail_screen.dart
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/class_item.dart';
import '../services/payments_service.dart';
import '../widgets/section_scaffold.dart';

class ClassDetailScreen extends StatelessWidget {
  const ClassDetailScreen({super.key});

  bool get _isAdmin => AppState.currentRole.value == UserRole.admin;
  bool get _isFaculty => AppState.currentRole.value == UserRole.faculty;

  @override
  Widget build(BuildContext context) {
    final ClassItem item = ModalRoute.of(context)!.settings.arguments as ClassItem;

    return DRSectionScaffold(
      sectionTitle: 'Class Details',
      actions: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: ListTile(
              title: Text(item.title),
              subtitle: Text('${item.style} • ${item.days} • ${item.timeLabel}\nTeacher: ${item.teacher}'),
              isThreeLine: true,
              trailing: Text('₹${item.feeInr}'),
            ),
          ),
          const SizedBox(height: 10),

          // Student action
          FilledButton.icon(
            onPressed: () => _joinAndPay(context, item),
            icon: const Icon(Icons.payment_rounded),
            label: const Text('Join & Pay'),
          ),

          const SizedBox(height: 16),
          Text('Roster', style: Theme.of(context).textTheme.titleMedium),

          const SizedBox(height: 8),
          ValueListenableBuilder<List<ClassItem>>(
            valueListenable: AppState.classes,
            builder: (_, list, __) {
              final current = list.firstWhere((c) => c.id == item.id, orElse: () => item);
              if (current.roster.isEmpty) {
                return const Text('No members yet.');
              }
              return Column(
                children: [
                  for (final m in current.roster) ...[
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(m),
                        trailing: (_isFaculty || _isAdmin)
                            ? IconButton(
                                tooltip: 'Remove',
                                onPressed: () => AppState.removeMemberFromClass(item.id, m),
                                icon: const Icon(Icons.remove_circle_outline_rounded),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ]
                ],
              );
            },
          ),

          if (_isFaculty || _isAdmin) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _addMemberDialog(context, item.id),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add member to roster'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _joinAndPay(BuildContext context, ClassItem c) async {
    final ok = await PaymentsService.openUpi(
      upiId: AppState.defaultUpiId,
      name: 'DanceRang • ${c.title}',
      amount: c.feeInr,
      note: 'Class fee for ${c.title}',
    );

    if (!context.mounted) return;
    if (ok) {
      AppState.joinClass(c.id, AppState.memberName.value);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment initiated. Added to roster.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No UPI app found / Payment cancelled')),
      );
    }
  }

  Future<void> _addMemberDialog(BuildContext context, String classId) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add member'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Member name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      AppState.addMemberToClass(classId, ctrl.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added: ${ctrl.text.trim()}')),
        );
      }
    }
  }
}