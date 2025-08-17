import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AttendanceQrScreen extends StatelessWidget {
  const AttendanceQrScreen({super.key});

  String get _payload => 'DR|student:demo|ts:${DateTime.now().millisecondsSinceEpoch}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Attendance QR')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QrImageView(
              data: _payload,
              size: 260,
              backgroundColor: Colors.white,
              version: QrVersions.auto,
            ),
            const SizedBox(height: 16),
            const Text('Show this QR to faculty to mark attendance'),
          ],
        ),
      ),
    );
  }
}