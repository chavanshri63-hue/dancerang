// lib/models/app_settings.dart
import 'banner_item.dart';

class AppSettings {
  String? adminPhone;
  String? whatsapp;
  String? email;
  String? address;
  String? hours;
  String? upi;

  String? dashboardBgPath;                 // dashboard background image
  List<BannerItem> bannerItems;            // dashboard content cards

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
    final raw = (j['banners'] as List?) ?? const [];
    return AppSettings(
      adminPhone: j['adminPhone'] as String?,
      whatsapp: j['whatsapp'] as String?,
      email: j['email'] as String?,
      address: j['address'] as String?,
      hours: j['hours'] as String?,
      upi: j['upi'] as String?,
      dashboardBgPath: j['dashboardBgPath'] as String?,
      bannerItems: raw
          .map((e) => BannerItem.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
    );
  }
}