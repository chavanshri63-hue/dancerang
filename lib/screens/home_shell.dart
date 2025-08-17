import 'package:flutter/material.dart';
import '../theme.dart';

// Tabs
import 'dashboard_screen.dart';
import 'classes_screen.dart';
import 'studio_booking_screen.dart';
import 'online_screen.dart';
import 'profile_screen.dart';

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
      // NOTE: No AppBar here
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