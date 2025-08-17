class Workshop {
  final String id;
  String title;
  String dateLabel;
  int priceInr;
  String? hostName;
  String? hostImageUrl; // network/local path

  Workshop({
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.priceInr,
    this.hostName,
    this.hostImageUrl,
  });

  Workshop copyWith({
    String? title,
    String? dateLabel,
    int? priceInr,
    String? hostName,
    String? hostImageUrl,
  }) {
    return Workshop(
      id: id,
      title: title ?? this.title,
      dateLabel: dateLabel ?? this.dateLabel,
      priceInr: priceInr ?? this.priceInr,
      hostName: hostName ?? this.hostName,
      hostImageUrl: hostImageUrl ?? this.hostImageUrl,
    );
  }
}