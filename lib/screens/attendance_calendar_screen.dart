import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:async';
import '../widgets/glassmorphism_app_bar.dart';
import '../services/attendance_alert_service.dart';
import '../services/payment_service.dart';

class AttendanceCalendarScreen extends StatefulWidget {
  const AttendanceCalendarScreen({super.key});

  @override
  State<AttendanceCalendarScreen> createState() => _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends State<AttendanceCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<AttendanceEvent>> _events = {};
  Map<String, dynamic> _attendanceSummary = {};
  bool _isLoading = true;
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadAttendanceData();
    
    // Listen to payment success events for real-time attendance updates
    _paymentRefreshSubscription = PaymentService.refreshStream.listen((event) {
      if (event['type'] == 'payment_success' && mounted) {
        // Refresh attendance data when payment succeeds
        _loadAttendanceData();
      }
    });
  }

  @override
  void dispose() {
    _paymentRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAttendanceData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load attendance summary
      final summary = await AttendanceAlertService.getStudentAttendanceSummary(user.uid);
      
      // Load attendance events for calendar
      await _loadAttendanceEvents(user.uid);

      setState(() {
        _attendanceSummary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAttendanceEvents(String userId) async {
    try {
      // Load attendance records
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .get();
      
      // Sort in memory to avoid index requirement
      final attendanceDocs = attendanceSnapshot.docs.toList()
        ..sort((a, b) {
          final aTime = (a.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final bTime = (b.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });

      final events = <DateTime, List<AttendanceEvent>>{};

      for (final doc in attendanceDocs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        
        if (timestamp != null) {
          final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
          
          if (events[day] == null) {
            events[day] = [];
          }
          
          events[day]!.add(AttendanceEvent(
            id: doc.id,
            className: data['className'] ?? 'Unknown Class',
            instructor: data['instructor'] ?? 'Unknown',
            time: timestamp,
            status: data['status'] ?? 'present',
            isLate: data['isLate'] ?? false,
          ));
        }
      }

      setState(() {
        _events = events;
      });
    } catch (e) {
    }
  }

  List<AttendanceEvent> _getEventsForDay(DateTime day) {
    return _events[day] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'Attendance Calendar',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : RefreshIndicator(
              onRefresh: _loadAttendanceData,
              color: const Color(0xFFE53935),
              child: SingleChildScrollView(
                child: Column(
              children: [
                _buildAttendanceSummary(),
                _buildCalendar(),
                _buildEventList(),
              ],
                ),
              ),
            ),
    );
  }

  Widget _buildAttendanceSummary() {
    final overallRate = _attendanceSummary['overallAttendanceRate'] ?? 0;
    final totalSessions = _attendanceSummary['totalSessions'] ?? 0;
    final attendedSessions = _attendanceSummary['attendedSessions'] ?? 0;
    final missedSessions = _attendanceSummary['missedSessions'] ?? 0;

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
            'Attendance Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Overall Rate',
                  '$overallRate%',
                  overallRate >= 80 ? Colors.green : overallRate >= 60 ? Colors.orange : Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Attended',
                  '$attendedSessions',
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Missed',
                  '$missedSessions',
                  Colors.red,
                ),
              ),
            ],
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
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: TableCalendar<AttendanceEvent>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        eventLoader: _getEventsForDay,
        startingDayOfWeek: StartingDayOfWeek.monday,
        calendarStyle: const CalendarStyle(
          outsideDaysVisible: false,
          weekendTextStyle: TextStyle(color: Colors.white70),
          defaultTextStyle: TextStyle(color: Colors.white),
          holidayTextStyle: TextStyle(color: Colors.white),
          selectedTextStyle: TextStyle(color: Colors.white),
          todayTextStyle: TextStyle(color: Colors.white),
          markersMaxCount: 3,
          markerDecoration: BoxDecoration(
            color: Color(0xFFE53935),
            shape: BoxShape.circle,
          ),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonShowsNext: false,
          formatButtonDecoration: BoxDecoration(
            color: Color(0xFFE53935),
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          formatButtonTextStyle: TextStyle(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 18),
          leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
          rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: Colors.white70),
          weekendStyle: TextStyle(color: Colors.white70),
        ),
        onDaySelected: (selectedDay, focusedDay) {
          if (!isSameDay(_selectedDay, selectedDay)) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          }
        },
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() {
              _calendarFormat = format;
            });
          }
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
      ),
    );
  }

  Widget _buildEventList() {
    final selectedEvents = _selectedDay != null ? _getEventsForDay(_selectedDay!) : <AttendanceEvent>[];

    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _selectedDay != null
                    ? 'Events on ${_formatDate(_selectedDay!)}'
                    : 'Select a date',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: selectedEvents.isEmpty
                  ? const Center(
                      child: Text(
                        'No events on this day',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      itemCount: selectedEvents.length,
                      itemBuilder: (context, index) {
                        final event = selectedEvents[index];
                        return _buildEventCard(event);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(AttendanceEvent event) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: event.status == 'present' ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: event.status == 'present' ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            event.status == 'present' ? Icons.check_circle : Icons.cancel,
            color: event.status == 'present' ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.className,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${event.instructor} • ${_formatTime(event.time)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                if (event.isLate)
                  const Text(
                    'Late',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class AttendanceEvent {
  final String id;
  final String className;
  final String instructor;
  final DateTime time;
  final String status;
  final bool isLate;

  AttendanceEvent({
    required this.id,
    required this.className,
    required this.instructor,
    required this.time,
    required this.status,
    required this.isLate,
  });
}
