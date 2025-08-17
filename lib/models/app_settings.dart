// lib/models/app_settings.dart
import 'dart:convert';

class AppSettings {
  String? adminPhone;
  String? whatsapp;
  String? email;
  String? address;
  String? hours;
  String? upi;

  /// Dashboard hero background (local file path via image_picker)
  String? dashboardBgPath;

  /// Admin-managed content cards on dashboard
  List<BannerItem> bannerItems;

  AppSettings({
    this.adminPhone,
    this.whatsapp,
    this.email,
    this.address,
    this.hours,
    this.upi,
    this.dashboardBgPath,
    List<BannerItem>? bannerItems,
  }) : bannerItems = bannerItems ?? <BannerItem>[];

  AppSettings copy() => AppSettings(
        adminPhone: adminPhone,
        whatsapp: whatsapp,
        email: email,
        address: address,
        hours: hours,
        upi: upi,
        dashboardBgPath: dashboardBgPath,
        bannerItems: bannerItems.map((e) => e.copy()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'adminPhone': adminPhone,
        'whatsapp': whatsapp,
        'email': email,
        'address': address,
        'hours': hours,
        'upi': upi,
        'dashboardBgPath': dashboardBgPath,
        'banners': bannerItems.map((e) => e.toJson()).toList(),
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final list = (j['banners'] as List?) ?? const [];
    return AppSettings(
      adminPhone: j['adminPhone'] as String?,
      whatsapp: j['whatsapp'] as String?,
      email: j['email'] as String?,
      address: j['address'] as String?,
      hours: j['hours'] as String?,
      upi: j['upi'] as String?,
      dashboardBgPath: j['dashboardBgPath'] as String?,
      bannerItems: list
          .map((e) => BannerItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  static AppSettings fromJsonString(String s) =>
      AppSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);

  String toJsonString() => jsonEncode(toJson());
}

class BannerItem {
  String? title;
  String? path; // local file path

  BannerItem({this.title, this.path});

  BannerItem copy() => BannerItem(title: title, path: path);

  Map<String, dynamic> toJson() => {'title': title, 'path': path};

  factory BannerItem.fromJson(Map<String, dynamic> j) =>
      BannerItem(title: j['title'] as String?, path: j['path'] as String?);
}