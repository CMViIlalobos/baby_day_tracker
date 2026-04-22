import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../models/baby_profile.dart';
import '../utils/pdf_helper.dart';
import '../widgets/home_style.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({
    super.key,
    required this.refreshTick,
    required this.profile,
  });

  final int refreshTick;
  final BabyProfile profile;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _isExportingPdf = false;
  bool _isExportingCsv = false;

  Future<void> _exportPdf() async {
    setState(() {
      _isExportingPdf = true;
    });
    try {
      final events = await PdfHelper.loadLast7DaysEvents();
      final bytes = await PdfHelper.generateLast7DaysPdf(
        profile: widget.profile,
        events: events,
      );
      await PdfHelper.sharePdf(bytes);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isExportingPdf = false;
        });
      }
    }
  }

  Future<void> _shareCsv() async {
    setState(() {
      _isExportingCsv = true;
    });
    try {
      final events = await DatabaseHelper.instance.getAllEvents();
      final csv = PdfHelper.generateCsv(events);
      final directory = await getTemporaryDirectory();
      final file = await PdfHelper.writeCsvToTemp(directory.path, csv);
      await SharePlus.instance.share(
        ShareParams(
          text: 'Baby Day Tracker data export',
          files: [XFile(file.path)],
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isExportingCsv = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const HomeStylePageHeader(
          eyebrow: 'Sharing',
          title: 'Export Data',
          subtitle: 'PDF and CSV',
          icon: Icons.ios_share_rounded,
          gradient: [Color(0xFFFFF4E8), Color(0xFFEAF6FF), Color(0xFFEEFCEB)],
        ),
        const SizedBox(height: 20),
        HomeStyleSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeStyleSectionHeader(
                title: 'PDF Export',
                subtitle: 'Last 7 days',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isExportingPdf ? null : _exportPdf,
                icon:
                    _isExportingPdf
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.picture_as_pdf_rounded),
                label: Text(
                  _isExportingPdf ? 'Preparing PDF...' : 'Export to PDF',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        HomeStyleSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeStyleSectionHeader(
                title: 'CSV Export',
                subtitle: 'Full event log',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isExportingCsv ? null : _shareCsv,
                icon:
                    _isExportingCsv
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.table_chart_rounded),
                label: Text(_isExportingCsv ? 'Preparing CSV...' : 'Share CSV'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
