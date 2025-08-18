// lib/app_state.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Models already in your repo
import 'models/booking.dart';
import 'models/class_item.dart';
import 'models/member.dart';
import 'models/update_item.dart';
import 'models/video_item.dart';
import 'models/workshop_item.dart';

/// App wide roles
enum UserRole { none, student, faculty, admin }

class AppState {
  // ---------------- THEME ----------------
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.dark);
  static void toggleTheme() => themeMode.value =
      themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;

  // ---------------- IDENTITY / ROLE ----------------
  static final ValueNotifier<String> memberName =
      ValueNotifier<String>('Shree');
  static final ValueNotifier<UserRole> currentRole =
      ValueNotifier<UserRole>(UserRole.none);
  static void loginAs(UserRole role) => currentRole.value = role;
  static void logout() => currentRole.value = UserRole.none;

  // ---------------- NOTIFICATIONS (local feed) ----------------
  static final ValueNotifier<List<String>> notifications =
      ValueNotifier<List<String>>(<String>[]);
  static void pushNotification(String message) {
    notifications.value = [message, ...notifications.value];
  }

  // ---------------- SETTINGS (persisted) ----------------
  static final ValueNotifier<AppSettings> settings =
      ValueNotifier<AppSettings>(AppSettings.defaults());

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('settings');
    if (raw != null) {
      try {
        settings.value = AppSettings.fromJson(jsonDecode(raw));
      } catch (_) {
        // ignore bad/corrupt state, keep defaults
      }
    }
  }

  static Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings', jsonEncode(settings.value.toJson()));
  }

  /// UPI convenience (fallback to demo UPI if not set)
  static String get defaultUpiId =>
      (settings.value.upi?.trim().isNotEmpty == true)
          ? settings.value.upi!.trim()
          : 'your-upi-id@upi';

  // ---------------- MEMBERS (for Admin dashboard etc.) ----------------
  static final ValueNotifier<List<Member>> members =
      ValueNotifier<List<Member>>(<Member>[
    const Member(id: 'm1', name: 'Shree', phone: '9000000001', active: true),
    const Member(id: 'm2', name: 'Karan', phone: '9000000002', active: true),
    const Member(id: 'm3', name: 'Riya',  phone: '9000000003', active: false),
    const Member(id: 'm4', name: 'Aman',  phone: '9000000004', active: true),
  ]);

  static List<Member> get activeMembers =>
      members.value.where((m) => m.active).toList();
  static List<Member> get inactiveMembers =>
      members.value.where((m) => !m.active).toList();

  // ---------------- UPDATES (CRUD) ----------------
  static final ValueNotifier<List<UpdateItem>> updates =
      ValueNotifier<List<UpdateItem>>(<UpdateItem>[]);
  static void addUpdate(UpdateItem u) {
    updates.value = [u, ...updates.value];
    pushNotification('New update: ${u.title}');
  }
  static void editUpdateAt(int index, UpdateItem updated) {
    final list = [...updates.value];
    if (index >= 0 && index < list.length) {
      list[index] = updated;
      updates.value = list;
      pushNotification('Update edited: ${updated.title}');
    }
  }
  static void removeUpdateAt(int index) {
    final list = [...updates.value];
    if (index >= 0 && index < list.length) {
      final removed = list.removeAt(index);
      updates.value = list;
      pushNotification('Update deleted: ${removed.title}');
    }
  }

  // ---------------- ATTENDANCE ----------------
  static final ValueNotifier<List<DateTime>> attendanceDates =
      ValueNotifier<List<DateTime>>(<DateTime>[]);
  static void markAttendance(DateTime when) {
    attendanceDates.value = [when, ...attendanceDates.value];
    pushNotification('Attendance marked for ${_d(when)}');
  }
  static int attendedThisMonth() {
    final now = DateTime.now();
    return attendanceDates.value
        .where((d) => d.year == now.year && d.month == now.month)
        .length;
  }
  static DateTime? lastClassDate() => attendanceDates.value.isEmpty
      ? null
      : attendanceDates.value.reduce((a, b) => a.isAfter(b) ? a : b);
  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  // ---------------- PAYMENTS / DUES ----------------
  static final ValueNotifier<int> pendingDue = ValueNotifier<int>(0);
  static final ValueNotifier<String?> subscriptionPlan =
      ValueNotifier<String?>('Monthly');

  // ---------------- STUDIO BOOKINGS ----------------
  static final ValueNotifier<List<Booking>> studioBookings =
      ValueNotifier<List<Booking>>(<Booking>[]);
  static void addBooking(Booking b) {
    studioBookings.value = [...studioBookings.value, b];
    pushNotification('Studio booked: ${b.pretty}');
  }
  static int upcomingBookingsCount() {
    final now = DateTime.now();
    return studioBookings.value.where((b) => b.startTime.isAfter(now)).length;
  }

  // ---------------- ONLINE VIDEOS (bookmarkable) ----------------
  static final ValueNotifier<Map<String, Map<String, List<VideoItem>>>> videos =
      ValueNotifier<Map<String, Map<String, List<VideoItem>>>>({});
  static void addVideo({
    required String style,
    required String category, // 'Foundation' | 'Choreography'
    required VideoItem item,
  }) {
    final map = {...videos.value};
    final byStyle = {...(map[style] ?? {})};
    final list = [...(byStyle[category] ?? <VideoItem>[])];
    list.insert(0, item);
    byStyle[category] = list;
    map[style] = byStyle;
    videos.value = map;
    pushNotification('New video in $style • $category: ${item.title}');
  }
  static final ValueNotifier<Set<String>> bookmarks =
      ValueNotifier<Set<String>>(<String>{});
  static String videoKey(String style, String category, String title) =>
      '$style::$category::$title';
  static bool isBookmarked(String key) => bookmarks.value.contains(key);
  static void toggleBookmark(String key) {
    final set = {...bookmarks.value};
    set.contains(key) ? set.remove(key) : set.add(key);
    bookmarks.value = set;
  }

  // ---------------- BANNERS (from persisted settings) ----------------
  /// For convenience if you still need a string banners list anywhere,
  /// derive from settings.bannerItems titles.
  static List<String> get legacyBannerTitles =>
      settings.value.bannerItems.map((e) => e.title ?? '').where((t)=>t.isNotEmpty).toList();

  // ===================================================================
  //                           CLASSES
  // ===================================================================
  static final ValueNotifier<List<ClassItem>> classes =
      ValueNotifier<List<ClassItem>>(<ClassItem>[
    ClassItem(
      id: 'c1',
      title: 'Hip Hop Juniors',
      style: 'Hip Hop',
      days: 'Mon · Wed · Fri',
      timeLabel: '6–7 PM',
      teacher: 'Aman',
      feeInr: 1100,
      roster: const ['Shree', 'Karan'],
    ),
    ClassItem(
      id: 'c2',
      title: 'Bharatanatyam Beginners',
      style: 'Classical',
      days: 'Tue · Thu',
      timeLabel: '5–6 PM',
      teacher: 'Riya',
      feeInr: 900,
      roster: const [],
    ),
    ClassItem(
      id: 'c3',
      title: 'Contemporary Teens',
      style: 'Contemporary',
      days: 'Sat · Sun',
      timeLabel: '11–12 AM',
      teacher: 'Riya',
      feeInr: 1100,
      roster: const ['Shree'],
    ),
  ]);

  static void addClass(ClassItem item) {
    classes.value = [...classes.value, item];
    pushNotification('New class added: ${item.title}');
  }

  static void updateClass(int index, ClassItem item) {
    final list = [...classes.value];
    if (index >= 0 && index < list.length) {
      list[index] = item;
      classes.value = list;
      pushNotification('Class updated: ${item.title}');
    }
  }
  static void updateClassAt(int index, ClassItem item) => updateClass(index, item);

  static void removeClassAt(int index) {
    final list = [...classes.value];
    if (index >= 0 && index < list.length) {
      final removed = list.removeAt(index);
      classes.value = list;
      pushNotification('Class removed: ${removed.title}');
    }
  }

  static void addMemberToClass(String classId, String name) {
    final list = [...classes.value];
    final i = list.indexWhere((c) => c.id == classId);
    if (i == -1) return;
    final c = list[i];
    final r = {...c.roster};
    r.add(name);
    list[i] = c.copyWith(roster: r.toList());
    classes.value = list;
    pushNotification('Joined ${c.title}: $name');
  }

  static void removeMemberFromClass(String classId, String name) {
    final list = [...classes.value];
    final i = list.indexWhere((c) => c.id == classId);
    if (i == -1) return;
    final c = list[i];
    final r = {...c.roster}..remove(name);
    list[i] = c.copyWith(roster: r.toList());
    classes.value = list;
    pushNotification('Removed from ${c.title}: $name');
  }

  // ===================================================================
  //                          WORKSHOPS
  // ===================================================================
  static final ValueNotifier<List<WorkshopItem>> workshops =
      ValueNotifier<List<WorkshopItem>>(<WorkshopItem>[
    WorkshopItem(
      id: 'w1',
      title: 'Bollywood Beginners',
      date: '24 Aug · 5–7 PM',
      price: 799,
      hostName: 'Ananya',
      hostImage: '',
      registered: const [],
    ),
    WorkshopItem(
      id: 'w2',
      title: 'Corporate Choreo Sprint',
      date: '5 Sept · 6–8 PM',
      price: 999,
      hostName: 'Sameer',
      hostImage: '',
      registered: const [],
    ),
    WorkshopItem(
      id: 'w3',
      title: 'HipHop Foundations',
      date: '12 Sept · 4–6 PM',
      price: 899,
      hostName: 'Rohan',
      hostImage: '',
      registered: const [],
    ),
  ]);

  static void addWorkshop(WorkshopItem w) {
    workshops.value = [...workshops.value, w];
    pushNotification('New workshop: ${w.title}');
  }

  static void updateWorkshop(int index, WorkshopItem w) {
    final list = [...workshops.value];
    if (index >= 0 && index < list.length) {
      list[index] = w;
      workshops.value = list;
      pushNotification('Workshop updated: ${w.title}');
    }
  }

  static void deleteWorkshop(String id) {
    final list = [...workshops.value]..removeWhere((e) => e.id == id);
    workshops.value = list;
    pushNotification('Workshop deleted');
  }

  static void toggleRegisterForWorkshop(String id, String member) {
    final list = [...workshops.value];
    final i = list.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final w = list[i];
    final set = {...w.registered};
    set.contains(member) ? set.remove(member) : set.add(member);
    list[i] = w.copyWith(registered: set.toList());
    workshops.value = list;
  }
}

