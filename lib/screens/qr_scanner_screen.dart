import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../widgets/glassmorphism_app_bar.dart';
import '../services/live_attendance_service.dart';

class QRScannerScreen extends StatefulWidget {
  final bool workshopMode; // when true, only handle workshop attendance
  const QRScannerScreen({super.key, this.workshopMode = false});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool _isScanning = false;
  bool _handlingScan = false;
  List<Map<String, dynamic>> _attendanceHistory = [];
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  @override
  void initState() {
    super.initState();
    _loadAttendanceHistory();
  }

  Future<void> _markWorkshopWithKnownIds(String userId, String? workshopId) async {
    try {
      // Resolve student name
      String studentName = 'Student';
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          studentName = userData?['name'] ?? userData?['displayName'] ?? 'Student';
        }
      } catch (_) {}

      // If server function not available, fall back to client path
      final result = await LiveAttendanceService.markWorkshopAttendance(
        userId: userId,
        userName: studentName,
        workshopId: workshopId,
      );

      if (result['success'] == true) {
        _showSuccessDialog(userId, studentName, 'Workshop', result['message']);
      } else {
        _showErrorDialog(result['message']);
      }
    } catch (e) {
      _showErrorDialog('Error marking workshop attendance: $e');
    }
  }

  Future<void> _loadAttendanceHistory() async {
    try {
      // Load recent scans; split storage for classes vs workshops
      final String collection = widget.workshopMode ? 'workshop_attendance' : 'attendance';
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection(collection)
          .limit(50)
          .get();
      
      // Sort in memory to avoid index requirement
      final attendanceDocs = attendanceSnapshot.docs.toList()
        ..sort((a, b) {
          final aMarked = (a.data()['markedAt'] as Timestamp?)?.toDate();
          final bMarked = (b.data()['markedAt'] as Timestamp?)?.toDate();
          final aTime = aMarked ?? (a.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
          final bTime = bMarked ?? (b.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });

      final attendanceHistory = attendanceDocs.map((doc) {
        final data = doc.data();
        return {
          'studentName': data['userName'] ?? data['studentName'] ?? 'Unknown Student',
          'studentId': data['userId'] ?? data['studentId'] ?? '',
          'itemName': widget.workshopMode
              ? (data['workshopName'] ?? 'Unknown Workshop')
              : (data['className'] ?? 'Unknown Class'),
          'scanTime': (data['markedAt'] as Timestamp?)?.toDate().toString() ??
              (data['timestamp'] as Timestamp?)?.toDate().toString() ?? 'Unknown Time',
          'status': data['status'] ?? 'Unknown',
        };
      }).toList();

      setState(() {
        _attendanceHistory = attendanceHistory;
      });
    } catch (e) {
      setState(() {
        _attendanceHistory = [];
      });
    }
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
    });
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null) {
        if (_handlingScan) return;
        _handlingScan = true;
        this.controller?.pauseCamera();
        _processQRData(scanData.code!);
      }
    });
  }

  void _processQRData(String qrData) {
    setState(() {
      _isScanning = false;
    });

    // Parse QR data - support multiple formats
    // Format 1: student_userId_timestamp (student QR)
    // Format 2: dancerang_attendance:classId_timestamp (class QR)
    // Format 3: dancerang_workshop:workshopId_timestamp (workshop QR)
    // Format 4: workshop_workshopId_userId_timestamp (workshop student QR)
    
    if (!widget.workshopMode && qrData.startsWith('dancerang_attendance:')) {
      // Class attendance QR - process directly
      _processClassAttendanceQR(qrData);
    } else if (qrData.startsWith('dancerang_workshop:')) {
      // Workshop attendance QR - process directly
      _processWorkshopAttendanceQR(qrData);
    } else if (qrData.startsWith('workshop_')) {
      // Workshop student QR - extract both IDs
      final parts = qrData.split('_');
      if (parts.length >= 3) {
        final workshopId = parts[1];
        final userId = parts[2];
        _markWorkshopWithKnownIds(userId, workshopId);
      } else {
        _showInvalidQRDialog();
      }
    } else if (qrData.startsWith('student_')) {
      // Student QR - show attendance type selection
      final parts = qrData.split('_');
      if (parts.length >= 2) {
        final userId = parts[1];
        if (widget.workshopMode) {
          // In workshop-only mode, try server flow with student only (auto-pick first enrolled workshop)
          _markWorkshopWithKnownIds(userId, null);
        } else {
          _showAttendanceTypeDialog(userId);
        }
      } else {
        _showInvalidQRDialog();
      }
    } else {
      _showInvalidQRDialog();
    }
  }

  void _processClassAttendanceQR(String qrData) async {
    try {
      // Get current user info (faculty/admin scanning)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorDialog('Please log in to mark attendance');
        return;
      }

      // Parse QR data to get classId
      final parts = qrData.split(':')[1].split('_');
      if (parts.length != 2) {
        _showErrorDialog('Invalid QR code format');
        return;
      }

      final classId = parts[0];
      final timestamp = int.tryParse(parts[1]);
      
      if (timestamp == null) {
        _showErrorDialog('Invalid timestamp in QR code');
        return;
      }

      // Get class information
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .get();

      if (!classDoc.exists) {
        _showErrorDialog('Class not found');
        return;
      }

      final classData = classDoc.data()!;
      final className = classData['name'] ?? 'Unknown Class';

      // Show class selection dialog for faculty/admin
      _showClassSelectionDialog(classId, className, qrData);
    } catch (e) {
      _showErrorDialog('Error processing QR code: $e');
    }
  }

  void _processWorkshopAttendanceQR(String qrData) async {
    try {
      // Get current user info (faculty/admin scanning)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorDialog('Please log in to mark attendance');
        return;
      }

      // Parse QR data to get workshopId
      final parts = qrData.split(':')[1].split('_');
      if (parts.length != 2) {
        _showErrorDialog('Invalid QR code format');
        return;
      }

      final workshopId = parts[0];
      final timestamp = int.tryParse(parts[1]);
      
      if (timestamp == null) {
        _showErrorDialog('Invalid timestamp in QR code');
        return;
      }

      // Get workshop information
      final workshopDoc = await FirebaseFirestore.instance
          .collection('workshops')
          .doc(workshopId)
          .get();

      if (!workshopDoc.exists) {
        _showErrorDialog('Workshop not found');
        return;
      }

      final workshopData = workshopDoc.data()!;
      final workshopName = workshopData['name'] ?? 'Unknown Workshop';

      // Attempt server-side marking first to bypass Firestore client rule issues
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1B1B1B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.qr_code, color: const Color(0xFF4F46E5), size: 24),
            const SizedBox(width: 8),
            const Text('Confirm Workshop Scan', style: TextStyle(color: Color(0xFFF9FAFB))),
          ]),
          content: Text('Mark attendance for "$workshopName" via server?', style: const TextStyle(color: Color(0xFFF9FAFB))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Proceed', style: TextStyle(color: Color(0xFF4F46E5)))),
          ],
        ),
      );

      if (confirm == true) {
        // Ask for student id
        String enteredId = '';
        final ok = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) {
            final controller = TextEditingController();
            return AlertDialog(
              backgroundColor: const Color(0xFF1B1B1B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Student ID', style: TextStyle(color: Color(0xFFF9FAFB))),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Enter student user ID'),
                onSubmitted: (v) { enteredId = v.trim(); Navigator.pop(dialogContext, true); },
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                TextButton(onPressed: () { enteredId = controller.text.trim(); Navigator.pop(dialogContext, true); }, child: const Text('Mark', style: TextStyle(color: Color(0xFF4F46E5)))),
              ],
            );
          },
        );

        if (ok == true && enteredId.isNotEmpty) {
          // Resolve student name
          String studentName = 'Student';
          try {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(enteredId).get();
            if (userDoc.exists) {
              final userData = userDoc.data();
              studentName = userData?['name'] ?? userData?['displayName'] ?? 'Student';
            }
          } catch (_) {}

          final result = await LiveAttendanceService.markWorkshopAttendance(
            userId: enteredId,
            userName: studentName,
            workshopId: workshopId,
          );

          if (result['success'] == true) {
            _showSuccessDialog(enteredId, studentName, 'Workshop', result['message']);
            return;
          } else {
            _showErrorDialog(result['message']);
            return;
          }
        }
      }

      // Fallback to client-side dialog
      _showWorkshopSelectionDialog(workshopId, workshopName, qrData);
    } catch (e) {
      _showErrorDialog('Error processing QR code: $e');
    }
  }

  void _processAttendanceQR(String qrData) async {
    try {
      // Get current user info (faculty/admin scanning)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorDialog('Please log in to mark attendance');
        return;
      }

      // Parse QR data to get classId
      final parts = qrData.split(':')[1].split('_');
      if (parts.length != 2) {
        _showErrorDialog('Invalid QR code format');
        return;
      }

      final classId = parts[0];
      final timestamp = int.tryParse(parts[1]);
      
      if (timestamp == null) {
        _showErrorDialog('Invalid timestamp in QR code');
        return;
      }

      // Get class information
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .get();

      if (!classDoc.exists) {
        _showErrorDialog('Class not found');
        return;
      }

      final classData = classDoc.data()!;
      final className = classData['name'] ?? 'Unknown Class';

      // Show class selection dialog for faculty/admin
      _showClassAttendanceDialog(classId, className, qrData);
    } catch (e) {
      _showErrorDialog('Error processing QR code: $e');
    }
  }

  void _showClassAttendanceDialog(String classId, String className, String qrData) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.qr_code, color: const Color(0xFFE53935), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Class Attendance',
                style: const TextStyle(color: Color(0xFFF9FAFB)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Class: $className',
              style: const TextStyle(color: Color(0xFFF9FAFB)),
            ),
            const SizedBox(height: 8),
            Text(
              'This QR code is for class attendance marking.',
              style: const TextStyle(color: Color(0xFFA3A3A3)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select action:',
              style: TextStyle(
                color: Color(0xFFF9FAFB),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _showStudentSelectionDialog(classId, className);
            },
            child: const Text('Mark Attendance', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  void _showStudentSelectionDialog(String classId, String className) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Select Student',
          style: TextStyle(color: Color(0xFFF9FAFB)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter Student ID to mark attendance:',
              style: TextStyle(color: Color(0xFFA3A3A3)),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Student ID',
                hintText: 'Enter student user ID',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (studentId) {
                Navigator.of(dialogContext).pop();
                _markAttendanceForStudent(studentId.trim(), classId, className);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              // Get text from TextField and mark attendance
              Navigator.of(dialogContext).pop();
              // This will be handled by onSubmitted
            },
            child: const Text('Mark', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  void _markAttendanceForStudent(String studentId, String classId, String className) async {
    if (studentId.isEmpty) {
      _showErrorDialog('Please enter a valid student ID');
      return;
    }

    try {
      // Get student name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get();
      
      if (!userDoc.exists) {
        _showErrorDialog('Student not found');
        return;
      }

      final userData = userDoc.data()!;
      final studentName = userData['name'] ?? userData['displayName'] ?? 'Student';

      // Mark attendance using LiveAttendanceService
      final result = await LiveAttendanceService.scanAndMarkAttendance(
        qrData: 'dancerang_attendance:${classId}_${DateTime.now().millisecondsSinceEpoch}',
        userId: studentId,
        userName: studentName,
      );

      if (result['success'] == true) {
        _showSuccessDialog(studentId, studentName, 'Class', result['message']);
      } else {
        _showErrorDialog(result['message']);
      }
    } catch (e) {
      _showErrorDialog('Error marking attendance: $e');
    }
  }

  void _showAttendanceDialog(String studentId) async {
    // Get student name
    String studentName = 'Student';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        studentName = userData?['name'] ?? userData?['displayName'] ?? 'Student';
      }
    } catch (e) {
    }

    // Show selection dialog for faculty/admin to choose between class and workshop
    _showAttendanceTypeSelectionDialog(studentId, studentName);
  }

  void _showClassSelectionDialog(String classId, String className, String qrData) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.qr_code, color: const Color(0xFFE53935), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Class Attendance',
                style: const TextStyle(color: Color(0xFFF9FAFB)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Class: $className',
              style: const TextStyle(color: Color(0xFFF9FAFB)),
            ),
            const SizedBox(height: 8),
            Text(
              'This QR code is for class attendance marking.',
              style: const TextStyle(color: Color(0xFFA3A3A3)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select action:',
              style: TextStyle(
                color: Color(0xFFF9FAFB),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _showStudentSelectionDialog(classId, className);
            },
            child: const Text('Mark Attendance', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  void _showWorkshopSelectionDialog(String workshopId, String workshopName, String qrData) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.qr_code, color: const Color(0xFF4F46E5), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Workshop Attendance',
                style: const TextStyle(color: Color(0xFFF9FAFB)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workshop: $workshopName',
              style: const TextStyle(color: Color(0xFFF9FAFB)),
            ),
            const SizedBox(height: 8),
            Text(
              'This QR code is for workshop attendance marking.',
              style: const TextStyle(color: Color(0xFFA3A3A3)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select action:',
              style: TextStyle(
                color: Color(0xFFF9FAFB),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _showWorkshopStudentSelectionDialog(workshopId, workshopName);
            },
            child: const Text('Mark Attendance', style: TextStyle(color: Color(0xFF4F46E5))),
          ),
        ],
      ),
    );
  }

  void _showWorkshopAttendanceDialog(String studentId, String workshopId) async {
    // Get student name
    String studentName = 'Student';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        studentName = userData?['name'] ?? userData?['displayName'] ?? 'Student';
      }
    } catch (e) {
    }

    // Mark workshop attendance directly
    _markWorkshopAttendance(studentId, studentName);
  }

  void _showAttendanceTypeDialog(String studentId) async {
    // Get student name
    String studentName = 'Student';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        studentName = userData?['name'] ?? userData?['displayName'] ?? 'Student';
      }
    } catch (e) {
    }

    // Show selection dialog for faculty/admin to choose between class and workshop
    _showAttendanceTypeSelectionDialog(studentId, studentName);
  }

  void _showAttendanceTypeSelectionDialog(String studentId, String studentName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.person, color: const Color(0xFFE53935), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mark Attendance',
                style: const TextStyle(color: Color(0xFFF9FAFB)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student: $studentName',
              style: const TextStyle(color: Color(0xFFF9FAFB)),
            ),
            const SizedBox(height: 8),
            Text(
              'ID: $studentId',
              style: const TextStyle(color: Color(0xFFA3A3A3), fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select attendance type:',
              style: TextStyle(
                color: Color(0xFFF9FAFB),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _markClassAttendance(studentId, studentName);
            },
            child: const Text('Class', style: TextStyle(color: Color(0xFFE53935))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _markWorkshopAttendance(studentId, studentName);
            },
            child: const Text('Workshop', style: TextStyle(color: Color(0xFF4F46E5))),
          ),
        ],
      ),
    );
  }

  void _markClassAttendance(String studentId, String studentName) async {
    try {
      final result = await LiveAttendanceService.markClassAttendance(
        userId: studentId,
        userName: studentName,
      );

      if (result['success'] == true) {
        _showSuccessDialog(studentId, studentName, 'Class', result['message']);
      } else {
        _showErrorDialog(result['message']);
      }
    } catch (e) {
      _showErrorDialog('Error marking class attendance: $e');
    }
  }

  void _showWorkshopStudentSelectionDialog(String workshopId, String workshopName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Select Student',
          style: TextStyle(color: Color(0xFFF9FAFB)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter Student ID to mark workshop attendance:',
              style: TextStyle(color: Color(0xFFA3A3A3)),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Student ID',
                hintText: 'Enter student user ID',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (studentId) {
                Navigator.of(dialogContext).pop();
                _markWorkshopAttendanceForStudent(studentId.trim(), workshopId, workshopName);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Mark', style: TextStyle(color: Color(0xFF4F46E5))),
          ),
        ],
      ),
    );
  }

  void _markWorkshopAttendanceForStudent(String studentId, String workshopId, String workshopName) async {
    if (studentId.isEmpty) {
      _showErrorDialog('Please enter a valid student ID');
      return;
    }

    try {
      // Get student name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get();
      
      if (!userDoc.exists) {
        _showErrorDialog('Student not found');
        return;
      }

      final userData = userDoc.data()!;
      final studentName = userData['name'] ?? userData['displayName'] ?? 'Student';

      // Mark workshop attendance using LiveAttendanceService
      final result = await LiveAttendanceService.markWorkshopAttendance(
        userId: studentId,
        userName: studentName,
      );

      if (result['success'] == true) {
        _showSuccessDialog(studentId, studentName, 'Workshop', result['message']);
        // Refresh attendance history
        _loadAttendanceHistory();
      } else {
        _showErrorDialog(result['message']);
      }
    } catch (e) {
      _showErrorDialog('Error marking attendance: $e');
    }
  }

  void _markWorkshopAttendance(String studentId, String studentName) async {
    try {
      final result = await LiveAttendanceService.markWorkshopAttendance(
        userId: studentId,
        userName: studentName,
      );

      if (result['success'] == true) {
        _showSuccessDialog(studentId, studentName, 'Workshop', result['message']);
        // Refresh attendance history
        _loadAttendanceHistory();
      } else {
        _showErrorDialog(result['message']);
      }
    } catch (e) {
      _showErrorDialog('Error marking workshop attendance: $e');
    }
  }

  void _showSuccessDialog(String studentId, String studentName, String type, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$type Attendance Marked',
                style: const TextStyle(color: Color(0xFFF9FAFB)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student: $studentName',
              style: const TextStyle(color: Color(0xFFF9FAFB)),
            ),
            const SizedBox(height: 4),
            Text(
              'ID: $studentId',
              style: const TextStyle(color: Color(0xFFA3A3A3), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              'Time: ${DateTime.now().toString().split('.')[0]}',
              style: const TextStyle(color: Color(0xFFA3A3A3)),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _addToHistory(studentId);
              // Resume scanning
              controller?.resumeCamera();
              setState(() { _isScanning = true; });
              _handlingScan = false;
            },
            child: const Text('OK', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Attendance Failed',
              style: TextStyle(color: Color(0xFFF9FAFB)),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFFF9FAFB)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              controller?.resumeCamera();
              setState(() { _isScanning = true; });
              _handlingScan = false;
            },
            child: const Text('OK', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  void _showInvalidQRDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Invalid QR Code',
              style: TextStyle(color: Color(0xFFF9FAFB)),
            ),
          ],
        ),
        content: const Text(
          'This QR code is not valid for attendance marking.',
          style: TextStyle(color: Color(0xFFF9FAFB)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller?.resumeCamera();
              setState(() { _isScanning = true; });
              _handlingScan = false;
            },
            child: const Text('OK', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  void _addToHistory(String studentId) {
    setState(() {
      _attendanceHistory.insert(0, {
        'studentName': 'Student $studentId',
        'studentId': studentId,
        'itemName': widget.workshopMode ? 'Current Workshop' : 'Current Class',
        'scanTime': DateTime.now().toString().split(' ')[1].substring(0, 5),
        'status': 'Present',
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: GlassmorphismAppBar(
        title: 'QR Scanner',
        onLeadingPressed: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          // Scanner Area
          Expanded(
            flex: 2,
            child: Card(
              elevation: 8,
              shadowColor: const Color(0xFFE53935).withValues(alpha: 0.2),
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: const Color(0xFFE53935).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              margin: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).cardColor,
                      Theme.of(context).cardColor.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              child: _isScanning
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: QRView(
                        key: qrKey,
                        onQRViewCreated: _onQRViewCreated,
                        overlay: QrScannerOverlayShape(
                          borderColor: const Color(0xFFE53935),
                          borderRadius: 12,
                          borderLength: 30,
                          borderWidth: 10,
                          cutOutSize: 250,
                        ),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 80,
                          color: const Color(0xFFE53935).withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Ready to Scan',
                          style: TextStyle(
                            color: Color(0xFFF9FAFB),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap the scan button to start',
                          style: TextStyle(
                            color: Color(0xFFA3A3A3),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          ),
          
          // Scan Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE53935).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _startScanning,
                icon: Icon(_isScanning ? Icons.stop : Icons.qr_code_scanner),
                label: Text(_isScanning ? 'Scanning...' : 'Start Scanning'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
          
          // Attendance History
          Expanded(
            flex: 1,
            child: Card(
              elevation: 8,
              shadowColor: const Color(0xFFE53935).withValues(alpha: 0.2),
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: const Color(0xFFE53935).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).cardColor,
                      Theme.of(context).cardColor.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.history, color: const Color(0xFFE53935), size: 20),
                          const SizedBox(width: 8),
                          const Text(
                          'Recent Scans',
                          style: TextStyle(
                            color: Color(0xFFF9FAFB),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _attendanceHistory.length,
                      itemBuilder: (context, index) {
                        final record = _attendanceHistory[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: record['status'] == 'Present' 
                                ? Colors.green 
                                : Colors.orange,
                            child: Icon(
                              record['status'] == 'Present' 
                                  ? Icons.check 
                                  : Icons.schedule,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            record['studentName'],
                            style: const TextStyle(
                              color: Color(0xFFF9FAFB),
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${record['itemName']} • ${record['scanTime']}',
                            style: const TextStyle(
                              color: Color(0xFFA3A3A3),
                              fontSize: 12,
                            ),
                          ),
                          trailing: Text(
                            record['status'],
                            style: TextStyle(
                              color: record['status'] == 'Present' 
                                  ? Colors.green 
                                  : Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
