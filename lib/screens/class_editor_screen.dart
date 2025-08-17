// lib/screens/class_editor_screen.dart
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/class_item.dart';
import '../widgets/section_scaffold.dart';

class ClassEditorScreen extends StatefulWidget {
  const ClassEditorScreen({super.key});

  @override
  State<ClassEditorScreen> createState() => _ClassEditorScreenState();
}

class _ClassEditorScreenState extends State<ClassEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _style = TextEditingController();
  final _days = TextEditingController();
  final _time = TextEditingController();
  final _teacher = TextEditingController();
  final _fee = TextEditingController();

  int? editIndex;
  String? editId;

  @override
  void initState() {
    super.initState();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['item'] != null) {
      final ClassItem c = args['item'];
      editIndex = args['index'] as int?;
      editId = c.id;
      _title.text = c.title;
      _style.text = c.style;
      _days.text = c.days;
      _time.text = c.timeLabel;
      _teacher.text = c.teacher;
      _fee.text = c.feeInr.toString();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _style.dispose();
    _days.dispose();
    _time.dispose();
    _teacher.dispose();
    _fee.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;

    final item = ClassItem(
      id: editId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      style: _style.text.trim(),
      days: _days.text.trim(),
      timeLabel: _time.text.trim(),
      teacher: _teacher.text.trim(),
      feeInr: int.tryParse(_fee.text.trim()) ?? 0,
      roster: const [],
    );

    if (editIndex != null) {
      AppState.updateClassAt(editIndex!, item);
    } else {
      AppState.addClass(item);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DRSectionScaffold(
      sectionTitle: editIndex == null ? 'New Class' : 'Edit Class',
      child: Form(
        key: _form,
        child: Column(
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title *'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(controller: _style, decoration: const InputDecoration(labelText: 'Style')),
            const SizedBox(height: 10),
            TextFormField(controller: _days, decoration: const InputDecoration(labelText: 'Days (e.g. Mon · Wed · Fri)')),
            const SizedBox(height: 10),
            TextFormField(controller: _time, decoration: const InputDecoration(labelText: 'Time (e.g. 6–7 PM)')),
            const SizedBox(height: 10),
            TextFormField(controller: _teacher, decoration: const InputDecoration(labelText: 'Teacher')),
            const SizedBox(height: 10),
            TextFormField(
              controller: _fee,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Fee (₹)'),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}