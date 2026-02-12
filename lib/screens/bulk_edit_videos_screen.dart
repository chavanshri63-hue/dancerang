import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/glassmorphism_app_bar.dart';

class BulkEditVideosScreen extends StatefulWidget {
  final List<String> selectedVideoIds;
  
  const BulkEditVideosScreen({
    super.key,
    required this.selectedVideoIds,
  });

  @override
  State<BulkEditVideosScreen> createState() => _BulkEditVideosScreenState();
}

class _BulkEditVideosScreenState extends State<BulkEditVideosScreen> {
  String _selectedAction = 'status';
  String _selectedStatus = 'published';
  String _selectedDanceStyle = '';
  String _selectedInstructor = '';
  String _selectedSection = '';
  bool _isLive = false;
  bool _isPaid = false;
  bool _isLoading = false;
  
  List<String> _danceStyles = [];
  List<String> _instructors = [];
  List<String> _sections = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      // Load dance styles
      final stylesSnapshot = await FirebaseFirestore.instance
          .collection('onlineStyles')
          .get();
      
      // Load instructors
      final instructorsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'faculty')
          .get();

      setState(() {
        _danceStyles = stylesSnapshot.docs.map((doc) => doc.data()['name'] as String? ?? '').toList();
        _instructors = instructorsSnapshot.docs.map((doc) => doc.data()['name'] as String? ?? '').toList();
        _sections = ['Bollywood', 'Hip-Hop', 'Contemporary', 'Classical', 'Tutorials', 'Choreography', 'Practice', 'Live Recordings', 'Announcements'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading options: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'Bulk Edit Videos (${widget.selectedVideoIds.length})',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Action Selection
            _buildActionSelection(),
            const SizedBox(height: 20),
            
            // Action-specific fields
            _buildActionFields(),
            const SizedBox(height: 20),
            
            // Preview Changes
            _buildPreviewSection(),
            const SizedBox(height: 20),
            
            // Apply Button
            _buildApplyButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSelection() {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Action',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _selectedAction,
              decoration: const InputDecoration(
                labelText: 'Bulk Action',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(value: 'status', child: Text('Change Status')),
                DropdownMenuItem(value: 'style', child: Text('Change Dance Style')),
                DropdownMenuItem(value: 'instructor', child: Text('Change Instructor')),
                DropdownMenuItem(value: 'section', child: Text('Change Section')),
                DropdownMenuItem(value: 'live', child: Text('Toggle Live Status')),
                DropdownMenuItem(value: 'paid', child: Text('Toggle Paid Status')),
                DropdownMenuItem(value: 'delete', child: Text('Delete Videos')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedAction = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionFields() {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Action Details',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (_selectedAction == 'status') ...[
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'New Status',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                  DropdownMenuItem(value: 'published', child: Text('Published')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value!;
                  });
                },
              ),
            ] else if (_selectedAction == 'style') ...[
              DropdownButtonFormField<String>(
                value: _selectedDanceStyle.isEmpty ? null : _selectedDanceStyle,
                decoration: const InputDecoration(
                  labelText: 'New Dance Style',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Select Style')),
                  ..._danceStyles.map((style) => DropdownMenuItem(
                    value: style,
                    child: Text(style),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedDanceStyle = value ?? '';
                  });
                },
              ),
            ] else if (_selectedAction == 'instructor') ...[
              DropdownButtonFormField<String>(
                value: _selectedInstructor.isEmpty ? null : _selectedInstructor,
                decoration: const InputDecoration(
                  labelText: 'New Instructor',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Select Instructor')),
                  ..._instructors.map((instructor) => DropdownMenuItem(
                    value: instructor,
                    child: Text(instructor),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedInstructor = value ?? '';
                  });
                },
              ),
            ] else if (_selectedAction == 'section') ...[
              DropdownButtonFormField<String>(
                value: _selectedSection.isEmpty ? null : _selectedSection,
                decoration: const InputDecoration(
                  labelText: 'New Section',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Select Section')),
                  ..._sections.map((section) => DropdownMenuItem(
                    value: section,
                    child: Text(section),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedSection = value ?? '';
                  });
                },
              ),
            ] else if (_selectedAction == 'live') ...[
              SwitchListTile(
                title: const Text('Live Status', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  _isLive ? 'Videos will be marked as live' : 'Videos will be marked as not live',
                  style: const TextStyle(color: Colors.white70),
                ),
                value: _isLive,
                onChanged: (value) {
                  setState(() {
                    _isLive = value;
                  });
                },
                activeColor: const Color(0xFFE53935),
              ),
            ] else if (_selectedAction == 'paid') ...[
              SwitchListTile(
                title: const Text('Paid Status', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  _isPaid ? 'Videos will be marked as paid' : 'Videos will be marked as free',
                  style: const TextStyle(color: Colors.white70),
                ),
                value: _isPaid,
                onChanged: (value) {
                  setState(() {
                    _isPaid = value;
                  });
                },
                activeColor: const Color(0xFFE53935),
              ),
            ] else if (_selectedAction == 'delete') ...[
              const Card(
                color: Colors.red,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This action will permanently delete all selected videos. This cannot be undone.',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview Changes',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'Selected Videos: ${widget.selectedVideoIds.length}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            
            Text(
              'Action: ${_getActionDescription()}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  String _getActionDescription() {
    switch (_selectedAction) {
      case 'status':
        return 'Change status to $_selectedStatus';
      case 'style':
        return 'Change dance style to $_selectedDanceStyle';
      case 'instructor':
        return 'Change instructor to $_selectedInstructor';
      case 'section':
        return 'Change section to $_selectedSection';
      case 'live':
        return _isLive ? 'Mark as live' : 'Mark as not live';
      case 'paid':
        return _isPaid ? 'Mark as paid' : 'Mark as free';
      case 'delete':
        return 'Delete videos permanently';
      default:
        return 'No action selected';
    }
  }

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _applyChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedAction == 'delete' ? Colors.red : const Color(0xFFE53935),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                _selectedAction == 'delete' ? 'Delete Videos' : 'Apply Changes',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _applyChanges() async {
    if (_selectedAction != 'delete' && _selectedAction != 'live' && _selectedAction != 'paid') {
      if ((_selectedAction == 'style' && _selectedDanceStyle.isEmpty) ||
          (_selectedAction == 'instructor' && _selectedInstructor.isEmpty) ||
          (_selectedAction == 'section' && _selectedSection.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a value for the action')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      int successCount = 0;

      for (String videoId in widget.selectedVideoIds) {
        final videoRef = FirebaseFirestore.instance.collection('onlineVideos').doc(videoId);
        
        if (_selectedAction == 'delete') {
          batch.delete(videoRef);
        } else {
          Map<String, dynamic> updates = {};
          
          switch (_selectedAction) {
            case 'status':
              updates['status'] = _selectedStatus;
              break;
            case 'style':
              updates['danceStyle'] = _selectedDanceStyle;
              break;
            case 'instructor':
              updates['instructor'] = _selectedInstructor;
              break;
            case 'section':
              updates['section'] = _selectedSection;
              break;
            case 'live':
              updates['isLive'] = _isLive;
              break;
            case 'paid':
              updates['isPaid'] = _isPaid;
              break;
          }
          
          batch.update(videoRef, updates);
        }
        successCount++;
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedAction == 'delete'
                ? 'Successfully deleted $successCount videos'
                : 'Successfully updated $successCount videos',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true); // Return true to indicate success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error applying changes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
