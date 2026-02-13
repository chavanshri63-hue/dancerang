class AppConfig {
  static String get adminKey => const String.fromEnvironment(
    'ADMIN_KEY',
    defaultValue: '',
  );

  static String get facultyKey => const String.fromEnvironment(
    'FACULTY_KEY',
    defaultValue: '',
  );

  static const String defaultLoginBackground = 'https://images.unsplash.com/photo-1508700929628-666bc8bd84ea?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80';
  static const String defaultHomeBackground = 'https://images.unsplash.com/photo-1508700929628-666bc8bd84ea?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80';
  static const String defaultOTPBackground = 'https://images.unsplash.com/photo-1508700929628-666bc8bd84ea?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80';

  static const String appName = 'DanceRang';
  static const String appTagline = 'Step into Excellence';
  static const String appVersion = '1.0.0';

  static const String usersCollection = 'users';
  static const String classesCollection = 'classes';
  static const String galleryCollection = 'gallery';
  static const String appSettingsCollection = 'appSettings';
  static const String bannersCollection = 'banners';

  static const int defaultMaxStudents = 20;
  static const int defaultResendCountdown = 60;
  static const int defaultOTPLength = 6;

  static const String defaultNotificationChannel = 'dancerang_default_channel';
  static const String defaultNotificationChannelName = 'DanceRang Notifications';
  static const String defaultNotificationChannelDescription = 'General notifications for DanceRang';

  static const double defaultBorderRadius = 12.0;
  static const double defaultCardElevation = 8.0;
  static const double defaultAnimationDuration = 1000.0;

  static const int minPhoneNumberLength = 10;
  static const int maxPhoneNumberLength = 10;
  static const int minNameLength = 2;
  static const int maxNameLength = 50;

  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  static const int defaultCacheExpiry = 300;
  static const int imageCacheExpiry = 3600;

  static const String defaultLevel = 'Beginner';
  static const String defaultPrice = '₹500';
  static const String defaultInstructor = 'Unknown';
  static const String defaultCategory = 'General';

  static bool isValidRoleKey(String key) {
    return key.isNotEmpty && key.length >= 8;
  }
}
