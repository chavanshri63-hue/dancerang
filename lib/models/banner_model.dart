class AppBanner {
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String? ctaText;
  final String? ctaLink;
  final bool isActive;
  final int sort;

  AppBanner({
    required this.title,
    required this.imageUrl,
    this.subtitle,
    this.ctaText,
    this.ctaLink,
    this.isActive = true,
    this.sort = 0,
  });

  factory AppBanner.fromMap(Map<String, dynamic> map) {
    return AppBanner(
      title: (map['title'] ?? '').toString(),
      subtitle: map['subtitle'] as String?,
      imageUrl: (map['imageUrl'] ?? '').toString(),
      ctaText: map['ctaText'] as String?,
      ctaLink: map['ctaLink'] as String?,
      isActive: (map['isActive'] ?? true) == true,
      sort: int.tryParse('${map['sort'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        'imageUrl': imageUrl,
        if (ctaText != null) 'ctaText': ctaText,
        if (ctaLink != null) 'ctaLink': ctaLink,
        'isActive': isActive,
        'sort': sort,
      };
}


