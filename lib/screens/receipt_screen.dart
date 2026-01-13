import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
// PdfGoogleFonts is exported by pdf/widgets.dart

class ReceiptScreen extends StatelessWidget {
  final Map<String, dynamic> payment;
  const ReceiptScreen({super.key, required this.payment});

  @override
  Widget build(BuildContext context) {
    final String paymentId = payment['id']?.toString() ?? '';
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Receipt'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: paymentId.isNotEmpty
            ? FirebaseFirestore.instance.collection('payments').doc(paymentId).snapshots()
            : null,
        builder: (context, snapshot) {
          // Use live data if available, otherwise fallback to passed payment data
          final paymentData = snapshot.hasData && snapshot.data!.exists
              ? {'id': paymentId, ...?snapshot.data!.data()}
              : payment;
          
          final String title = (paymentData['description'] ?? 'Payment Receipt').toString();
          // Handle both amount (in rupees) and amount_paise (in paise)
          final num rawAmount = paymentData['amount'] ?? paymentData['amount_paise'] ?? 0;
          final bool isPaise = paymentData.containsKey('amount_paise') && !paymentData.containsKey('amount');
          final num amount = isPaise ? (rawAmount / 100.0) : rawAmount;
          final String amountStr = '₹${amount.toStringAsFixed(0)}';
          final String currency = (paymentData['currency'] ?? 'INR').toString();
          final String type = (paymentData['payment_type'] ?? paymentData['type'] ?? '').toString();
          final String itemId = (paymentData['item_id'] ?? '').toString();
          final String rzpPayId = (paymentData['razorpay_payment_id'] ?? '').toString();
          final String rzpOrderId = (paymentData['razorpay_order_id'] ?? '').toString();
          final Timestamp? timestamp = paymentData['timestamp'] as Timestamp?;
          final String dateStr = timestamp != null
              ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}'
              : '';

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: Theme.of(context).cardColor,
                  elevation: 8,
                  shadowColor: const Color(0xFFE53935).withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: const Color(0xFFE53935).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
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
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'DanceRang',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'PAID',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _row(context, 'Payment ID', paymentId),
                          _row(context, 'Amount', amountStr),
                          if (dateStr.isNotEmpty) _row(context, 'Date', dateStr),
                          _row(context, 'Currency', currency),
                          if (type.isNotEmpty) _row(context, 'Type', type),
                          if (itemId.isNotEmpty) _row(context, 'Item ID', itemId),
                          if (rzpPayId.isNotEmpty) _row(context, 'Razorpay Payment ID', rzpPayId),
                          if (rzpOrderId.isNotEmpty) _row(context, 'Razorpay Order ID', rzpOrderId),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final doc = await _buildReceiptPdf(
                        paymentData: paymentData,
                        amountStr: amountStr,
                        currency: currency,
                        title: title,
                        type: type,
                        itemId: itemId,
                        rzpPayId: rzpPayId,
                        rzpOrderId: rzpOrderId,
                        dateStr: dateStr,
                      );
                      final bytes = await doc.save();
                      await Printing.sharePdf(
                        bytes: bytes,
                        filename: 'receipt_${paymentId}.pdf',
                      );
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Download PDF'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color ?? const Color(0xFFA3A3A3),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<pw.Document> _buildReceiptPdf({
    required Map<String, dynamic> paymentData,
    required String amountStr,
    required String currency,
    required String title,
    required String type,
    required String itemId,
    required String rzpPayId,
    required String rzpOrderId,
    required String dateStr,
  }) async {
    final doc = pw.Document();
    // Load Unicode-capable fonts so the Rupee symbol renders correctly
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    doc.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat.a4,
        build: (context) {
          return pw.Padding(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'DanceRang Receipt',
                        style: pw.TextStyle(fontSize: 20, font: boldFont),
                      ),
                      pw.Text(
                        'PAID',
                        style: pw.TextStyle(color: pdf.PdfColors.green, font: boldFont),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  _pdfRow('Description', title, baseFont, boldFont),
                  _pdfRow('Payment ID', paymentData['id']?.toString() ?? '', baseFont, boldFont),
                  _pdfRow('Amount', amountStr, baseFont, boldFont),
                  if (dateStr.isNotEmpty) _pdfRow('Date', dateStr, baseFont, boldFont),
                  _pdfRow('Currency', currency, baseFont, boldFont),
                  if (type.isNotEmpty) _pdfRow('Type', type, baseFont, boldFont),
                  if (itemId.isNotEmpty) _pdfRow('Item ID', itemId, baseFont, boldFont),
                  if (rzpPayId.isNotEmpty) _pdfRow('Razorpay Payment ID', rzpPayId, baseFont, boldFont),
                  if (rzpOrderId.isNotEmpty) _pdfRow('Razorpay Order ID', rzpOrderId, baseFont, boldFont),
                  pw.Spacer(),
                  pw.Text(
                    'Thank you for your payment!',
                    style: pw.TextStyle(fontSize: 12, font: baseFont),
                  ),
                ],
              ),
          );
        },
      ),
    );
    return doc;
  }

  pw.Widget _pdfRow(String label, String value, pw.Font baseFont, pw.Font boldFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(color: pdf.PdfColors.grey, font: baseFont),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: boldFont),
            ),
          ),
        ],
      ),
    );
  }
}





