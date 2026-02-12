import 'package:flutter/material.dart';

class QRViewController {
  Future<void> toggleFlash() async {}
  Future<void> flipCamera() async {}
  void pauseCamera() {}
  void resumeCamera() {}
  Stream<Barcode> get scannedDataStream => const Stream.empty();
  void dispose() {}
}

class Barcode {
  final String? code;
  Barcode({this.code});
}

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderRadius = 0,
    this.borderLength = 40,
    this.borderWidth = 3,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

class QRView extends StatelessWidget {
  final GlobalKey key;
  final Function(QRViewController) onQRViewCreated;
  final ShapeBorder? overlay;

  const QRView({
    required this.key,
    required this.onQRViewCreated,
    this.overlay,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'QR Scanner is not available on web',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}
