// lib/app_state.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/app_settings.dart';
import 'models/class_item.dart';
import 'models/video_item.dart';
import 'models/booking.dart';

/// App-wide role
enum UserRole { student, faculty, admin }

class AppState {
  // ========= Theme =========
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);

  // ========= User / Role =========
  static final ValueNotifier<UserRole> currentRole =
      ValueNotifier<UserRole>(UserRole.student);

  static void setRole(UserRole r) => currentRole.value = r;

  // Optional display name for greeting
  static final ValueNotifier<String> memberName =
      ValueNotifier<String>('Shree');

  // ========= Classes (demo store) =========
  static final ValueNotifier<List<ClassItem>> classes =
      ValueNotifier<List<ClassItem>>(<ClassItem>[]);

  static void addClass(ClassItem c) => classes.value = [...classes.value, c];

  static void removeClassAt(int i) {
    final copy = [...classes.value];
    if (i >= 0 && i < copy.length) copy.removeAt(i);
    classes.value = copy;
  }

  // ========= Settings (admin editable) =========
  static final settings = ValueNotifier<AppSettings>(AppSettings());

  static String? get defaultUpiId => settings.value.upi;

  // ========= Studio bookings (optional local list) =========
  static final ValueNotifier<List<Booking>> bookings =
      ValueNotifier<List<Booking>>(<Booking>[]);

  static void addBooking(Booking b) => bookings.value = [...bookings.value, b];

  // ========= Online videos per style =========
  static final Map<String, ValueNotifier<List<VideoItem>>> _videos = {};

  static ValueNotifier<List<VideoItem>> videosForStyle(String style) {
    return _videos.putIfAbsent(style, () => ValueNotifier<List<VideoItem>>(<VideoItem>[]));
  }

  static void addVideo(String style, VideoItem v) {
    final list = videosForStyle(style);
    list.value = [...list.value, v];
  }

  // ========= Persistence (settings only) =========
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('settings');
    if (raw != null) {
      try {
        settings.value =
            AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // ignore corrupted state
      }
    }
  }

  static Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings', jsonEncode(settings.value.toJson()));
  }
}