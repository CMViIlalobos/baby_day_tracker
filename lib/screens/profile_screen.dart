import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/baby_profile.dart';
import '../widgets/home_style.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.refreshTick,
    required this.profile,
    required this.onPreviewChanged,
    required this.onChanged,
  });

  final int refreshTick;
  final BabyProfile profile;
  final ValueChanged<BabyProfile> onPreviewChanged;
  final Future<void> Function() onChanged;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  DateTime? _birthDate;
  AppThemeColor _themeColor = AppThemeColor.blue;
  String? _photoBase64;
  bool _isSaving = false;
  bool _isPickingPhoto = false;

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
    _photoBase64 = profile.photoBase64;
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
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDate: _birthDate ?? now,
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
      _emitPreview();
    }
  }

  Future<void> _pickPhoto() async {
    setState(() {
      _isPickingPhoto = true;
    });
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        imageQuality: 82,
      );
      if (file == null) {
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _photoBase64 = base64Encode(bytes);
      });
      _emitPreview();
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
          _isPickingPhoto = false;
        });
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _photoBase64 = null;
    });
    _emitPreview();
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
    });
    try {
      final profile = _draftProfile();
      await DatabaseHelper.instance.saveBabyProfile(profile);
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

  BabyProfile _draftProfile() {
    return widget.profile.copyWith(
      name: _nameController.text.trim(),
      birthDate: _birthDate,
      clearBirthDate: _birthDate == null,
      themeColorValue: _themeColor,
      photoBase64: _photoBase64,
      clearPhoto: _photoBase64 == null,
      notificationsEnabled: false,
      reminderTimes: const [],
    );
  }

  void _emitPreview() {
    widget.onPreviewChanged(_draftProfile());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayName =
        _nameController.text.trim().isEmpty
            ? 'Baby'
            : _nameController.text.trim();
    final photoBytes = _draftProfile().photoBytes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        HomeStylePageHeader(
          eyebrow: 'Baby Profile',
          title: displayName,
          subtitle: _birthDate == null ? 'Birth date not set' : _ageLabel(),
          icon: Icons.child_care_rounded,
          badge:
              _birthDate == null
                  ? 'Set birth date'
                  : '${_ageInMonths(_birthDate!)} months',
          gradient: const [
            Color(0xFFFFF4E8),
            Color(0xFFEAF6FF),
            Color(0xFFE7F8EF),
          ],
        ),
        const SizedBox(height: 20),
        HomeStyleSurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile Details',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: scheme.surfaceContainerHighest,
                      backgroundImage:
                          photoBytes == null ? null : MemoryImage(photoBytes),
                      child:
                          photoBytes == null
                              ? Icon(
                                Icons.child_care_rounded,
                                size: 40,
                                color: scheme.primary,
                              )
                              : null,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: _isPickingPhoto ? null : _pickPhoto,
                          icon:
                              _isPickingPhoto
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.photo_library_rounded),
                          label: Text(
                            photoBytes == null
                                ? 'Upload profile photo'
                                : 'Change profile photo',
                          ),
                        ),
                        if (photoBytes != null)
                          OutlinedButton.icon(
                            onPressed: _removePhoto,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Remove'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _nameController,
                onChanged: (_) {
                  setState(() {});
                  _emitPreview();
                },
                decoration: const InputDecoration(
                  labelText: 'Baby name',
                  prefixIcon: Icon(Icons.edit_rounded),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _pickBirthDate,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(
                    _birthDate == null
                        ? 'Select birth date'
                        : DateFormat('MMMM d, y').format(_birthDate!),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _birthDate == null
                      ? 'Current age appears here after you choose a birth date.'
                      : _ageLabel(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        HomeStyleSurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme Color',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              SegmentedButton<AppThemeColor>(
                selected: {_themeColor},
                onSelectionChanged: (selection) {
                  setState(() {
                    _themeColor = selection.first;
                  });
                  _emitPreview();
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

  String _ageLabel() {
    final birthDate = _birthDate;
    if (birthDate == null) {
      return 'Birth date not set';
    }
    final months = _ageInMonths(birthDate);
    final days = DateTime.now().difference(birthDate).inDays;
    if (months == 0) {
      return '$days days old';
    }
    return '$months months old';
  }

  int _ageInMonths(DateTime birthDate) {
    final now = DateTime.now();
    var months = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
    if (now.day < birthDate.day) {
      months--;
    }
    return months < 0 ? 0 : months;
  }
}
