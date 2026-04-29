import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/baby_profile.dart';
import '../widgets/home_style.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({
    super.key,
    required this.refreshTick,
    required this.profile,
  });

  final int refreshTick;
  final BabyProfile profile;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  List<GrowthEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void didUpdateWidget(covariant StatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _loadEntries();
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final entries = await DatabaseHelper.instance.getGrowthEntries();
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
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

  Future<void> _saveGrowth() async {
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    if (height == null && weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter height or weight first')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      await DatabaseHelper.instance.insertGrowthEntry(
        GrowthEntry(
          recordedAt: DateTime.now(),
          heightCm: height,
          weightKg: weight,
        ),
      );
      _heightController.clear();
      _weightController.clear();
      await _loadEntries();
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

  Future<void> _deleteEntry(GrowthEntry entry) async {
    final id = entry.id;
    if (id == null) {
      return;
    }
    try {
      await DatabaseHelper.instance.deleteGrowthEntry(id);
      await _loadEntries();
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
    final currentMonth = _ageInMonths(widget.profile.birthDate);
    final latest = _entries.isEmpty ? null : _entries.first;

    return RefreshIndicator(
      onRefresh: _loadEntries,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          HomeStylePageHeader(
            eyebrow: 'Growth Stats',
            title: 'Height & Weight',
            subtitle: 'Save monthly measurements',
            icon: Icons.show_chart_rounded,
            badge:
                widget.profile.birthDate == null
                    ? 'Age not set'
                    : 'Month ${currentMonth.clamp(1, 12)}',
            gradient: const [
              Color(0xFFEAF6FF),
              Color(0xFFE7F8EF),
              Color(0xFFFFF4E8),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _LatestMetricCard(
                  title: 'Latest height',
                  value:
                      latest?.heightCm == null
                          ? 'No entry'
                          : '${latest!.heightCm!.toStringAsFixed(1)} cm',
                  subtitle:
                      latest == null
                          ? 'Add a measurement'
                          : DateFormat('MMM d, y').format(latest.recordedAt),
                  icon: Icons.height_rounded,
                  backgroundColor: const Color(0xFFEAF6FF),
                  iconColor: const Color(0xFF2563EB),
                  labelColor: const Color(0xFF1D4ED8),
                  valueColor: const Color(0xFF1E3A8A),
                ),
                _LatestMetricCard(
                  title: 'Latest weight',
                  value:
                      latest?.weightKg == null
                          ? 'No entry'
                          : '${latest!.weightKg!.toStringAsFixed(2)} kg',
                  subtitle:
                      latest == null
                          ? 'Add a measurement'
                          : DateFormat('MMM d, y').format(latest.recordedAt),
                  icon: Icons.monitor_weight_rounded,
                  backgroundColor: const Color(0xFFFFF4E8),
                  iconColor: const Color(0xFFF97316),
                  labelColor: const Color(0xFFEA580C),
                  valueColor: const Color(0xFF9A3412),
                ),
              ];

              if (constraints.maxWidth < 640) {
                return Column(
                  children: [
                    for (var index = 0; index < cards.length; index++) ...[
                      SizedBox(width: double.infinity, child: cards[index]),
                      if (index != cards.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 14),
                  Expanded(child: cards[1]),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          HomeStyleSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Measurement',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final fields = [
                      TextField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Height',
                          suffixText: 'cm',
                          prefixIcon: Icon(Icons.height_rounded),
                        ),
                      ),
                      TextField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Weight',
                          suffixText: 'kg',
                          prefixIcon: Icon(Icons.monitor_weight_rounded),
                        ),
                      ),
                    ];

                    if (constraints.maxWidth < 520) {
                      return Column(
                        children: [
                          fields[0],
                          const SizedBox(height: 12),
                          fields[1],
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: fields[0]),
                        const SizedBox(width: 12),
                        Expanded(child: fields[1]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveGrowth,
                    icon:
                        _isSaving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.save_rounded),
                    label: Text(_isSaving ? 'Saving...' : 'Save measurement'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          HomeStyleSectionHeader(
            title: 'Saved Measurements',
            subtitle: _entries.isEmpty ? 'No entries yet' : 'Latest first',
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_entries.isEmpty)
            const HomeStyleEmptyState(
              icon: Icons.straighten_rounded,
              title: 'No measurements yet',
              description: 'Add height or weight to start the growth history.',
            )
          else
            for (final entry in _entries)
              _GrowthEntryCard(
                entry: entry,
                onDelete: () => _deleteEntry(entry),
              ),
          const SizedBox(height: 20),
          HomeStyleSectionHeader(
            title: 'Reference Bands',
            subtitle: 'Broad P15-P85 guide by month',
          ),
          const SizedBox(height: 12),
          HomeStyleSurfaceCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Use these as broad reference bands. Your pediatrician should interpret your baby\'s actual curve.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                for (final row in _growthRows)
                  _GrowthPercentileRow(
                    row: row,
                    isCurrentMonth:
                        widget.profile.birthDate != null &&
                        row.month == currentMonth.clamp(1, 12),
                  ),
              ],
            ),
          ),
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
}

class _LatestMetricCard extends StatelessWidget {
  const _LatestMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.labelColor,
    required this.valueColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final Color labelColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      constraints: const BoxConstraints(minHeight: 112),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowthEntryCard extends StatelessWidget {
  const _GrowthEntryCard({required this.entry, required this.onDelete});

  final GrowthEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return HomeStyleSurfaceCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMMM d, y').format(entry.recordedAt),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (entry.heightCm != null)
                      _MetricChip(
                        label: 'Height',
                        value: '${entry.heightCm!.toStringAsFixed(1)} cm',
                      ),
                    if (entry.weightKg != null)
                      _MetricChip(
                        label: 'Weight',
                        value: '${entry.weightKg!.toStringAsFixed(2)} kg',
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete measurement',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _GrowthPercentileRow extends StatelessWidget {
  const _GrowthPercentileRow({required this.row, required this.isCurrentMonth});

  final _GrowthRow row;
  final bool isCurrentMonth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            isCurrentMonth
                ? scheme.primaryContainer.withValues(alpha: 0.55)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isCurrentMonth
                  ? scheme.primary.withValues(alpha: 0.35)
                  : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Month ${row.month}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isCurrentMonth)
                const HomeStylePill(
                  label: 'Current',
                  icon: Icons.today_rounded,
                  backgroundColor: Colors.white,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricChip(label: 'Weight P15-P85', value: row.weightRange),
              _MetricChip(label: 'Height P15-P85', value: row.heightRange),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _GrowthRow {
  const _GrowthRow({
    required this.month,
    required this.weightRange,
    required this.heightRange,
  });

  final int month;
  final String weightRange;
  final String heightRange;
}

const _growthRows = [
  _GrowthRow(month: 1, weightRange: '3.6-5.7 kg', heightRange: '51-58 cm'),
  _GrowthRow(month: 2, weightRange: '4.4-6.8 kg', heightRange: '54-61 cm'),
  _GrowthRow(month: 3, weightRange: '5.1-7.7 kg', heightRange: '57-64 cm'),
  _GrowthRow(month: 4, weightRange: '5.6-8.4 kg', heightRange: '60-67 cm'),
  _GrowthRow(month: 5, weightRange: '6.1-9.0 kg', heightRange: '62-69 cm'),
  _GrowthRow(month: 6, weightRange: '6.4-9.5 kg', heightRange: '64-71 cm'),
  _GrowthRow(month: 7, weightRange: '6.7-10.0 kg', heightRange: '65-73 cm'),
  _GrowthRow(month: 8, weightRange: '7.0-10.4 kg', heightRange: '67-74 cm'),
  _GrowthRow(month: 9, weightRange: '7.2-10.8 kg', heightRange: '68-76 cm'),
  _GrowthRow(month: 10, weightRange: '7.5-11.1 kg', heightRange: '69-77 cm'),
  _GrowthRow(month: 11, weightRange: '7.7-11.5 kg', heightRange: '71-79 cm'),
  _GrowthRow(month: 12, weightRange: '7.9-11.8 kg', heightRange: '72-80 cm'),
];
