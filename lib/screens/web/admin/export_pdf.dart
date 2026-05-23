import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AdminExportPdf {
  static Future<Uint8List> generateTablePdf({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    String subtitle = 'Bulacan State University - College of Information and Communications Technology (CICT)',
  }) async {
    final pdf = pw.Document();
    final bsuLogo = await _loadImage('assets/images/bsu_logo.png');
    final cictLogo = await _loadImage('assets/images/cict_logo.png');
    final upriseLogo = await _loadImage('assets/images/logo.png');
    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (bsuLogo != null) pw.Image(bsuLogo, height: 40),
                if (cictLogo != null) pw.Image(cictLogo, height: 40),
                if (upriseLogo != null) pw.Image(upriseLogo, height: 30),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              'Page ${context.pageNumber}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          );
        },
        build: (context) => [
          pw.Header(level: 0, title: title),
          pw.SizedBox(height: 10),
          pw.Text(
            subtitle,
            style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated: $now',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
          pw.Divider(),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            columnWidths: {
              for (var i = 0; i < headers.length; i++) i: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: headers.map((header) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      header ?? '',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                    ),
                  );
                }).toList(),
              ),
              ...rows.map((row) {
                return pw.TableRow(
                  children: List.generate(headers.length, (index) {
                    final value = index < row.length ? row[index] : '';
                    return pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(value ?? '', style: pw.TextStyle(fontSize: 10)),
                    );
                  }),
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<pw.MemoryImage?> _loadImage(String path) async {
    try {
      final byteData = await rootBundle.load(path);
      return pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }
}
