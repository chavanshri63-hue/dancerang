class AppConfig {
  // Role Keys - Load from environment variables for security
  // IMPORTANT: For production, set ADMIN_KEY and FACULTY_KEY environment variables
  // or update these default values to secure keys before building release
  // FIXED KEYS - Production keys set
  static const String _fixedAdminKey = 'ANUSHREE0918';
  static const String _fixedFacultyKey = 'DANCERANG5678';
  
  static String get adminKey => const String.fromEnvironment(
    'ADMIN_KEY',
    defaultValue: _fixedAdminKey,
  );
  
  static String get facultyKey => const String.fromEnvironment(
    'FACULTY_KEY', 
    defaultValue: _fixedFacultyKey,
  );
  
  // Default Background Images
  static const String defaultLoginBackground = 'https://images.unsplash.com/photo-1508700929628-666bc8bd84ea?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80';
  static const String defaultHomeBackground = 'https://images.unsplash.com/photo-1508700929628-666bc8bd84ea?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80';
  static const String defaultOTPBackground = 'https://images.unsplash.com/photo-1508700929628-666bc8bd84ea?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80';
  
  // App Settings
  static const String appName = 'DanceRang';
  static const String appTagline = 'Step into Excellence';
  static const String appVersion = '1.0.0';
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String classesCollection = 'classes';
  static const String galleryCollection = 'gallery';
  static const String appSettingsCollection = 'appSettings';
  static const String bannersCollection = 'banners';
  
  // Default Values
  static const int defaultMaxStudents = 20;
  static const int defaultResendCountdown = 60;
  static const int defaultOTPLength = 6;
  
  // Demo Mode (removed - not used in production)
  
  // Notification Settings
  static const String defaultNotificationChannel = 'dancerang_default_channel';
  static const String defaultNotificationChannelName = 'DanceRang Notifications';
  static const String defaultNotificationChannelDescription = 'General notifications for DanceRang';
  
  // UI Settings
  static const double defaultBorderRadius = 12.0;
  static const double defaultCardElevation = 8.0;
  static const double defaultAnimationDuration = 1000.0; // milliseconds
  
  // Validation
  static const int minPhoneNumberLength = 10;
  static const int maxPhoneNumberLength = 10;
  static const int minNameLength = 2;
  static const int maxNameLength = 50;
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // Cache Settings
  static const int defaultCacheExpiry = 300; // 5 minutes in seconds
  static const int imageCacheExpiry = 3600; // 1 hour in seconds
  
  // Default Values for Services
  static const String defaultLevel = 'Beginner';
  static const String defaultPrice = '₹500';
  static const String defaultInstructor = 'Unknown';
  static const String defaultCategory = 'General';
  
  // Security validation
  static bool isValidAdminKey(String key) {
    return key.isNotEmpty && key.length >= 8 && key != 'DRADMIN2025';
  }
  
  static bool isValidFacultyKey(String key) {
    return key.isNotEmpty && key.length >= 8 && key != 'DRFAC2025';
  }
  
  // Get secure role key with validation
  static String getSecureAdminKey() {
    final key = adminKey;
    if (!isValidAdminKey(key)) {
      throw Exception('Invalid admin key configuration');
    }
    return key;
  }
  
  static String getSecureFacultyKey() {
    final key = facultyKey;
    if (!isValidFacultyKey(key)) {
      throw Exception('Invalid faculty key configuration');
    }
    return key;
  }
}
