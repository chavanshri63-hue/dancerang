class Booking {
  final DateTime startTime;
  final DateTime endTime;
  final bool isWeekend;
  final int hours;
  final int totalAmount;

  const Booking({
    required this.startTime,
    required this.endTime,
    required this.isWeekend,
    required this.hours,
    required this.totalAmount,
  });

  /// Pricing rules:
  /// Weekday: ₹1000/hr (if >3h => ₹800/hr)
  /// Weekend: ₹1200/hr (if >3h => ₹1000/hr)
  static Booking from(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final h = duration.inMinutes <= 0 ? 1 : ((duration.inMinutes + 59) ~/ 60);
    final weekend = start.weekday == DateTime.saturday || start.weekday == DateTime.sunday;
    final rate = weekend ? (h > 3 ? 1000 : 1200) : (h > 3 ? 800 : 1000);
    return Booking(
      startTime: start,
      endTime: end,
      isWeekend: weekend,
      hours: h,
      totalAmount: rate * h,
    );
  }

  String get pretty {
    String two(int n) => n.toString().padLeft(2, '0');
    String d(DateTime x) => "${two(x.day)}/${two(x.month)} ${two(x.hour)}:${two(x.minute)}";
    return "${d(startTime)} • ${hours}h • ₹$totalAmount";
  }
}