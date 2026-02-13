import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/phone_auth_screen.dart';
import 'screens/simple_auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/payment_service.dart';
import 'services/live_notification_service.dart';
import 'services/payment_validity_service.dart';
import 'services/attendance_alert_service.dart';
import 'services/background_renewal_service.dart';
import 'services/dance_styles_service.dart';
import 'services/class_enrollment_expiry_service.dart';
import 'services/birthday_service.dart';
import 'services/fcm_service.dart';
import 'config/app_config.dart';
import 'providers/auth_provider.dart';


// Initialize non-critical services in background for better performance
Future<void> _initializeBackgroundServices() async {
  // Run in background without blocking app startup
  Future.microtask(() async {
  try {
    // Initialize live notification service
    await LiveNotificationService.initialize();
    LiveNotificationService.startSpotMonitoring();
  } catch (e) {
    if (kDebugMode) {
      print('❌ Error initializing live notifications: $e');
    }
  }

    // Determine role once and gate admin/faculty-only background jobs
    String? userRole;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        userRole = ((userDoc.data() ?? const {})['role'] as String?)?.toLowerCase();
      } catch (e) {
        if (kDebugMode) {
          print('Error loading user role for background services: $e');
        }
      }
    }

    try {
      // Initialize payment validity monitoring (admin/faculty only)
      if (userRole == 'admin' || userRole == 'faculty') {
        PaymentValidityService.checkAllUsersValidity();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in payment validity monitoring: $e');
      }
    }

    try {
      // Initialize attendance alert monitoring (admin/faculty only)
      if (userRole == 'admin' || userRole == 'faculty') {
        AttendanceAlertService.checkAllStudentsAttendance();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in attendance alert monitoring: $e');
      }
    }

    try {
      // Expire class enrollments that have passed endDate (admin only)
      if (userRole == 'admin') {
      await ClassEnrollmentExpiryService.expireAllIfNeeded();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in class enrollments expiry check: $e');
      }
    }

    try {
      // Start background subscription renewal service only for admin users
      if (userRole == 'admin') {
        BackgroundRenewalService.start();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in background renewal service: $e');
      }
    }

    // Initialize default styles for classes and online (admin only)
    try {
      if (userRole == 'admin') {
        await ClassStylesService.initializeDefaultStyles();
        await OnlineStylesService.initializeDefaultStyles();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing style lists: $e');
      }
    }

    // Check and send birthday wishes (for all users)
    try {
      await BirthdayService.checkAndSendBirthdayWishes();
    } catch (e) {
      if (kDebugMode) {
        print('Error checking birthday wishes: $e');
      }
    }
  });
}

Future<void> _initializeFirebaseAndServices() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  
  try {
    if (!kIsWeb) {
      await FCMService.initialize();
    }
  } catch (e) {
    if (kDebugMode) {
      print('FCM service initialization error: $e');
    }
  }

  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user != null) {
      if (!kIsWeb) {
        FCMService.initialize().catchError((e) {
          if (kDebugMode) {
            print('Error re-initializing FCM after login: $e');
          }
        });
      }
      
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final userData = userDoc.data();
        final userName = userData?['name'] as String? ?? 'User';
        
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final welcomeCheck = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .where('type', isEqualTo: 'welcome')
            .where('createdAt', isGreaterThan: Timestamp.fromDate(todayStart))
            .limit(1)
            .get();
        
        if (welcomeCheck.docs.isEmpty) {
          await LiveNotificationService.sendWelcomeNotification(
            userName: userName,
            userId: user.uid,
          );
        }
      } catch (e) {
      }
    }
  });
  
  try {
    // Initialize payment service
    PaymentService.initialize();
  } catch (e) {
    if (kDebugMode) {
      print('Payment service initialization error: $e');
    }
  }

  // Do not write role keys at startup; configure via admin tools or console.
  
  // Initialize non-critical services in background (lazy loading)
  _initializeBackgroundServices();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Cleanup method for services (called when app is disposed)
  static void cleanup() {
    try {
      // Stop live notification monitoring
      LiveNotificationService.stopSpotMonitoring();
      
      // Stop background renewal service
      BackgroundRenewalService.stop();
    } catch (e) {
      // Service cleanup error
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: PaymentService.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'DanceRang',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE53935),
          secondary: Color(0xFF4F46E5),
          surface: Color(0xFF1B1B1B),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFFFAFAFA),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        cardColor: const Color(0xFF1B1B1B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFE53935),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFFAFAFA)),
          bodyMedium: TextStyle(color: Color(0xFFFAFAFA)),
          bodySmall: TextStyle(color: Color(0xFFA3A3A3)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1B1B1B),
          hintStyle: const TextStyle(color: Color(0xFFA3A3A3)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF262626)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF262626)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF4F46E5),
            side: const BorderSide(color: Color(0xFF4F46E5), width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4F46E5),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF262626),
          thickness: 1,
          space: 24,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1B1B1B),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF262626)),
          ),
        ),
      ),
      home: const FirebaseInitScreen(),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/phone-auth': (context) => const PhoneAuthScreen(),
        '/simple-auth': (context) => const SimpleAuthScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

class FirebaseInitScreen extends StatefulWidget {
  const FirebaseInitScreen({super.key});

  @override
  State<FirebaseInitScreen> createState() => _FirebaseInitScreenState();
}

class _FirebaseInitScreenState extends State<FirebaseInitScreen> {
  late Future<void> _initFuture;  @override
  void initState() {
    super.initState();
    _initFuture = _initializeFirebaseAndServices();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF000000),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFE53935)),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFF000000),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Startup failed. Tap to retry.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _initFuture = _initializeFirebaseAndServices();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final user = FirebaseAuth.instance.currentUser;
        return user == null ? const LoginScreen() : const HomeScreen();
      },
    );
  }
}
