import 'package:flutter/material.dart';
import 'app_state.dart';
import 'theme.dart';

// Screens (no-args)
import 'screens/dashboard_screen.dart';
import 'screens/classes_screen.dart';
import 'screens/studio_booking_screen.dart';
import 'screens/online_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/attendance_qr_screen.dart';
import 'screens/attendance_scanner_screen.dart';
import 'screens/updates_screen.dart';
import 'screens/workshops_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/members_screen.dart';

// New screens
import 'screens/event_choreo_screen.dart';
import 'screens/dashboard_content_manager.dart';

// Screens (with args)
import 'screens/class_detail_screen.dart';
import 'screens/class_editor_screen.dart';
import 'screens/online_style_screen.dart';

// models
import 'models/class_item.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ensure settings (background + content cards) are loaded
  await AppState.load(); // this should exist in your AppState (SharedPreferences)
  runApp(const DanceRangApp());
}

class DanceRangApp extends StatelessWidget {
  const DanceRangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppState.themeMode,
      builder: (_, mode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'DanceRang',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,

          routes: {
            '/attendance/qr': (_) => const AttendanceQrScreen(),
            '/attendance/scan': (_) => const AttendanceScannerScreen(),
            '/updates': (_) => const UpdatesScreen(),
            '/workshops': (_) => const WorkshopsScreen(),
            '/classes': (_) => const ClassesScreen(),
            '/studio': (_) => const StudioBookingScreen(),
            '/online': (_) => const OnlineScreen(),
            '/notifications': (_) => const NotificationsScreen(),
            '/admin': (_) => const AdminDashboardScreen(),
            '/members': (_) => const MembersScreen(),

            // NEW
            '/event-choreo': (_) => const EventChoreoScreen(),
            '/dashboard/manage': (_) => const DashboardContentManagerScreen(),
          },

          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/class/detail':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const ClassDetailScreen(),
                );
              case '/class/editor':
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => const ClassEditorScreen(),
                );
              case '/online/style':
                final style = (settings.arguments ?? '') as String;
                return MaterialPageRoute(
                  settings: settings,
                  builder: (_) => OnlineStyleScreen(style: style),
                );
            }
            return null;
          },

          onUnknownRoute: (_) => MaterialPageRoute(
            builder: (_) => const Scaffold(body: Center(child: Text('Route not found'))),
          ),

          home: const HomeShell(),
        );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = const [
    DashboardScreen(),
    ClassesScreen(),
    StudioBookingScreen(),
    OnlineScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.red,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_customize_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.event_note_rounded), label: 'Classes'),
          BottomNavigationBarItem(icon: Icon(Icons.meeting_room_rounded), label: 'Studio'),
          BottomNavigationBarItem(icon: Icon(Icons.play_circle_fill_rounded), label: 'Online'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}