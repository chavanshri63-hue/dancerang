// lib/models/class_item.dart
class ClassItem {
  final String id;
  final String title;
  final String style;      // e.g. "Hip Hop"
  final String days;       // e.g. "Mon · Wed · Fri"
  final String timeLabel;  // e.g. "6–7 PM"
  final String teacher;    // e.g. "Aman"
  final int feeInr;        // e.g. 1100
  final List<String> roster; // members

  const ClassItem({
    required this.id,
    required this.title,
    required this.style,
    required this.days,
    required this.timeLabel,
    required this.teacher,
    required this.feeInr,
    required this.roster,
  });

  ClassItem copyWith({
    String? id,
    String? title,
    String? style,
    String? days,
    String? timeLabel,
    String? teacher,
    int? feeInr,
    List<String>? roster,
  }) {
    return ClassItem(
      id: id ?? this.id,
      title: title ?? this.title,
      style: style ?? this.style,
      days: days ?? this.days,
      timeLabel: timeLabel ?? this.timeLabel,
      teacher: teacher ?? this.teacher,
      feeInr: feeInr ?? this.feeInr,
      roster: roster ?? this.roster,
    );
  }
}