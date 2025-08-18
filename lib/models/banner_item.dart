// lib/models/banner_item.dart
class BannerItem {
  String? title;
  String? path; // local file path / asset path

  BannerItem({this.title, this.path});

  factory BannerItem.fromJson(Map<String, dynamic> j) =>
      BannerItem(title: j['title'] as String?, path: j['path'] as String?);

  Map<String, dynamic> toJson() => {'title': title, 'path': path};

  BannerItem copy() => BannerItem(title: title, path: path);
}