// ================== SETTINGS & CONTENT MODELS ==================

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

  /// Event-Choreography configurable pricing/content
  EventChoreoSettings eventChoreo;

  AppSettings({
    this.adminPhone,
    this.whatsapp,
    this.email,
    this.address,
    this.hours,
    this.upi,
    this.dashboardBgPath,
    List<BannerItem>? bannerItems,
    EventChoreoSettings? eventChoreo,
  })  : bannerItems = bannerItems ?? <BannerItem>[],
        eventChoreo = eventChoreo ?? EventChoreoSettings.defaults();

  factory AppSettings.defaults() => AppSettings(
        adminPhone: '',
        whatsapp: '',
        email: '',
        address: '',
        hours: '',
        upi: '',
        dashboardBgPath: null,
        bannerItems: <BannerItem>[
          BannerItem(title: 'Mega Workshop this weekend!', path: null),
          BannerItem(title: 'Refer a friend and get 10% off', path: null),
        ],
        eventChoreo: EventChoreoSettings.defaults(),
      );

  AppSettings copy() => AppSettings(
        adminPhone: adminPhone,
        whatsapp: whatsapp,
        email: email,
        address: address,
        hours: hours,
        upi: upi,
        dashboardBgPath: dashboardBgPath,
        bannerItems: bannerItems.map((e) => e.copy()).toList(),
        eventChoreo: eventChoreo.copy(),
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
        'eventChoreo': eventChoreo.toJson(),
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
      eventChoreo: (j['eventChoreo'] != null)
          ? EventChoreoSettings.fromJson(
              Map<String, dynamic>.from(j['eventChoreo']))
          : EventChoreoSettings.defaults(),
    );
  }
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

