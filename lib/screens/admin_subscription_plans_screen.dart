import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/glassmorphism_app_bar.dart';

class AdminSubscriptionPlansScreen extends StatefulWidget {
  const AdminSubscriptionPlansScreen({super.key});

  @override
  State<AdminSubscriptionPlansScreen> createState() => _AdminSubscriptionPlansScreenState();
}

class _AdminSubscriptionPlansScreenState extends State<AdminSubscriptionPlansScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: const GlassmorphismAppBar(title: 'Subscription Plans'),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE53935),
        onPressed: _openCreate,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('subscription_plans').orderBy('priority').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No plans yet', style: TextStyle(color: Colors.white70)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final id = docs[i].id;
              return Card(
                color: Theme.of(context).cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: const Color(0xFFE53935).withOpacity(0.22))),
                child: ListTile(
                  title: Text('${d['name']} • ₹${d['price']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: Text('${d['billingCycle']} • ${d['description'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                  trailing: PopupMenuButton<String>(
                    color: const Color(0xFF1B1B1B),
                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                    onSelected: (v) {
                      if (v == 'edit') _openEdit(id);
                      if (v == 'delete') _delete(id);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
                      PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.white))),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openCreate() async {
    await showDialog(context: context, builder: (_) => const _EditPlanDialog());
  }

  Future<void> _openEdit(String id) async {
    await showDialog(context: context, builder: (_) => _EditPlanDialog(planId: id));
  }

  Future<void> _delete(String id) async {
    await FirebaseFirestore.instance.collection('subscription_plans').doc(id).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan deleted'), backgroundColor: Colors.red));
  }
}

class _EditPlanDialog extends StatefulWidget {
  final String? planId;
  const _EditPlanDialog({this.planId});

  @override
  State<_EditPlanDialog> createState() => _EditPlanDialogState();
}

class _EditPlanDialogState extends State<_EditPlanDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  final TextEditingController _storeProductId = TextEditingController();
  final TextEditingController _playProductId = TextEditingController();
  final TextEditingController _appStoreProductId = TextEditingController();
  String _billing = 'monthly';
  int _priority = 1;
  bool _trial = false;
  int _trialDays = 7;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.planId != null) _load();
  }

  Future<void> _load() async {
    final doc = await FirebaseFirestore.instance.collection('subscription_plans').doc(widget.planId).get();
    final d = doc.data() ?? {};
    setState(() {
      _name.text = (d['name'] ?? '').toString();
      _price.text = (d['price'] ?? 0).toString();
      _desc.text = (d['description'] ?? '').toString();
      _storeProductId.text = (d['storeProductId'] ?? '').toString();
      _playProductId.text = (d['playProductId'] ?? '').toString();
      _appStoreProductId.text = (d['appStoreProductId'] ?? '').toString();
      _billing = (d['billingCycle'] ?? 'monthly').toString();
      _priority = (d['priority'] ?? 1) as int;
      _trial = d['trialEnabled'] == true;
      _trialDays = (d['trialDays'] ?? 7) as int;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: Text(widget.planId == null ? 'Create Plan' : 'Edit Plan', style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Plan Name')),
            const SizedBox(height: 12),
            TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (₹)')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _billing,
              decoration: const InputDecoration(labelText: 'Billing Cycle'),
              items: const [
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                DropdownMenuItem(value: 'annual', child: Text('Annual')),
              ],
              onChanged: (v) => setState(() => _billing = v ?? 'monthly'),
            ),
            const SizedBox(height: 12),
            TextField(controller: _desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 12),
            TextField(controller: _storeProductId, decoration: const InputDecoration(labelText: 'Store Product ID (fallback)')),
            const SizedBox(height: 12),
            TextField(controller: _playProductId, decoration: const InputDecoration(labelText: 'Play Store Product ID')),
            const SizedBox(height: 12),
            TextField(controller: _appStoreProductId, decoration: const InputDecoration(labelText: 'App Store Product ID')),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: '$_priority'),
              decoration: const InputDecoration(labelText: 'Priority (sort order)'),
              keyboardType: TextInputType.number,
              onChanged: (v) => _priority = int.tryParse(v) ?? 1,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Enable Trial', style: TextStyle(color: Colors.white)),
              value: _trial,
              onChanged: (v) => setState(() => _trial = v),
              activeThumbColor: const Color(0xFFE53935),
            ),
            if (_trial) TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Trial Days'), onChanged: (v) => _trialDays = int.tryParse(v) ?? 7),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() { _loading = true; });
    try {
      final data = {
        'name': _name.text.trim(),
        'price': int.tryParse(_price.text.trim()) ?? 0,
        'billingCycle': _billing,
        'description': _desc.text.trim(),
        'storeProductId': _storeProductId.text.trim(),
        'playProductId': _playProductId.text.trim(),
        'appStoreProductId': _appStoreProductId.text.trim(),
        'priority': _priority,
        'trialEnabled': _trial,
        'trialDays': _trial ? _trialDays : 0,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final col = FirebaseFirestore.instance.collection('subscription_plans');
      if (widget.planId == null) {
        await col.add({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
          'active': true,
        });
      } else {
        await col.doc(widget.planId).set(data, SetOptions(merge: true));
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }
}


