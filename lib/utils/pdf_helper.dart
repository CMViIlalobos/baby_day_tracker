import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/database_helper.dart';
import '../models/baby_profile.dart';
import '../models/event.dart';

class PdfHelper {
  static Future<List<BabyEvent>> loadLast7DaysEvents() async {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    return DatabaseHelper.instance.getEventsBetween(
      start,
      now.add(const Duration(days: 1)),
    );
  }

  static Future<Uint8List> generateLast7DaysPdf({
    required BabyProfile profile,
    required List<BabyEvent> events,
  }) async {
    final pdf = pw.Document();
    final grouped = <String, List<BabyEvent>>{};

    for (final event in events) {
      final key = DateFormat('EEEE, MMMM d, y').format(event.timestamp);
      grouped.putIfAbsent(key, () => []).add(event);
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(28)),
        build:
            (context) => [
              pw.Text(
                'Baby Day Tracker',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                profile.name.trim().isEmpty
                    ? 'Baby profile not set'
                    : profile.name,
              ),
              pw.Text(
                profile.birthDate == null
                    ? 'Birth date: Not set'
                    : 'Birth date: ${DateFormat('MMMM d, y').format(profile.birthDate!)}',
              ),
              pw.SizedBox(height: 20),
              if (grouped.isEmpty)
                pw.Text('No events recorded in the last 7 days.')
              else
                ...grouped.entries.map(
                  (entry) => pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        color: PdfColors.blue50,
                        child: pw.Text(
                          entry.key,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      ...entry.value.map(_buildEventRow),
                      pw.SizedBox(height: 14),
                    ],
                  ),
                ),
            ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildEventRow(BabyEvent event) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '${DateFormat('hh:mm a').format(event.timestamp)} • ${event.type.label}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(_eventDetails(event)),
          if ((event.notes ?? '').isNotEmpty) pw.Text('Notes: ${event.notes}'),
        ],
      ),
    );
  }

  static String _eventDetails(BabyEvent event) {
    return switch (event.type) {
      EventType.feeding =>
        'Side: ${event.feedingSide ?? '-'} | Duration: ${event.feedingDuration ?? 0} min',
      EventType.diaper => 'Type: ${event.diaperType ?? '-'}',
      EventType.sleep => 'Duration: ${event.sleepDuration ?? 0} min',
      EventType.medicine =>
        'Dose: ${(event.medicineDose ?? '-')} ${(event.medicineUnit ?? '')}'
            .trim(),
    };
  }

  static Future<void> sharePdf(Uint8List bytes) async {
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'baby_day_tracker_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  static String generateCsv(List<BabyEvent> events) {
    final buffer = StringBuffer();
    buffer.writeln(
      'id,type,timestamp,notes,feedingDuration,feedingSide,diaperType,sleepDuration,medicineDose,medicineUnit',
    );
    for (final event in events) {
      buffer.writeln(
        [
          event.id ?? '',
          event.type.dbValue,
          event.timestamp.toIso8601String(),
          _escapeCsv(event.notes),
          event.feedingDuration ?? '',
          _escapeCsv(event.feedingSide),
          _escapeCsv(event.diaperType),
          event.sleepDuration ?? '',
          _escapeCsv(event.medicineDose),
          _escapeCsv(event.medicineUnit),
        ].join(','),
      );
    }
    return buffer.toString();
  }

  static String _escapeCsv(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  static Future<File> writeCsvToTemp(String directoryPath, String csv) async {
    final file = File(
      p.join(
        directoryPath,
        'baby_day_tracker_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
      ),
    );
    return file.writeAsString(csv);
  }
}
