import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/baby_profile.dart';
import '../widgets/home_style.dart';

class DevelopmentScreen extends StatefulWidget {
  const DevelopmentScreen({
    super.key,
    required this.refreshTick,
    required this.profile,
    required this.onChanged,
  });

  final int refreshTick;
  final BabyProfile profile;
  final Future<void> Function() onChanged;

  @override
  State<DevelopmentScreen> createState() => _DevelopmentScreenState();
}

class _DevelopmentScreenState extends State<DevelopmentScreen> {
  bool _isLoading = true;
  List<GrowthEntry> _growthEntries = const [];
  List<MilestoneEntry> _milestones = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant DevelopmentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final growthEntries = await DatabaseHelper.instance.getGrowthEntries();
      final milestones = await DatabaseHelper.instance.getMilestones();
      if (!mounted) {
        return;
      }
      setState(() {
        _growthEntries = growthEntries;
        _milestones = milestones;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      _showError(error);
    }
  }

  Future<void> _openGrowthEditor() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _GrowthBottomSheet(),
    );
    if (saved == true) {
      await _loadData();
      await widget.onChanged();
    }
  }

  Future<void> _openMilestoneEditor() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _MilestoneBottomSheet(),
    );
    if (saved == true) {
      await _loadData();
      await widget.onChanged();
    }
  }

  Future<void> _deleteGrowth(GrowthEntry entry) async {
    if (entry.id == null) {
      return;
    }
    try {
      await DatabaseHelper.instance.deleteGrowthEntry(entry.id!);
      await _loadData();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _deleteMilestone(MilestoneEntry milestone) async {
    if (milestone.id == null) {
      return;
    }
    try {
      await DatabaseHelper.instance.deleteMilestone(milestone.id!);
      await _loadData();
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final latestGrowth = _growthEntries.isEmpty ? null : _growthEntries.first;
    final previousGrowth = _growthEntries.length > 1 ? _growthEntries[1] : null;
    final weightDelta =
        latestGrowth?.weightKg != null && previousGrowth?.weightKg != null
            ? latestGrowth!.weightKg! - previousGrowth!.weightKg!
            : null;
    final heightDelta =
        latestGrowth?.heightCm != null && previousGrowth?.heightCm != null
            ? latestGrowth!.heightCm! - previousGrowth!.heightCm!
            : null;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _GrowthHero(
            ageLabel: _ageLabel(widget.profile.birthDate),
            measurementsCount: _growthEntries.length,
            milestoneCount: _milestones.length,
            onLogGrowth: _openGrowthEditor,
            onAddMilestone: _openMilestoneEditor,
          ),
          const SizedBox(height: 18),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _SectionTitle(
              title: 'Current Snapshot',
              subtitle: 'Latest progress',
            ),
            const SizedBox(height: 12),
            HomeStyleResponsiveGrid(
              mainAxisExtent: 176,
              children: [
                _SnapshotCard(
                  title: 'Weight',
                  value:
                      latestGrowth?.weightKg == null
                          ? 'Not logged'
                          : '${latestGrowth!.weightKg!.toStringAsFixed(2)} kg',
                  subtitle:
                      weightDelta == null
                          ? 'Need 2 entries'
                          : '${weightDelta >= 0 ? '+' : ''}${weightDelta.toStringAsFixed(2)} kg',
                  icon: Icons.monitor_weight_rounded,
                  tint: const Color(0xFFFFD4D4),
                ),
                _SnapshotCard(
                  title: 'Height',
                  value:
                      latestGrowth?.heightCm == null
                          ? 'Not logged'
                          : '${latestGrowth!.heightCm!.toStringAsFixed(1)} cm',
                  subtitle:
                      heightDelta == null
                          ? 'Need 2 entries'
                          : '${heightDelta >= 0 ? '+' : ''}${heightDelta.toStringAsFixed(1)} cm',
                  icon: Icons.height_rounded,
                  tint: const Color(0xFFD9ECFF),
                ),
                _SnapshotCard(
                  title: 'Head Circ.',
                  value:
                      latestGrowth?.headCircumferenceCm == null
                          ? 'Not logged'
                          : '${latestGrowth!.headCircumferenceCm!.toStringAsFixed(1)} cm',
                  subtitle:
                      latestGrowth == null
                          ? 'No entry'
                          : 'Updated ${DateFormat('MMM d').format(latestGrowth.recordedAt)}',
                  icon: Icons.circle_outlined,
                  tint: const Color(0xFFDDF5E8),
                ),
                _SnapshotCard(
                  title: 'Newest milestone',
                  value:
                      _milestones.isEmpty
                          ? 'None yet'
                          : _milestones.first.title,
                  subtitle:
                      _milestones.isEmpty
                          ? 'No milestone'
                          : _milestones.first.category,
                  icon: Icons.emoji_events_rounded,
                  tint: const Color(0xFFFDE7C8),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _SectionTitle(
              title: 'Growth Timeline',
              subtitle: 'Latest first',
              actionLabel: _growthEntries.isEmpty ? null : 'Log new',
              onAction: _growthEntries.isEmpty ? null : _openGrowthEditor,
            ),
            const SizedBox(height: 12),
            if (_growthEntries.isEmpty)
              const _IllustratedEmptyState(
                icon: Icons.straighten_rounded,
                title: 'No growth check-ins yet',
                description: 'Add a first measurement.',
              )
            else
              ..._growthEntries.asMap().entries.map(
                (entry) => _GrowthTimelineCard(
                  entry: entry.value,
                  isLatest: entry.key == 0,
                  onDelete: () => _deleteGrowth(entry.value),
                ),
              ),
            const SizedBox(height: 22),
            _SectionTitle(
              title: 'Milestone Moments',
              subtitle: 'Captured moments',
              actionLabel: _milestones.isEmpty ? null : 'Add new',
              onAction: _milestones.isEmpty ? null : _openMilestoneEditor,
            ),
            const SizedBox(height: 12),
            if (_milestones.isEmpty)
              const _IllustratedEmptyState(
                icon: Icons.flag_rounded,
                title: 'No milestones yet',
                description: 'Add a first milestone.',
              )
            else
              HomeStyleResponsiveGrid(
                mainAxisExtent: 190,
                children:
                    _milestones
                        .map(
                          (milestone) => _MilestoneCard(
                            milestone: milestone,
                            onDelete: () => _deleteMilestone(milestone),
                          ),
                        )
                        .toList(),
              ),
          ],
        ],
      ),
    );
  }

  String _ageLabel(DateTime? birthDate) {
    if (birthDate == null) {
      return 'Birth date not set';
    }
    final days = DateTime.now().difference(birthDate).inDays;
    final weeks = days ~/ 7;
    final remainingDays = days % 7;
    if (weeks > 0) {
      return '$weeks weeks, $remainingDays days';
    }
    return '$days days';
  }
}

class _GrowthHero extends StatelessWidget {
  const _GrowthHero({
    required this.ageLabel,
    required this.measurementsCount,
    required this.milestoneCount,
    required this.onLogGrowth,
    required this.onAddMilestone,
  });

  final String ageLabel;
  final int measurementsCount;
  final int milestoneCount;
  final VoidCallback onLogGrowth;
  final VoidCallback onAddMilestone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF2E5), Color(0xFFE3F1FF), Color(0xFFE7F8EF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8DBEF3).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.insights_rounded, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Growth & Development',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A calm place to follow progress, patterns, and proud moments.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wideLayout = constraints.maxWidth >= 760;
              final chips = [
                _HeroChip(icon: Icons.cake_rounded, label: ageLabel),
                _HeroChip(
                  icon: Icons.straighten_rounded,
                  label: '$measurementsCount measurements',
                ),
                _HeroChip(
                  icon: Icons.emoji_events_rounded,
                  label: '$milestoneCount milestones',
                ),
              ];

              if (wideLayout) {
                return Row(
                  children: [
                    for (var index = 0; index < chips.length; index++) ...[
                      Expanded(child: chips[index]),
                      if (index != chips.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                );
              }

              return Column(
                children: [
                  for (var index = 0; index < chips.length; index++) ...[
                    SizedBox(width: double.infinity, child: chips[index]),
                    if (index != chips.length - 1) const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final wideLayout = constraints.maxWidth >= 560;
              if (wideLayout) {
                return Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onLogGrowth,
                        icon: const Icon(Icons.add_chart_rounded),
                        label: const Text('Log Growth'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onAddMilestone,
                        icon: const Icon(Icons.flag_rounded),
                        label: const Text('Add Milestone'),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onLogGrowth,
                      icon: const Icon(Icons.add_chart_rounded),
                      label: const Text('Log Growth'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onAddMilestone,
                      icon: const Icon(Icons.flag_rounded),
                      label: const Text('Add Milestone'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return HomeStyleSectionHeader(
      title: title,
      subtitle: subtitle,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return HomeStyleInfoCard(
      title: title,
      value: value,
      subtitle: subtitle,
      icon: icon,
      gradientColors: [tint.withValues(alpha: 0.72), Colors.white],
      iconColor: const Color(0xFF2563EB),
      labelColor: const Color(0xFF374151),
      valueColor: const Color(0xFF111827),
      subtitleColor: const Color(0xFF6B7280),
    );
  }
}

class _GrowthTimelineCard extends StatelessWidget {
  const _GrowthTimelineCard({
    required this.entry,
    required this.isLatest,
    required this.onDelete,
  });

  final GrowthEntry entry;
  final bool isLatest;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('growth-${entry.id}'),
      direction: DismissDirection.endToStart,
      background: _dismissBackground(),
      onDismissed: (_) => onDelete(),
      child: HomeStyleSurfaceCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('MMMM d, y').format(entry.recordedAt),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (isLatest)
                  const HomeStylePill(
                    label: 'Latest',
                    icon: Icons.auto_awesome_rounded,
                    backgroundColor: Color(0xFFDDF5E8),
                  ),
                IconButton(
                  tooltip: 'Delete growth entry',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (entry.weightKg != null)
                  _MetricPill(
                    label: 'Weight',
                    value: '${entry.weightKg!.toStringAsFixed(2)} kg',
                  ),
                if (entry.heightCm != null)
                  _MetricPill(
                    label: 'Height',
                    value: '${entry.heightCm!.toStringAsFixed(1)} cm',
                  ),
                if (entry.headCircumferenceCm != null)
                  _MetricPill(
                    label: 'Head Circ.',
                    value:
                        '${entry.headCircumferenceCm!.toStringAsFixed(1)} cm',
                  ),
              ],
            ),
            if ((entry.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(entry.notes!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.milestone, required this.onDelete});

  final MilestoneEntry milestone;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('milestone-${milestone.id}'),
      direction: DismissDirection.endToStart,
      background: _dismissBackground(),
      onDismissed: (_) => onDelete(),
      child: HomeStyleSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: HomeStylePill(
                    label: milestone.category,
                    icon: Icons.flag_rounded,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                  ),
                ),
                IconButton(
                  tooltip: 'Delete milestone',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              milestone.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM d, y').format(milestone.achievedAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if ((milestone.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                milestone.notes!,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IllustratedEmptyState extends StatelessWidget {
  const _IllustratedEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return HomeStyleEmptyState(
      icon: icon,
      title: title,
      description: description,
    );
  }
}

Widget _dismissBackground() {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.red.shade300,
      borderRadius: BorderRadius.circular(24),
    ),
    child: const Icon(Icons.delete_rounded, color: Colors.white),
  );
}

class _GrowthBottomSheet extends StatefulWidget {
  const _GrowthBottomSheet();

  @override
  State<_GrowthBottomSheet> createState() => _GrowthBottomSheetState();
}

class _GrowthBottomSheetState extends State<_GrowthBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _headController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _recordedAt = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _headController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now(),
      initialDate: _recordedAt,
    );
    if (picked != null) {
      setState(() {
        _recordedAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _recordedAt.hour,
          _recordedAt.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    final weight = _parseDouble(_weightController.text);
    final height = _parseDouble(_heightController.text);
    final head = _parseDouble(_headController.text);
    if (weight == null && height == null && head == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one measurement')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await DatabaseHelper.instance.insertGrowthEntry(
        GrowthEntry(
          recordedAt: _recordedAt,
          weightKg: weight,
          heightCm: height,
          headCircumferenceCm: head,
          notes:
              _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() {
        _isSaving = false;
      });
    }
  }

  double? _parseDouble(String value) {
    if (value.trim().isEmpty) {
      return null;
    }
    return double.tryParse(value.trim());
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Log growth entry',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(DateFormat('MMMM d, y').format(_recordedAt)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _headController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Head circumference (cm)',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon:
                        _isSaving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Save growth entry'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MilestoneBottomSheet extends StatefulWidget {
  const _MilestoneBottomSheet();

  @override
  State<_MilestoneBottomSheet> createState() => _MilestoneBottomSheetState();
}

class _MilestoneBottomSheetState extends State<_MilestoneBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _achievedAt = DateTime.now();
  String _category = 'Motor';
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      lastDate: DateTime.now(),
      initialDate: _achievedAt,
    );
    if (picked != null) {
      setState(() {
        _achievedAt = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await DatabaseHelper.instance.insertMilestone(
        MilestoneEntry(
          title: _titleController.text.trim(),
          category: _category,
          achievedAt: _achievedAt,
          notes:
              _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Add milestone',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Milestone title',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a milestone title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items:
                      const [
                            'Motor',
                            'Language',
                            'Social',
                            'Sleep',
                            'Feeding',
                            'Health',
                            'Memory',
                          ]
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _category = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_rounded),
                  label: Text(DateFormat('MMMM d, y').format(_achievedAt)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon:
                        _isSaving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Save milestone'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
