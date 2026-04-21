import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../models/baby_profile.dart';
import '../utils/notification_helper.dart';
import '../utils/pdf_helper.dart';
import '../widgets/app_accordion_section.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.refreshTick,
    required this.profile,
    required this.onChanged,
  });

  final int refreshTick;
  final BabyProfile profile;
  final Future<void> Function() onChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late DateTime? _birthDate;
  late AppThemeColor _themeColor;
  late bool _notificationsEnabled;
  late List<String> _reminderTimes;
  bool _isSaving = false;
  bool _isExportingPdf = false;
  bool _isExportingCsv = false;

  @override
  void initState() {
    super.initState();
    _applyProfile(widget.profile);
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _nameController.dispose();
      _applyProfile(widget.profile);
    }
  }

  void _applyProfile(BabyProfile profile) {
    _nameController = TextEditingController(text: profile.name);
    _birthDate = profile.birthDate;
    _themeColor = profile.themeColorValue;
    _notificationsEnabled = profile.notificationsEnabled;
    _reminderTimes = List<String>.from(profile.reminderTimes)..sort();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDate: _birthDate ?? now,
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  Future<void> _addReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) {
      return;
    }
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (_reminderTimes.contains(formatted)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That reminder already exists.')),
      );
      return;
    }
    setState(() {
      _reminderTimes = [..._reminderTimes, formatted]..sort();
    });
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
    });
    try {
      final profile = BabyProfile(
        id: 1,
        name: _nameController.text.trim(),
        birthDate: _birthDate,
        themeColorValue: _themeColor,
        notificationsEnabled: _notificationsEnabled,
        reminderTimes: _reminderTimes,
      );
      await DatabaseHelper.instance.saveBabyProfile(profile);
      await NotificationHelper.instance.syncProfileReminders(profile);
      await widget.onChanged();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved')));
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
          _isSaving = false;
        });
      }
    }
  }

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

  String _buildAgeLabel() {
    if (_birthDate == null) {
      return 'Set a birth date to calculate age.';
    }
    final now = DateTime.now();
    final difference = now.difference(_birthDate!);
    final days = difference.inDays;
    final weeks = days ~/ 7;
    final remainingDays = days % 7;
    if (weeks > 0) {
      return '$weeks weeks, $remainingDays days old';
    }
    return '$days days old';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: scheme.surface,
            border: Border.all(color: scheme.outlineVariant),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Baby Profile',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'A cleaner control center for details, reminders, and exports with the new design language applied.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppAccordionSection(
          title: 'Profile details',
          subtitle: 'Name, birth date, and age summary.',
          initiallyExpanded: true,
          leading: Icon(Icons.badge_rounded, color: scheme.primary),
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Baby name',
                prefixIcon: Icon(Icons.edit_rounded),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickBirthDate,
              icon: const Icon(Icons.calendar_month_rounded),
              label: Text(
                _birthDate == null
                    ? 'Select birth date'
                    : DateFormat('MMMM d, y').format(_birthDate!),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _buildAgeLabel(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppAccordionSection(
          title: 'Appearance',
          subtitle: 'Theme accent and app presentation.',
          leading: Icon(Icons.palette_outlined, color: scheme.primary),
          children: [
            Text(
              'Accent color',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            SegmentedButton<AppThemeColor>(
              selected: {_themeColor},
              onSelectionChanged: (selection) {
                setState(() {
                  _themeColor = selection.first;
                });
              },
              segments:
                  AppThemeColor.values
                      .map(
                        (theme) => ButtonSegment<AppThemeColor>(
                          value: theme,
                          label: Text(theme.label),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppAccordionSection(
          title: 'Reminder settings',
          subtitle: 'Local reminders and quick reminder chips.',
          leading: Icon(Icons.notifications_outlined, color: scheme.primary),
          children: [
            SwitchListTile.adaptive(
              value: _notificationsEnabled,
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable local reminders'),
              subtitle: const Text(
                'Notifications stay on this device and use your saved reminder times.',
              ),
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final reminder in _reminderTimes)
                  InputChip(
                    label: Text(_formatReminder(reminder)),
                    onDeleted: () {
                      setState(() {
                        _reminderTimes =
                            _reminderTimes
                                .where((item) => item != reminder)
                                .toList();
                      });
                    },
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add_alarm_rounded, size: 18),
                  label: const Text('Add reminder'),
                  onPressed: _addReminderTime,
                ),
              ],
            ),
            if (_reminderTimes.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Try reminders like 9:00 AM, 12:00 PM, and 3:00 PM.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AppAccordionSection(
          title: 'Exports',
          subtitle: 'PDF and CSV sharing actions.',
          leading: Icon(Icons.ios_share_rounded, color: scheme.primary),
          children: [
            Text(
              'Share a 7-day PDF summary or your full care history as CSV.',
              style: Theme.of(context).textTheme.bodyMedium,
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
              label: Text(_isExportingPdf ? 'Preparing PDF...' : 'Export PDF'),
            ),
            const SizedBox(height: 12),
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
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _isSaving ? null : _saveProfile,
          icon:
              _isSaving
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.save_rounded),
          label: Text(_isSaving ? 'Saving...' : 'Save profile'),
        ),
      ],
    );
  }

  String _formatReminder(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = int.tryParse(parts.last) ?? 0;
    return DateFormat.jm().format(DateTime(2000, 1, 1, hour, minute));
  }
}
