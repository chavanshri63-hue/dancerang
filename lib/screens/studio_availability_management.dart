import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:async';
import '../services/payment_service.dart';

class StudioAvailabilityManagementDialog extends StatefulWidget {
  @override
  _StudioAvailabilityManagementDialogState createState() => _StudioAvailabilityManagementDialogState();
}

class _StudioAvailabilityManagementDialogState extends State<StudioAvailabilityManagementDialog> {
  DateTime _selectedDate = DateTime.now();
  // Per-date overrides (key: yyyy-mm-dd)
  Map<String, Map<String, List<String>>> _overrides = {};
  // Weekly rule: block 17:00-21:00 every day by default
  List<Map<String, String>> _weeklyBlockedRanges = [
    {'start': '17:00', 'end': '21:00'},
  ];
  // Legacy flat lists kept for backwards compatibility (unused in new UI rendering)
  List<String> _availableTimes = [];
  List<String> _blockedTimes = [];
  bool _isLoading = false;
  StreamSubscription<Map<String, dynamic>>? _paymentRefreshSubscription;

  @override
  void initState() {
    super.initState();
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
    setState(() => _isLoading = true);
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('studioAvailability')
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _availableTimes = List<String>.from(data['availableTimes'] ?? []);
          _blockedTimes = List<String>.from(data['blockedTimes'] ?? []);
          _overrides = Map<String, Map<String, List<String>>>.from(
            (data['overrides'] ?? {}).map<String, Map<String, List<String>>>((k, v) => MapEntry(
                  k as String,
                  {
                    'availableTimes': List<String>.from((v['availableTimes'] ?? []) as List),
                    'blockedTimes': List<String>.from((v['blockedTimes'] ?? []) as List),
                  },
                )),
          );
          _weeklyBlockedRanges = List<Map<String, String>>.from(
            (data['weeklyRule']?['blockedRanges'] ?? _weeklyBlockedRanges)
                .map<Map<String, String>>((r) => {
                      'start': r['start'] as String,
                      'end': r['end'] as String,
                    }),
          );
        });
      } else {
        // Defaults already set in state (weekly 17:00-21:00 blocked)
      }
    } catch (e) {
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAvailabilitySettings() async {
    setState(() => _isLoading = true);
    
    try {
      await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('studioAvailability')
          .set({
        'availableTimes': _availableTimes,
        'blockedTimes': _blockedTimes,
        'weeklyRule': {
          'blockedRanges': _weeklyBlockedRanges,
        },
        'overrides': _overrides,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Availability settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleTimeSlot(String time) {
    final key = _formatDateKey(_selectedDate);
    _overrides.putIfAbsent(key, () => {'availableTimes': [], 'blockedTimes': []});
    final available = _overrides[key]!['availableTimes']!;
    final blocked = _overrides[key]!['blockedTimes']!;
    setState(() {
      if (available.contains(time)) {
        available.remove(time);
        blocked.add(time);
      } else if (blocked.contains(time)) {
        blocked.remove(time);
        available.add(time);
      } else {
        available.add(time);
      }
    });
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
    final override = _overrides[key];
    if (override != null) {
      if (override['blockedTimes']!.contains(time)) return false;
      if (override['availableTimes']!.contains(time)) return true;
    }
    // Default: available unless weekly rule blocks it
    return !_isBlockedByWeeklyRule(time);
  }

  void _applyPresetWeeklyBlock() {
    setState(() {
      _weeklyBlockedRanges = [
        {'start': '17:00', 'end': '21:00'},
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preset applied: Mon–Sun 5pm–9pm blocked')),
    );
  }

  void _clearOverridesForSelectedDate() {
    final key = _formatDateKey(_selectedDate);
    setState(() {
      _overrides.remove(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1B1B),
      title: const Text('Studio Availability Management', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Date picker for choosing a date
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Selected Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() {
                                _selectedDate = DateTime(date.year, date.month, date.day);
                              });
                            }
                          },
                          child: const Text('Change', style: TextStyle(color: Color(0xFFE53935))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: _applyPresetWeeklyBlock,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
                        child: const Text('Preset: 5pm–9pm blocked'),
                      ),
                      OutlinedButton(
                        onPressed: _clearOverridesForSelectedDate,
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
                        child: const Text('Clear this date', style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Available Time Slots (24 hours)',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Time slots grid
                  SizedBox(
                    height: 150,
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                        childAspectRatio: 1.2,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                      ),
                      itemCount: 24,
                      itemBuilder: (context, index) {
                        final hour = index;
                        final time = '${hour.toString().padLeft(2, '0')}:00';
                        final isAvailable = _isAvailableForDate(_selectedDate, time);
                        final isBlocked = !isAvailable;
                        
                        return GestureDetector(
                          onTap: () => _toggleTimeSlot(time),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isAvailable 
                                  ? const Color(0xFF10B981)
                                  : isBlocked
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF374151),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isAvailable 
                                    ? const Color(0xFF059669)
                                    : isBlocked
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF4B5563),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                time,
                                style: TextStyle(
                                  color: isAvailable || isBlocked ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Legend
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Available', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(width: 16),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Blocked', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(width: 16),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFF374151),
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Not Set', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveAvailabilitySettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
          ),
          child: _isLoading 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
