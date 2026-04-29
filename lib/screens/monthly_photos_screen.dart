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
  PageController? _stackController;
  int _selectedMonth = 1;
  int _activePhotoIndex = 0;
  bool _isLoading = true;
  bool _isPicking = false;
  List<BabyPhoto> _photos = const [];

  @override
  void initState() {
    super.initState();
    _selectedMonth = _ageInMonths(widget.profile.birthDate).clamp(1, 12);
    _stackController = PageController(viewportFraction: 0.86);
    _loadPhotos();
  }

  @override
  void dispose() {
    _stackController?.dispose();
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

  void _openGallery(List<BabyPhoto> photos, int initialIndex) {
    if (photos.isEmpty) {
      return;
    }
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder:
          (_) => _PhotoGalleryDialog(
            photos: photos,
            initialIndex: initialIndex,
            onDelete: (photo) async {
              Navigator.of(context).pop();
              await _deletePhoto(photo);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _stackController ??= PageController(viewportFraction: 0.86);
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
                              _activePhotoIndex = 0;
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
          else ...[
            _StackedPhotoCarousel(
              photos: selectedPhotos,
              controller: _stackController!,
              activeIndex: _activePhotoIndex.clamp(
                0,
                selectedPhotos.length - 1,
              ),
              onPageChanged:
                  (index) => setState(() {
                    _activePhotoIndex = index;
                  }),
              onOpen:
                  (index) => _openGallery(
                    selectedPhotos,
                    index.clamp(0, selectedPhotos.length - 1),
                  ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'All photos',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed:
                      () => _openGallery(
                        selectedPhotos,
                        _activePhotoIndex.clamp(0, selectedPhotos.length - 1),
                      ),
                  child: const Text('Open all'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _PhotoGrid(
              photos: selectedPhotos,
              onDelete: _deletePhoto,
              onOpen: (index) => _openGallery(selectedPhotos, index),
            ),
          ],
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

class _StackedPhotoCarousel extends StatelessWidget {
  const _StackedPhotoCarousel({
    required this.photos,
    required this.controller,
    required this.activeIndex,
    required this.onPageChanged,
    required this.onOpen,
  });

  final List<BabyPhoto> photos;
  final PageController controller;
  final int activeIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 410,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (photos.length > 1)
            Positioned(
              right: 22,
              top: 32,
              bottom: 32,
              child: Transform.rotate(
                angle: 0.055,
                child: _StackBackPlate(
                  photo: photos[(activeIndex + 1) % photos.length],
                ),
              ),
            ),
          if (photos.length > 2)
            Positioned(
              left: 22,
              top: 48,
              bottom: 48,
              child: Transform.rotate(
                angle: -0.045,
                child: _StackBackPlate(
                  photo: photos[(activeIndex + 2) % photos.length],
                ),
              ),
            ),
          PageView.builder(
            controller: controller,
            itemCount: photos.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  var scale = 1.0;
                  if (controller.position.haveDimensions) {
                    final page =
                        controller.page ?? controller.initialPage.toDouble();
                    scale = (1 - (page - index).abs() * 0.08).clamp(0.9, 1.0);
                  }
                  return Transform.scale(scale: scale, child: child);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _FeaturedPhotoCard(
                    photo: photos[index],
                    index: index,
                    count: photos.length,
                    onTap: () => onOpen(index),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StackBackPlate extends StatelessWidget {
  const _StackBackPlate({required this.photo});

  final BabyPhoto photo;

  @override
  Widget build(BuildContext context) {
    final bytes = photo.photoBytes;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        image:
            bytes == null
                ? null
                : DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
      ),
    );
  }
}

class _FeaturedPhotoCard extends StatelessWidget {
  const _FeaturedPhotoCard({
    required this.photo,
    required this.index,
    required this.count,
    required this.onTap,
  });

  final BabyPhoto photo;
  final int index;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bytes = photo.photoBytes;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.13),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes == null)
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image_rounded, size: 42),
              )
            else
              Image.memory(bytes, fit: BoxFit.cover),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.04),
                      Colors.black.withValues(alpha: 0.12),
                      Colors.black.withValues(alpha: 0.68),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${index + 1}/$count',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (photo.caption ?? '').isEmpty
                        ? 'Photo memory'
                        : photo.caption!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        DateFormat('MMM d, y').format(photo.createdAt),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF1D2226),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.onDelete,
    required this.onOpen,
  });

  final List<BabyPhoto> photos;
  final ValueChanged<BabyPhoto> onDelete;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 840
                ? 3
                : constraints.maxWidth >= 520
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: photos.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: columns == 1 ? 320 : 236,
          ),
          itemBuilder: (context, index) {
            return _PhotoCard(
              photo: photos[index],
              onOpen: () => onOpen(index),
              onDelete: () => onDelete(photos[index]),
            );
          },
        );
      },
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.photo,
    required this.onOpen,
    required this.onDelete,
  });

  final BabyPhoto photo;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bytes = photo.photoBytes;

    return GestureDetector(
      onTap: onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
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
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
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
      ),
    );
  }
}

class _PhotoGalleryDialog extends StatefulWidget {
  const _PhotoGalleryDialog({
    required this.photos,
    required this.initialIndex,
    required this.onDelete,
  });

  final List<BabyPhoto> photos;
  final int initialIndex;
  final ValueChanged<BabyPhoto> onDelete;

  @override
  State<_PhotoGalleryDialog> createState() => _PhotoGalleryDialogState();
}

class _PhotoGalleryDialogState extends State<_PhotoGalleryDialog> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.photos.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                final bytes = photo.photoBytes;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(18, 70, 18, 110),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child:
                              bytes == null
                                  ? Container(
                                    color: const Color(0xFF202428),
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image_rounded,
                                        color: Colors.white,
                                        size: 48,
                                      ),
                                    ),
                                  )
                                  : InteractiveViewer(
                                    child: Image.memory(
                                      bytes,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        (photo.caption ?? '').isEmpty
                            ? 'Photo memory'
                            : photo.caption!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('MMM d, y').format(photo.createdAt),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              top: 14,
              left: 14,
              child: IconButton.filled(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_index + 1}/${widget.photos.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => widget.onDelete(widget.photos[_index]),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
