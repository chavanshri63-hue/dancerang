import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/glassmorphism_app_bar.dart';

class AdminAttendanceReportsScreen extends StatefulWidget {
  const AdminAttendanceReportsScreen({super.key});

  @override
  State<AdminAttendanceReportsScreen> createState() => _AdminAttendanceReportsScreenState();
}

class _AdminAttendanceReportsScreenState extends State<AdminAttendanceReportsScreen> {
  List<Map<String, dynamic>> _attendanceData = [];
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load attendance data
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(_startDate))
          .where('timestamp', isLessThan: Timestamp.fromDate(_endDate.add(const Duration(days: 1))))
          .get();
      
      // Sort in memory to avoid index requirement
      final attendanceDocs = attendanceSnapshot.docs.toList()
        ..sort((a, b) {
          final aTime = (a.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final bTime = (b.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });

      _attendanceData = attendanceDocs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'studentId': data['userId'] ?? '',
          'studentName': data['studentName'] ?? 'Unknown',
          'className': data['className'] ?? 'Unknown',
          'instructor': data['instructor'] ?? 'Unknown',
          'timestamp': data['timestamp']?.toDate() ?? DateTime.now(),
          'status': data['status'] ?? 'present',
          'isLate': data['isLate'] ?? false,
        };
      }).toList();

      // Load student data for detailed reports
      await _loadStudentData();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStudentData() async {
    try {
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Student')
          .get();

      final studentData = studentsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'email': data['email'] ?? '',
          'phone': data['phone'] ?? '',
          'level': data['level'] ?? 'Beginner',
          'joinDate': data['createdAt']?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
    }
  }

  List<Map<String, dynamic>> get _filteredData {
    if (_selectedFilter == 'all') return _attendanceData;
    
    return _attendanceData.where((record) {
      switch (_selectedFilter) {
        case 'present':
          return record['status'] == 'present';
        case 'late':
          return record['isLate'] == true;
        case 'absent':
          return record['status'] == 'absent';
        default:
          return true;
      }
    }).toList();
  }

  Map<String, dynamic> get _summaryStats {
    final totalRecords = _attendanceData.length;
    final presentCount = _attendanceData.where((r) => r['status'] == 'present').length;
    final lateCount = _attendanceData.where((r) => r['isLate'] == true).length;
    final absentCount = _attendanceData.where((r) => r['status'] == 'absent').length;
    
    return {
      'totalRecords': totalRecords,
      'presentCount': presentCount,
      'lateCount': lateCount,
      'absentCount': absentCount,
      'attendanceRate': totalRecords > 0 ? (presentCount / totalRecords * 100).round() : 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'Attendance Reports',
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _exportToCSV,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAttendanceData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : Column(
              children: [
                _buildFilters(),
                _buildSummaryCards(),
                _buildDataTable(),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDatePicker(
                  'Start Date',
                  _startDate,
                  (date) => setState(() => _startDate = date),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDatePicker(
                  'End Date',
                  _endDate,
                  (date) => setState(() => _endDate = date),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedFilter,
            decoration: const InputDecoration(
              labelText: 'Status Filter',
              labelStyle: TextStyle(color: Colors.white70),
              border: OutlineInputBorder(),
            ),
            dropdownColor: const Color(0xFF1B1B1B),
            style: const TextStyle(color: Colors.white),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Records')),
              DropdownMenuItem(value: 'present', child: Text('Present Only')),
              DropdownMenuItem(value: 'late', child: Text('Late Only')),
              DropdownMenuItem(value: 'absent', child: Text('Absent Only')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedFilter = value ?? 'all';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime date, Function(DateTime) onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          onChanged(picked);
          _loadAttendanceData();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF262626)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final stats = _summaryStats;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Total Records',
              '${stats['totalRecords']}',
              Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'Present',
              '${stats['presentCount']}',
              Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'Late',
              '${stats['lateCount']}',
              Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'Absent',
              '${stats['absentCount']}',
              Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    final filteredData = _filteredData;
    
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Attendance Records (${filteredData.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Attendance Rate: ${_summaryStats['attendanceRate']}%',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredData.isEmpty
                  ? const Center(
                      child: Text(
                        'No records found',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFF262626)),
                        dataRowColor: WidgetStateProperty.all(Colors.transparent),
                        columns: const [
                          DataColumn(label: Text('Student', style: TextStyle(color: Colors.white))),
                          DataColumn(label: Text('Class', style: TextStyle(color: Colors.white))),
                          DataColumn(label: Text('Instructor', style: TextStyle(color: Colors.white))),
                          DataColumn(label: Text('Date', style: TextStyle(color: Colors.white))),
                          DataColumn(label: Text('Time', style: TextStyle(color: Colors.white))),
                          DataColumn(label: Text('Status', style: TextStyle(color: Colors.white))),
                        ],
                        rows: filteredData.map((record) {
                          final timestamp = record['timestamp'] as DateTime;
                          return DataRow(
                            cells: [
                              DataCell(Text(
                                record['studentName'],
                                style: const TextStyle(color: Colors.white70),
                              )),
                              DataCell(Text(
                                record['className'],
                                style: const TextStyle(color: Colors.white70),
                              )),
                              DataCell(Text(
                                record['instructor'],
                                style: const TextStyle(color: Colors.white70),
                              )),
                              DataCell(Text(
                                '${timestamp.day}/${timestamp.month}/${timestamp.year}',
                                style: const TextStyle(color: Colors.white70),
                              )),
                              DataCell(Text(
                                '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(color: Colors.white70),
                              )),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      record['status'] == 'present' ? Icons.check_circle : Icons.cancel,
                                      color: record['status'] == 'present' ? Colors.green : Colors.red,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      record['status'] == 'present' 
                                          ? (record['isLate'] ? 'Late' : 'Present')
                                          : 'Absent',
                                      style: TextStyle(
                                        color: record['status'] == 'present' 
                                            ? (record['isLate'] ? Colors.orange : Colors.green)
                                            : Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToCSV() async {
    try {
      final csvData = _filteredData.map((record) {
        final timestamp = record['timestamp'] as DateTime;
        return [
          record['studentName'],
          record['className'],
          record['instructor'],
          '${timestamp.day}/${timestamp.month}/${timestamp.year}',
          '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
          record['status'] == 'present' 
              ? (record['isLate'] ? 'Late' : 'Present')
              : 'Absent',
        ];
      }).toList();

      // Add header
      csvData.insert(0, ['Student Name', 'Class', 'Instructor', 'Date', 'Time', 'Status']);

      final csvString = const ListToCsvConverter().convert(csvData);
      
      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/attendance_report_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvString);

      // Share the file
      await Share.shareXFiles([XFile(file.path)], text: 'Attendance Report');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report exported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
