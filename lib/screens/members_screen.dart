// lib/screens/members_screen.dart
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/member.dart';

enum _Filter { all, active, inactive }

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;

  bool get _canManage =>
      AppState.currentRole.value == UserRole.admin ||
      AppState.currentRole.value == UserRole.faculty;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onToggle(Member m) {
    if (!_canManage) return;
    final list = [...AppState.members.value];
    final i = list.indexWhere((x) => x.id == m.id);
    if (i == -1) return;
    list[i] = m.copyWith(active: !m.active);
    AppState.members.value = list;
  }

  Future<void> _addMemberDialog() async {
    if (AppState.currentRole.value != UserRole.admin) return;

    final name = TextEditingController();
    final phone = TextEditingController();
    bool active = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (ctx, setS) => SwitchListTile(
                value: active,
                onChanged: (v) => setS(() => active = v),
                title: const Text('Active'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );

    if (ok == true && name.text.trim().isNotEmpty) {
      final newMember = Member(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.text.trim(),
        phone: phone.text.trim(),
        active: active,
      );
      AppState.members.value = [newMember, ...AppState.members.value];
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Member added: ${newMember.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context)
        .textTheme
        .headlineSmall
        ?.copyWith(fontWeight: FontWeight.w800);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DanceRang'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
            icon: const Icon(Icons.notifications_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ValueListenableBuilder<List<Member>>(
          valueListenable: AppState.members,
          builder: (_, members, __) {
            final q = _search.text.trim().toLowerCase();
            final filtered = members.where((m) {
              final matchesText = q.isEmpty ||
                  m.name.toLowerCase().contains(q) ||
                  m.phone.toLowerCase().contains(q);
              final matchesFilter = switch (_filter) {
                _Filter.all => true,
                _Filter.active => m.active,
                _Filter.inactive => !m.active,
              };
              return matchesText && matchesFilter;
            }).toList();

            final activeCount = members.where((m) => m.active).length;
            final inactiveCount = members.length - activeCount;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Align(alignment: Alignment.center, child: Text('Members', style: titleStyle)),
                const SizedBox(height: 12),

                // ---- Summary row (Wrap to avoid overflow)
                LayoutBuilder(
                  builder: (ctx, c) {
                    const spacing = 8.0;
                    final w = c.maxWidth;
                    final itemW = (w - (spacing * 2)) / 3;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        SizedBox(
                          width: itemW,
                          child: _SummaryTile(
                            icon: Icons.people_alt_rounded,
                            label: 'Total',
                            value: '${members.length}',
                          ),
                        ),
                        SizedBox(
                          width: itemW,
                          child: _SummaryTile(
                            icon: Icons.verified_rounded,
                            iconColor: Colors.green,
                            label: 'Active',
                            value: '$activeCount',
                          ),
                        ),
                        SizedBox(
                          width: itemW,
                          child: _SummaryTile(
                            icon: Icons.block_rounded,
                            iconColor: Colors.redAccent,
                            label: 'Inactive',
                            value: '$inactiveCount',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // ---- Search + filters + Add
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Search name or phone',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (AppState.currentRole.value == UserRole.admin)
                      FilledButton.icon(
                        onPressed: _addMemberDialog,
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                        label: const Text('Add'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _filter == _Filter.all,
                      onSelected: (_) => setState(() => _filter = _Filter.all),
                    ),
                    ChoiceChip(
                      label: const Text('Active'),
                      selected: _filter == _Filter.active,
                      onSelected: (_) => setState(() => _filter = _Filter.active),
                    ),
                    ChoiceChip(
                      label: const Text('Inactive'),
                      selected: _filter == _Filter.inactive,
                      onSelected: (_) => setState(() => _filter = _Filter.inactive),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ---- Members list
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: Text('No members found')),
                  )
                else
                  ...filtered.map(
                    (m) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(m.name.isNotEmpty ? m.name[0] : '?'),
                        ),
                        title: Text(m.name),
                        subtitle: Text('${m.phone} • ${m.active ? 'Active' : 'Inactive'}'),
                        trailing: _canManage
                            ? Switch(
                                value: m.active,
                                onChanged: (_) => _onToggle(m),
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (iconColor ?? Colors.white).withOpacity(.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon ?? Icons.info_outline, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}