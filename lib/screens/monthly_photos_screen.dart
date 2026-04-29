import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/baby_profile.dart';
import '../widgets/home_style.dart';

class MonthlyPhotosScreen extends StatefulWidget {
  const MonthlyPhotosScreen({super.key, required this.profile});

  final BabyProfile profile;

  @override
  State<MonthlyPhotosScreen> createState() => _MonthlyPhotosScreenState();
}

class _MonthlyPhotosScreenState extends State<MonthlyPhotosScreen> {
  final _captionController = TextEditingController();
  int _selectedMonth = 1;
  bool _isLoading = true;
  bool _isPicking = false;
  List<BabyPhoto> _photos = const [];

  @override
  void initState() {
    super.initState();
    _selectedMonth = _ageInMonths(widget.profile.birthDate).clamp(1, 12);
    _loadPhotos();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final photos = await DatabaseHelper.instance.getBabyPhotos();
      if (!mounted) {
        return;
      }
      setState(() {
        _photos = photos;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _pickPhoto() async {
    setState(() {
      _isPicking = true;
    });
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 84,
      );
      if (file == null) {
        return;
      }
      final bytes = await file.readAsBytes();
      await DatabaseHelper.instance.insertBabyPhoto(
        BabyPhoto(
          month: _selectedMonth,
          photoBase64: base64Encode(bytes),
          createdAt: DateTime.now(),
          caption:
              _captionController.text.trim().isEmpty
                  ? null
                  : _captionController.text.trim(),
        ),
      );
      _captionController.clear();
      await _loadPhotos();
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
          _isPicking = false;
        });
      }
    }
  }

  Future<void> _deletePhoto(BabyPhoto photo) async {
    final id = photo.id;
    if (id == null) {
      return;
    }
    try {
      await DatabaseHelper.instance.deleteBabyPhoto(id);
      await _loadPhotos();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPhotos =
        _photos.where((photo) => photo.month == _selectedMonth).toList();

    return RefreshIndicator(
      onRefresh: _loadPhotos,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          HomeStylePageHeader(
            eyebrow: 'Photo Album',
            title: 'Monthly Photos',
            subtitle: '${_monthTitle(_selectedMonth)} Photos',
            icon: Icons.photo_library_rounded,
            badge: 'Month $_selectedMonth',
            gradient: const [
              Color(0xFFFFF4E8),
              Color(0xFFF8EEFF),
              Color(0xFFEAF6FF),
            ],
          ),
          const SizedBox(height: 20),
          HomeStyleSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add to ${_monthTitle(_selectedMonth)} Photos',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var month = 1; month <= 12; month++)
                      ChoiceChip(
                        label: Text('$month'),
                        selected: _selectedMonth == month,
                        onSelected:
                            (_) => setState(() {
                              _selectedMonth = month;
                            }),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _captionController,
                  decoration: const InputDecoration(
                    labelText: 'Caption',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isPicking ? null : _pickPhoto,
                    icon:
                        _isPicking
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.add_photo_alternate_rounded),
                    label: Text(_isPicking ? 'Uploading...' : 'Upload photo'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          HomeStyleSectionHeader(
            title: '${_monthTitle(_selectedMonth)} Photos',
            subtitle:
                selectedPhotos.isEmpty
                    ? 'No photos yet'
                    : '${selectedPhotos.length} saved',
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (selectedPhotos.isEmpty)
            const HomeStyleEmptyState(
              icon: Icons.photo_outlined,
              title: 'No photos here yet',
              description: 'Upload favorite moments for this month.',
            )
          else
            _PhotoGrid(photos: selectedPhotos, onDelete: _deletePhoto),
        ],
      ),
    );
  }

  int _ageInMonths(DateTime? birthDate) {
    if (birthDate == null) {
      return 1;
    }
    final now = DateTime.now();
    var months = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
    if (now.day < birthDate.day) {
      months--;
    }
    return months < 1 ? 1 : months;
  }

  String _monthTitle(int month) {
    return switch (month) {
      1 => 'First Month',
      2 => 'Second Month',
      3 => 'Third Month',
      4 => 'Fourth Month',
      5 => 'Fifth Month',
      6 => 'Sixth Month',
      7 => 'Seventh Month',
      8 => 'Eighth Month',
      9 => 'Ninth Month',
      10 => 'Tenth Month',
      11 => 'Eleventh Month',
      12 => 'Twelfth Month',
      _ => 'Month $month',
    };
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos, required this.onDelete});

  final List<BabyPhoto> photos;
  final ValueChanged<BabyPhoto> onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: photos.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 236,
          ),
          itemBuilder: (context, index) {
            return _PhotoCard(
              photo: photos[index],
              onDelete: () => onDelete(photos[index]),
            );
          },
        );
      },
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.photo, required this.onDelete});

  final BabyPhoto photo;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bytes = photo.photoBytes;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bytes == null)
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_rounded),
            )
          else
            Image.memory(bytes, fit: BoxFit.cover),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.48),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (photo.caption ?? '').isEmpty
                        ? DateFormat('MMM d, y').format(photo.createdAt)
                        : photo.caption!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM d, y').format(photo.createdAt),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filledTonal(
              tooltip: 'Delete photo',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
