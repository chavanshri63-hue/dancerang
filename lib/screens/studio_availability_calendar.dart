import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:async';
import '../services/payment_service.dart';

class StudioAvailabilityCalendar extends StatefulWidget {
  @override
  _StudioAvailabilityCalendarState createState() => _StudioAvailabilityCalendarState();
}

class _StudioAvailabilityCalendarState extends State<StudioAvailabilityCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, Map<String, List<String>>> _availabilityOverrides = {};
  List<Map<String, String>> _weeklyBlockedRanges = [];
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadAvailabilitySettings();
    
    // Listen to payment success events for real-time studio booking updates
    _paymentRefreshSubscription = PaymentService.refreshStream.listen((event) {
      if (event['type'] == 'payment_success' && 
          (event['paymentType'] == 'studio_booking' || event['paymentType'] == 'studio') && mounted) {
        // Force rebuild when studio booking payment succeeds
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _paymentRefreshSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAvailabilitySettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('studioAvailability')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _availabilityOverrides = Map<String, Map<String, List<String>>>.from(
            (data['overrides'] ?? {}).map<String, Map<String, List<String>>>((k, v) => MapEntry(
                  k as String,
                  {
                    'availableTimes': List<String>.from((v['availableTimes'] ?? []) as List),
                    'blockedTimes': List<String>.from((v['blockedTimes'] ?? []) as List),
                  },
                )),
          );
          _weeklyBlockedRanges = List<Map<String, String>>.from(
            (data['weeklyRule']?['blockedRanges'] ?? []).map<Map<String, String>>((r) => {
                  'start': r['start'] as String,
                  'end': r['end'] as String,
                }),
          );
        });
      }
    } catch (e) {
    }
  }

  // Add method to refresh bookings
  void _refreshBookings() {
    // Stream will automatically refresh
    setState(() {});
  }

  String _formatDateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _isBlockedByWeeklyRule(String time) {
    // time: HH:00
    final hour = int.parse(time.split(':')[0]);
    for (final range in _weeklyBlockedRanges) {
      final startHour = int.parse(range['start']!.split(':')[0]);
      final endHour = int.parse(range['end']!.split(':')[0]);
      if (hour >= startHour && hour < endHour) return true;
    }
    return false;
  }

  bool _isAvailableForDate(DateTime date, String time) {
    final key = _formatDateKey(date);
    final override = _availabilityOverrides[key];
    if (override != null) {
      if (override['blockedTimes']!.contains(time)) return false;
      if (override['availableTimes']!.contains(time)) return true;
    }
    // Default: available unless weekly rule blocks it
    return !_isBlockedByWeeklyRule(time);
  }

  // Show available times popup for selected date
  void _showAvailableTimesPopup(DateTime selectedDate) {
    final dayKey = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<Map<DateTime, List<Map<String, dynamic>>>>(
        stream: _getBookingsStream(),
        builder: (context, snapshot) {
          final bookings = snapshot.data ?? {};
          final dayBookings = bookings[dayKey] ?? [];
          
          // Generate available time slots (9 AM to 10 PM, 1-hour slots)
          final availableSlots = <String>[];
          for (int hour = 9; hour <= 22; hour++) {
            final timeSlot = '${hour.toString().padLeft(2, '0')}:00';
            
            // Check if admin has blocked this time slot
            if (!_isAvailableForDate(selectedDate, timeSlot)) {
              continue; // Skip this time slot - admin has blocked it
            }
            
            // Check if this time slot conflicts with any existing booking
            bool hasConflict = false;
            for (final booking in dayBookings) {
              final bookingTime = booking['time'] as String;
              final duration = booking['duration'] as int;
              
              // Calculate booking end time
              final timeParts = bookingTime.split(':');
              final bookingStartHour = int.parse(timeParts[0]);
              final bookingEndHour = bookingStartHour + duration;
              
              // Check if our time slot overlaps with the booking
              if (hour >= bookingStartHour && hour < bookingEndHour) {
                hasConflict = true;
                break;
              }
            }
            
            if (!hasConflict) {
              availableSlots.add(timeSlot);
            }
          }
          
          return AlertDialog(
            backgroundColor: const Color(0xFF1B1B1B),
            title: Text(
              'Available Times - ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dayBookings.isNotEmpty) ...[
                    const Text(
                      'Booked Times:',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...dayBookings.map((booking) {
                      // Calculate end time
                      final startTime = booking['time'] as String;
                      final duration = booking['duration'] as int;
                      final timeParts = startTime.split(':');
                      final startHour = int.parse(timeParts[0]);
                      final startMinute = int.parse(timeParts[1]);
                      final endHour = startHour + duration;
                      final endTime = '${endHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D2D2D),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: booking['status'] == 'confirmed' 
                                    ? Colors.green 
                                    : booking['status'] == 'in_progress'
                                        ? Colors.blue
                                        : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$startTime - $endTime (${booking['name']} - ${duration}h)',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                  
                  const Text(
                    'Available Times:',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  if (availableSlots.isEmpty)
                    const Text(
                      'No available time slots for this date',
                      style: TextStyle(color: Colors.white70),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableSlots.map((time) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          time,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      )).toList(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.white70)),
              ),
            ],
          );
        },
      ),
    );
  }

  // Stream for real-time booking updates
  Stream<Map<DateTime, List<Map<String, dynamic>>>> _getBookingsStream() async* {
    while (true) {
      try {
        // Load bookings for a wider range to include future bookings
        final startDate = DateTime.now().subtract(const Duration(days: 7)); // Include past week
        final endDate = startDate.add(const Duration(days: 365)); // Include next year
        
        QuerySnapshot<Map<String, dynamic>> bookingsSnapshot;
        
        try {
          // Try the indexed query first
          bookingsSnapshot = await FirebaseFirestore.instance
              .collection('studioBookings')
              .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
              .where('date', isLessThan: Timestamp.fromDate(endDate))
              .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
              .get();
        } catch (e) {
          // Fallback: Load bookings with basic filtering and filter client-side
          final allBookings = await FirebaseFirestore.instance
              .collection('studioBookings')
              .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
              .get();
          
          // Filter by date only (status already filtered at Firestore level)
          final filteredDocs = allBookings.docs.where((doc) {
            final data = doc.data();
            final date = (data['date'] as Timestamp?)?.toDate();
            
            if (date == null) return false;
            
            // Check if date is within our range
            return date.isAfter(startDate.subtract(const Duration(days: 1))) && 
                   date.isBefore(endDate);
          }).toList();
          
          // Process filtered docs directly
          final bookings = <DateTime, List<Map<String, dynamic>>>{};
          
          for (final doc in filteredDocs) {
            final data = doc.data();
            final date = (data['date'] as Timestamp).toDate();
            final day = DateTime(date.year, date.month, date.day);
            
            if (bookings[day] == null) {
              bookings[day] = [];
            }
            
            bookings[day]!.add({
              'id': doc.id,
              'time': data['time'] ?? '00:00',
              'duration': data['duration'] ?? 1,
              'name': data['name'] ?? 'Unknown',
              'status': data['status'] ?? 'pending',
            });
          }
          
          // Debug logging for fallback
          for (final entry in bookings.entries) {
            for (final booking in entry.value) {
            }
          }
          
          yield bookings;
          await Future.delayed(const Duration(seconds: 30)); // Refresh every 30 seconds
          continue;
        }

        final bookings = <DateTime, List<Map<String, dynamic>>>{};
        
        for (final doc in bookingsSnapshot.docs) {
          final data = doc.data();
          final date = (data['date'] as Timestamp).toDate();
          final day = DateTime(date.year, date.month, date.day);
          
          if (bookings[day] == null) {
            bookings[day] = [];
          }
          
          bookings[day]!.add({
            'id': doc.id,
            'time': data['time'] ?? '00:00',
            'duration': data['duration'] ?? 1,
            'name': data['name'] ?? 'Unknown',
            'status': data['status'] ?? 'pending',
          });
        }
        
        // Debug logging
        for (final entry in bookings.entries) {
          for (final booking in entry.value) {
          }
        }
        
        yield bookings;
        await Future.delayed(const Duration(seconds: 30)); // Refresh every 30 seconds
      } catch (e) {
        yield <DateTime, List<Map<String, dynamic>>>{};
        await Future.delayed(const Duration(seconds: 10)); // Wait longer on error
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1B1B1B),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFE53935),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Studio Availability Calendar',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: _refreshBookings,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'Refresh bookings',
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // Calendar with Real-time Updates
            Expanded(
              child: StreamBuilder<Map<DateTime, List<Map<String, dynamic>>>>(
                stream: _getBookingsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }
                  
                  final bookings = snapshot.data ?? {};
                  
                  // Debug: Log current focused day and available bookings
                  
                  return TableCalendar<Map<String, dynamic>>(
                    firstDay: DateTime.now().subtract(const Duration(days: 30)),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      
                      // Show available times popup for the selected date
                      _showAvailableTimesPopup(selectedDay);
                    },
                    eventLoader: (day) {
                      final dayKey = DateTime(day.year, day.month, day.day);
                      final events = bookings[dayKey] ?? [];
                      return events;
                    },
                    calendarStyle: const CalendarStyle(
                      outsideDaysVisible: false,
                      weekendTextStyle: TextStyle(color: Colors.white70),
                      defaultTextStyle: TextStyle(color: Colors.white),
                      todayTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      selectedTextStyle: TextStyle(color: Colors.white),
                      selectedDecoration: BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle),
                      todayDecoration: BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle),
                      markersMaxCount: 3,
                      markerDecoration: BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle),
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(color: Colors.white, fontSize: 16),
                      leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white70),
                      rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white70),
                    ),
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle: TextStyle(color: Colors.white70),
                      weekendStyle: TextStyle(color: Colors.white70),
                    ),
                  );
                },
              ),
            ),
            
            // Selected Day Bookings with Real-time Updates
            if (_selectedDay != null) ...[
              StreamBuilder<Map<DateTime, List<Map<String, dynamic>>>>(
                stream: _getBookingsStream(),
                builder: (context, snapshot) {
                  final bookings = snapshot.data ?? {};
                  final dayBookings = bookings[_selectedDay!] ?? [];
                  
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF262626),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bookings for ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (dayBookings.isEmpty)
                          const Text(
                            'No bookings for this day',
                            style: TextStyle(color: Colors.white70),
                          )
                        else
                          ...dayBookings.map((booking) => Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B1B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: booking['status'] == 'confirmed' 
                                    ? Colors.green 
                                    : booking['status'] == 'in_progress'
                                        ? Colors.blue
                                        : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${booking['time']} - ${booking['name']} (${booking['duration']}h)',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      )),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
