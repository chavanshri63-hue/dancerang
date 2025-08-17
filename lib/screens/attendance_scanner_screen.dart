import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../app_state.dart';

class AttendanceScannerScreen extends StatefulWidget {
  const AttendanceScannerScreen({super.key});

  @override
  State<AttendanceScannerScreen> createState() => _AttendanceScannerScreenState();
}

class _AttendanceScannerScreenState extends State<AttendanceScannerScreen> {
  final controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _handled = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_handled) return;
    final value = cap.barcodes.first.rawValue;
    if (value == null) return;
    _handled = true;

    // DEMO: mark attendance locally
    AppState.markAttendance(DateTime.now());

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance marked for payload: $value')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Student QR')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect, controller: controller),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => controller.toggleTorch(),
                      icon: const Icon(Icons.flash_on_rounded),
                      label: const Text('Torch'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => controller.switchCamera(),
                      icon: const Icon(Icons.cameraswitch_rounded),
                      label: const Text('Camera'),
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