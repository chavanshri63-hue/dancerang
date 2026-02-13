import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_config.dart';

class AppAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  String? _role;
  String? _userName;
  String? _adminKey;
  String? _facultyKey;
  bool _keysLoaded = false;
  bool _isLoading = true;
  String? _errorMessage;

  User? get user => _user;
  String? get role => _role;
  String? get userName => _userName;
  String? get adminKey => _adminKey;
  String? get facultyKey => _facultyKey;
  bool get keysLoaded => _keysLoaded;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get errorMessage => _errorMessage;

  AppAuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
    loadRoleKeys();
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _user = user;
    if (user != null) {
      await _loadUserRole();
    } else {
      _role = null;
      _userName = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadUserRole() async {
    if (_user == null) return;
    try {
      final doc = await _firestore
          .collection(AppConfig.usersCollection)
          .doc(_user!.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _role = data['role']?.toString();
        _userName = data['name']?.toString();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user role: $e');
      }
    }
    notifyListeners();
  }

  Future<void> loadRoleKeys() async {
    try {
      final doc = await _firestore
          .collection(AppConfig.appSettingsCollection)
          .doc('roleKeys')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _adminKey = data['adminKey']?.toString().trim();
        _facultyKey = data['facultyKey']?.toString().trim();
      } else {
        final envAdmin = AppConfig.adminKey;
        final envFaculty = AppConfig.facultyKey;
        _adminKey = envAdmin.isNotEmpty ? envAdmin : null;
        _facultyKey = envFaculty.isNotEmpty ? envFaculty : null;
      }
    } catch (e) {
      final envAdmin = AppConfig.adminKey;
      final envFaculty = AppConfig.facultyKey;
      _adminKey = envAdmin.isNotEmpty ? envAdmin : null;
      _facultyKey = envFaculty.isNotEmpty ? envFaculty : null;
      if (kDebugMode) {
        print('Error loading role keys: $e');
      }
    }
    _keysLoaded = true;
    notifyListeners();
  }

  Future<void> refreshRoleKeys() async {
    _keysLoaded = false;
    notifyListeners();
    await loadRoleKeys();
  }

  void updateRole(String newRole) {
    _role = newRole;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _role = null;
    _userName = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