class EventChoreoSettings {
  int schoolBase;
  int schoolBulk;
  int sangeetBase;
  int sangeetBulk;
  int corporateBase;
  int corporateBulk;
  String included; // text blob

  EventChoreoSettings({
    required this.schoolBase,
    required this.schoolBulk,
    required this.sangeetBase,
    required this.sangeetBulk,
    required this.corporateBase,
    required this.corporateBulk,
    required this.included,
  });

  factory EventChoreoSettings.defaults() => EventChoreoSettings(
        schoolBase: 4500,
        schoolBulk: 3500,
        sangeetBase: 7500,
        sangeetBulk: 5500,
        corporateBase: 7500,
        corporateBulk: 5500,
        included:
            'Music choreography/editing • Dedicated private sessions • Event-day faculty/admin availability',
      );

  EventChoreoSettings copy() => EventChoreoSettings(
        schoolBase: schoolBase,
        schoolBulk: schoolBulk,
        sangeetBase: sangeetBase,
        sangeetBulk: sangeetBulk,
        corporateBase: corporateBase,
        corporateBulk: corporateBulk,
        included: included,
      );

  Map<String, dynamic> toJson() => {
        'schoolBase': schoolBase,
        'schoolBulk': schoolBulk,
        'sangeetBase': sangeetBase,
        'sangeetBulk': sangeetBulk,
        'corporateBase': corporateBase,
        'corporateBulk': corporateBulk,
        'included': included,
      };

  factory EventChoreoSettings.fromJson(Map<String, dynamic> j) =>
      EventChoreoSettings(
        schoolBase: (j['schoolBase'] ?? 4500) as int,
        schoolBulk: (j['schoolBulk'] ?? 3500) as int,
        sangeetBase: (j['sangeetBase'] ?? 7500) as int,
        sangeetBulk: (j['sangeetBulk'] ?? 5500) as int,
        corporateBase: (j['corporateBase'] ?? 7500) as int,
        corporateBulk: (j['corporateBulk'] ?? 5500) as int,
        included: (j['included'] ?? '') as String,
      );
}