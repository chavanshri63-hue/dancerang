// lib/models/workshop_item.dart
class WorkshopItem {
  final String id;
  final String title;
  final String date;        // "24 Aug · 5–7 PM"
  final int price;          // INR
  final String hostName;    // host display name
  final String hostImage;   // optional local/remote path (for now keep "")
  final List<String> registered;

  const WorkshopItem({
    required this.id,
    required this.title,
    required this.date,
    required this.price,
    required this.hostName,
    required this.hostImage,
    required this.registered,
  });

  WorkshopItem copyWith({
    String? id,
    String? title,
    String? date,
    int? price,
    String? hostName,
    String? hostImage,
    List<String>? registered,
  }) {
    return WorkshopItem(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      price: price ?? this.price,
      hostName: hostName ?? this.hostName,
      hostImage: hostImage ?? this.hostImage,
      registered: registered ?? this.registered,
    );
  }
}