class ClassItem {
  final String id;
  final String title;
  final String days;      // e.g. "Mon/Wed/Fri"
  final String timeLabel; // e.g. "7–8 PM"
  final String? details;

  ClassItem({
    required this.id,
    required this.title,
    required this.days,
    required this.timeLabel,
    this.details,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'days': days,
        'timeLabel': timeLabel,
        'details': details,
      };

  factory ClassItem.fromJson(Map<String, dynamic> j) => ClassItem(
        id: j['id'] as String,
        title: j['title'] as String,
        days: j['days'] as String,
        timeLabel: j['timeLabel'] as String,
        details: j['details'] as String?,
      );
}