import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../app_state.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});
  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _form = GlobalKey<FormState>();
  late AppSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = AppState.settings.value.copy();
  }

  Future<void> _pickBg() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    setState(() => _draft.dashboardBgPath = x.path);
  }

  Future<void> _addBanner() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    setState(() {
      _draft.bannerItems.add(BannerItem(title: 'New banner', path: x.path));
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings', jsonEncode(_draft.toJson()));
    AppState.settings.value = _draft.copy();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red),
              child: const Text('Save'),
            ),
          )
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            _Section('Contact'),
            _TextBox(
              label: 'Admin phone (+91…)',
              initial: _draft.adminPhone ?? '',
              onSaved: (v) => _draft.adminPhone = v?.trim(),
            ),
            _TextBox(
              label: 'WhatsApp (+91…)',
              initial: _draft.whatsapp ?? '',
              onSaved: (v) => _draft.whatsapp = v?.trim(),
            ),
            _TextBox(
              label: 'Email',
              initial: _draft.email ?? '',
              onSaved: (v) => _draft.email = v?.trim(),
            ),
            _TextBox(
              label: 'Address/City',
              initial: _draft.address ?? '',
              onSaved: (v) => _draft.address = v?.trim(),
            ),
            _TextBox(
              label: 'Hours',
              initial: _draft.hours ?? '',
              onSaved: (v) => _draft.hours = v?.trim(),
            ),
            _TextBox(
              label: 'Default UPI ID',
              initial: _draft.upi ?? '',
              onSaved: (v) => _draft.upi = v?.trim(),
            ),
            const SizedBox(height: 20),

            _Section('Dashboard Background'),
            Row(
              children: [
                Expanded(
                  child: _draft.dashboardBgPath?.isNotEmpty == true &&
                          File(_draft.dashboardBgPath!).existsSync()
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(File(_draft.dashboardBgPath!),
                              height: 80, fit: BoxFit.cover))
                      : Container(
                          height: 80,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('No image selected'),
                        ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _pickBg,
                  child: const Text('Pick'),
                ),
              ],
            ),

            const SizedBox(height: 24),
            _Section('Home Banners'),
            ..._draft.bannerItems.asMap().entries.map((e) {
              final i = e.key;
              final b = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: b.title ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: InputBorder.none,
                        ),
                        onChanged: (v) => b.title = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (b.path != null && File(b.path!).existsSync())
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(b.path!), height: 48, width: 72, fit: BoxFit.cover),
                      )
                    else
                      const SizedBox(height: 48, width: 72),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _draft.bannerItems.removeAt(i)),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _addBanner,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add banner'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ——— UI bits ———
class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 12),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _TextBox extends StatelessWidget {
  final String label;
  final String initial;
  final FormFieldSetter<String> onSaved;
  const _TextBox({required this.label, required this.initial, required this.onSaved});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        initialValue: initial,
        decoration: InputDecoration(labelText: label, border: InputBorder.none),
        onSaved: onSaved,
      ),
    );
  }
}