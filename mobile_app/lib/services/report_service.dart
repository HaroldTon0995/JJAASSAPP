import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order_model.dart';
import '../core/utils/download_helper.dart' as dh;

class ReportService {
  /// Generates a CSV report from the given orders list and triggers a download.
  static Future<void> exportCSV({
    required List<OrderModel> orders,
    required String interval,
    required String formattedDate,
  }) async {
    final buffer = StringBuffer();
    
    // Write CSV headers
    buffer.writeln('Order ID,Customer Name,Customer Phone,Delivery Address,Water Type,Quantity,Price per Unit,Total Amount,Payment Method,Payment Status,Order Status,Completed At,Created At');
    
    // Write CSV data rows
    for (final order in orders) {
      final sanitizedCustomerName = order.customerName.replaceAll('"', '""');
      final sanitizedAddress = order.deliveryAddress.replaceAll('"', '""');
      final sanitizedPhone = order.customerPhone.replaceAll('"', '""');
      final completedStr = order.completedAt != null ? order.completedAt!.toIso8601String() : 'N/A';
      
      buffer.writeln(
        '"${order.id}",'
        '"$sanitizedCustomerName",'
        '"$sanitizedPhone",'
        '"$sanitizedAddress",'
        '"${order.waterType}",'
        '${order.quantity},'
        '${order.pricePerUnit},'
        '${order.totalAmount},'
        '"${order.paymentMethod}",'
        '"${order.paymentStatus}",'
        '"${order.orderStatus.displayName}",'
        '"$completedStr",'
        '"${order.createdAt.toIso8601String()}"'
      );
    }

    final sanitizedDate = formattedDate.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = 'Sales_Report_${interval}_$sanitizedDate.csv';
    
    await dh.downloadFile(
      content: buffer.toString(),
      fileName: fileName,
      mimeType: 'text/csv',
    );
  }

  /// Generates a PDF document for the given orders list.
  static Future<Uint8List> _generatePDFBytes({
    required List<OrderModel> orders,
    required String interval,
    required String formattedDate,
  }) async {
    final pdf = pw.Document();

    // Calculations
    double totalRevenue = 0;
    int purifiedJugQty = 0;
    int alkalineJugQty = 0;
    for (var o in orders) {
      totalRevenue += o.totalAmount;
      if (o.waterType.toLowerCase().contains('purified')) {
        purifiedJugQty += o.quantity;
      } else {
        alkalineJugQty += o.quantity;
      }
    }
    double averageOrderValue = orders.isEmpty ? 0 : totalRevenue / orders.length;
    String popularType = (purifiedJugQty >= alkalineJugQty) ? '19L Purified' : '19L Alkaline';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Report Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('JJAASS WATER SYSTEM', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.SizedBox(height: 4),
                    pw.Text('Sales & Financial Statements', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('INCOME REPORT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text('$interval ($formattedDate)', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 20),

            // Summary Cards Block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildPDFStatCard('Total Revenue', 'PHP ${totalRevenue.toStringAsFixed(2)}', PdfColors.green800),
                _buildPDFStatCard('Completed Orders', '${orders.length}', PdfColors.blue800),
                _buildPDFStatCard('Average Sale', 'PHP ${averageOrderValue.toStringAsFixed(2)}', PdfColors.orange800),
                _buildPDFStatCard('Best Product', popularType, PdfColors.cyan800),
              ],
            ),
            pw.SizedBox(height: 25),

            // Orders Table Title
            pw.Text('Transaction Breakdown', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            pw.SizedBox(height: 10),

            // Table of Orders
            pw.TableHelper.fromTextArray(
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
              headers: ['Order ID', 'Customer', 'Water Type', 'Qty', 'Payment', 'Status', 'Total'],
              data: orders.map((o) {
                return [
                  o.id,
                  o.customerName.length > 15 ? '${o.customerName.substring(0, 12)}...' : o.customerName,
                  o.waterType.replaceAll('19L ', ''),
                  o.quantity.toString(),
                  o.paymentMethod.replaceAll('on Delivery', '').replaceAll('Cash', 'COD'),
                  o.paymentStatus,
                  'PHP ${o.totalAmount.toStringAsFixed(2)}',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 8),
              columnWidths: {
                0: const pw.FixedColumnWidth(45),
                1: const pw.FixedColumnWidth(80),
                2: const pw.FixedColumnWidth(70),
                3: const pw.FixedColumnWidth(25),
                4: const pw.FixedColumnWidth(50),
                5: const pw.FixedColumnWidth(40),
                6: const pw.FixedColumnWidth(70),
              },
            ),

            pw.SizedBox(height: 30),
            
            // Signature section
            pw.Align(
              alignment: pw.Alignment.bottomRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 150,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(top: pw.BorderSide(color: PdfColors.grey800, width: 1)),
                    ),
                    padding: const pw.EdgeInsets.only(top: 4),
                    child: pw.Center(
                      child: pw.Text('Authorized Signature', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Center(
                    child: pw.Text('Report Generated on ${DateTime.now().toString().split('.')[0]}', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Displays printing preview layout of the sales report.
  static Future<void> printPDF({
    required List<OrderModel> orders,
    required String interval,
    required String formattedDate,
  }) async {
    final pdfBytes = await _generatePDFBytes(
      orders: orders,
      interval: interval,
      formattedDate: formattedDate,
    );

    final sanitizedDate = formattedDate.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = 'Sales_Report_${interval}_$sanitizedDate.pdf';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: fileName,
    );
  }

  /// Downloads the PDF report file directly to disk.
  static Future<void> downloadPDF({
    required List<OrderModel> orders,
    required String interval,
    required String formattedDate,
  }) async {
    final pdfBytes = await _generatePDFBytes(
      orders: orders,
      interval: interval,
      formattedDate: formattedDate,
    );

    final sanitizedDate = formattedDate.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = 'Sales_Report_${interval}_$sanitizedDate.pdf';

    await dh.downloadBytes(
      bytes: pdfBytes,
      fileName: fileName,
      mimeType: 'application/pdf',
    );
  }

  // Stat card builder for pdf layout
  static pw.Widget _buildPDFStatCard(String label, String value, PdfColor textColor) {
    return pw.Container(
      width: 110,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }
}
