import 'package:flutter/material.dart';
import '../app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // Common controllers
  final _name = TextEditingController(text: 'Shree');
  final _phone = TextEditingController(text: '9000000001');

  // Faculty
  final _facultyCode = TextEditingController();

  // Admin
  final _adminOtp = TextEditingController();
  final _adminUniqueCode = TextEditingController();

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _name.dispose();
    _phone.dispose();
    _facultyCode.dispose();
    _adminOtp.dispose();
    _adminUniqueCode.dispose();
    super.dispose();
  }

  Future<void> _asStudent() async {
    if (_loading) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 200));
    // Persist name (optional for demo)
    AppState.memberName.value = _name.text.trim().isEmpty ? 'Student' : _name.text.trim();
    AppState.loginAs(UserRole.student);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged in as Student')),
    );
    setState(() => _loading = false);
  }

  Future<void> _asFaculty() async {
    if (_loading) return;
    final code = _facultyCode.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter invite code')),
      );
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 200));

    if (AppState.verifyFacultyInvite(code)) {
      AppState.loginAs(UserRole.faculty);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged in (code: $code)')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid invite code')),
        );
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _asAdmin() async {
    if (_loading) return;
    final otp = _adminOtp.text.trim();
    final ucode = _adminUniqueCode.text.trim();
    if (otp.isEmpty || ucode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter OTP & Unique Code')),
      );
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 200));

    final ok = (otp == AppState.adminOtp) && (ucode == AppState.adminUniqueCode);
    if (ok) {
      AppState.loginAs(UserRole.admin);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged in as Admin')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wrong OTP or Code')),
        );
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Student'),
            Tab(text: 'Faculty'),
            Tab(text: 'Admin'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ---------------- STUDENT ----------------
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Continue as Student', style: t.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loading ? null : _asStudent,
                icon: const Icon(Icons.login_rounded),
                label: Text(_loading ? 'Please wait…' : 'Continue'),
              ),
            ],
          ),

          // ---------------- FACULTY ----------------
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Faculty Invite', style: t.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _facultyCode,
                decoration: const InputDecoration(
                  labelText: 'Invite code',
                  prefixIcon: Icon(Icons.qr_code_2_rounded),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loading ? null : _asFaculty,
                icon: const Icon(Icons.verified_rounded),
                label: Text(_loading ? 'Please wait…' : 'Redeem & Login'),
              ),
            ],
          ),

          // ---------------- ADMIN ----------------
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Admin Login', style: t.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _adminOtp,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Admin OTP',
                  prefixIcon: Icon(Icons.lock_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _adminUniqueCode,
                decoration: const InputDecoration(
                  labelText: 'Unique Admin Code',
                  prefixIcon: Icon(Icons.admin_panel_settings_rounded),
                ),
              ),
              const SizedBox(height: 8),
              Text('Demo OTP: ${AppState.adminOtp} • Code: ${AppState.adminUniqueCode}',
                  style: t.bodySmall?.copyWith(color: Colors.white70)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loading ? null : _asAdmin,
                icon: const Icon(Icons.verified_user_rounded),
                label: Text(_loading ? 'Checking…' : 'Login as Admin'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}