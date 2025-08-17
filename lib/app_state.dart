// lib/app_state.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Models (present in your repo)
import 'models/class_item.dart';
import 'models/booking.dart';
import 'models/video_item.dart';
import 'models/banner_item.dart';
import 'models/app_settings.dart';

/// ---- Roles ---------------------------------------------------------------
enum UserRole { student, faculty, admin }

String roleLabel(UserRole r) {
  switch (r) {
    case UserRole.student:
      return 'Student';
    case UserRole.faculty:
      return 'Faculty';
    case UserRole.admin:
      return 'Admin';
  }
}

/// ---- AppState : single source of truth -----------------------------------
class AppState {
  // THEME
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  // USER / ROLE
  static final ValueNotifier<UserRole> _role =
      ValueNotifier<UserRole>(UserRole.student);

  /// listenable (for ValueListenableBuilder)
  static ValueNotifier<UserRole> get roleListenable => _role;

  /// direct value (for simple checks)
  static UserRole get currentRole => _role.value;

  static void setRole(UserRole r) => _role.value = r;

  // Optional display name (used in dashboard welcome)
  static final ValueNotifier<String> memberName =
      ValueNotifier<String>('Shree');

  // CLASSES
  static final ValueNotifier<List<ClassItem>> classes =
      ValueNotifier<List<ClassItem>>(<ClassItem>[]);

  static void addClass(ClassItem c) =>
      classes.value = <ClassItem>[...classes.value, c];

  static void removeClassAt(int index) {
    final list = <ClassItem>[...classes.value];
    if (index >= 0 && index < list.length) list.removeAt(index);
    classes.value = list;
  }

  // DASHBOARD CONTENT (videos / updates etc.) – minimal APIs you call from screens
  static final ValueNotifier<List<VideoItem>> videos =
      ValueNotifier<List<VideoItem>>(<VideoItem>[]);

  static void addVideo(VideoItem v) =>
      videos.value = <VideoItem>[...videos.value, v];

  // BOOKINGS (Studio / Events requests)
  static final ValueNotifier<List<Booking>> bookings =
      ValueNotifier<List<Booking>>(<Booking>[]);

  static void addBooking(Booking b) =>
      bookings.value = <Booking>[...bookings.value, b];

  // ADMIN SETTINGS (contact, UPI, hero bg, banners…)
  static final ValueNotifier<AppSettings> settings =
      ValueNotifier<AppSettings>(AppSettings());

  /// Convenience getters used in screens
  static String? get adminPhone => settings.value.adminPhone;
  static String? get defaultUpiId => settings.value.upi;

  // ---------------- Persistence ----------------
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Settings
    final rawSettings = prefs.getString('settings');
    if (rawSettings != null) {
      try {
        settings.value =
            AppSettings.fromJson(jsonDecode(rawSettings) as Map<String, dynamic>);
      } catch (_) {/* ignore corrupted */}
    }

    // Classes (optional – only if you ever saved them)
    final rawClasses = prefs.getString('classes');
    if (rawClasses != null) {
      try {
        final list = (jsonDecode(rawClasses) as List)
            .map((e) => ClassItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        classes.value = list;
      } catch (_) {}
    }

    // Role (optional)
    final rawRole = prefs.getString('role');
    if (rawRole != null) {
      final r = UserRole.values.firstWhere(
        (e) => e.name == rawRole,
        orElse: () => UserRole.student,
      );
      _role.value = r;
    }
  }

  static Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings', jsonEncode(settings.value.toJson()));
  }

  static Future<void> saveRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', _role.value.name);
  }

  static Future<void> saveClasses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'classes',
      jsonEncode(classes.value.map((e) => e.toJson()).toList()),
    );
  }
}