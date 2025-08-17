// lib/screens/update_form.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/update_item.dart';

class UpdateFormScreen extends StatefulWidget {
  final UpdateItem? initial;
  const UpdateFormScreen({super.key, this.initial});

  @override
  State<UpdateFormScreen> createState() => _UpdateFormScreenState();
}

class _UpdateFormScreenState extends State<UpdateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  DateTime _createdAt = DateTime.now();
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _title.text = i.title;
      _desc.text = i.description ?? '';
      _createdAt = i.createdAt;
      _imagePath = i.imagePath;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _imagePath = x.path);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _createdAt,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null) setState(() => _createdAt = d);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final item = UpdateItem(
      id: widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      imagePath: _imagePath,
      createdAt: _createdAt,
    );

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final imgFile = _imagePath == null ? null : File(_imagePath!);

    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? 'Add Update' : 'Edit Update')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Date: ${_createdAt.toLocal().toString().split(' ').first}'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event),
                  label: const Text('Pick date'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (imgFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(imgFile, height: 180, fit: BoxFit.cover),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo),
              label: Text(_imagePath == null ? 'Add photo' : 'Change photo'),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}