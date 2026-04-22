import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/baby_profile.dart';
import '../widgets/home_style.dart';
import '../models/event.dart';
import '../widgets/stats_chart.dart';

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
  bool _isLoading = true;
  late _StatsData _stats;

  @override
  void initState() {
    super.initState();
    _stats = _StatsData.empty();
    _loadStats();
  }

  @override
  void didUpdateWidget(covariant StatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick ||
        oldWidget.profile != widget.profile) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));
      final sevenDaysAgo = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));

      final recentEvents = await DatabaseHelper.instance.getEventsBetween(
        last24Hours,
        now.add(const Duration(minutes: 1)),
      );
      final weekEvents = await DatabaseHelper.instance.getEventsBetween(
        sevenDaysAgo,
        now.add(const Duration(days: 1)),
      );
      final allEvents = await DatabaseHelper.instance.getAllEvents();
      final lowStockItems = await DatabaseHelper.instance.getLowStockItems();

      if (!mounted) {
        return;
      }
      setState(() {
        _stats = _StatsData.fromEvents(
          recentEvents: recentEvents,
          weekEvents: weekEvents,
          allEvents: allEvents,
          lowStockCount: lowStockItems.length,
        );
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          HomeStylePageHeader(
            eyebrow: 'Daily Insights',
            title: 'Statistics',
            subtitle: 'Care trends',
            icon: Icons.bar_chart_rounded,
            badge: _ageLabel(widget.profile.birthDate),
            gradient: const [
              Color(0xFFEAF6FF),
              Color(0xFFFFF4E8),
              Color(0xFFF8EEFF),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            HomeStyleResponsiveGrid(
              mainAxisExtent: 176,
              children: [
                _StatCard(
                  title: 'Feedings',
                  value: '${_stats.totalFeedings}',
                  subtitle: 'Last 24 hours',
                  icon: Icons.restaurant_rounded,
                  gradientColors: const [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
                  iconColor: const Color(0xFFE11D48),
                  labelColor: const Color(0xFFBE123C),
                  valueColor: const Color(0xFF881337),
                  subtitleColor: const Color(0xFFFB7185),
                ),
                _StatCard(
                  title: 'Diapers',
                  value: '${_stats.totalDiapers}',
                  subtitle:
                      '${_stats.wetCount} wet • ${_stats.dirtyCount} dirty • ${_stats.bothCount} both',
                  icon: Icons.baby_changing_station_rounded,
                  gradientColors: const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                  iconColor: const Color(0xFF2563EB),
                  labelColor: const Color(0xFF1D4ED8),
                  valueColor: const Color(0xFF1E3A8A),
                  subtitleColor: const Color(0xFF60A5FA),
                ),
                _StatCard(
                  title: 'Sleep',
                  value: _stats.sleepHoursLabel,
                  subtitle: 'Last 24 hours total',
                  icon: Icons.bedtime_rounded,
                  gradientColors: const [Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
                  iconColor: const Color(0xFFA855F7),
                  labelColor: const Color(0xFF7E22CE),
                  valueColor: const Color(0xFF4C1D95),
                  subtitleColor: const Color(0xFFC084FC),
                ),
                _StatCard(
                  title: 'Medicine',
                  value: _stats.lastMedicineLabel,
                  subtitle: 'Most recent dose',
                  icon: Icons.medication_rounded,
                  gradientColors: const [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                  iconColor: const Color(0xFF10B981),
                  labelColor: const Color(0xFF047857),
                  valueColor: const Color(0xFF065F46),
                  subtitleColor: const Color(0xFF34D399),
                ),
              ],
            ),
            const SizedBox(height: 20),
            HomeStyleSectionHeader(
              title: 'Activity Trend',
              subtitle: 'Last 7 days',
            ),
            const SizedBox(height: 12),
            HomeStyleSurfaceCard(
              padding: const EdgeInsets.all(20),
              child: StatsChart(data: _stats.dailyEventCounts),
            ),
            const SizedBox(height: 16),
            const HomeStyleSectionHeader(
              title: 'Highlights',
              subtitle: 'Key averages',
            ),
            const SizedBox(height: 12),
            HomeStyleResponsiveGrid(
              mainAxisExtent: 176,
              children: [
                _HighlightCard(
                  title: 'Average sleep',
                  value: _stats.averageSleepLabel,
                  subtitle: '7-day average',
                  icon: Icons.bedtime_rounded,
                ),
                _HighlightCard(
                  title: 'Average feeds/day',
                  value: _stats.averageFeedsLabel,
                  subtitle: '7-day average',
                  icon: Icons.restaurant_rounded,
                ),
                _HighlightCard(
                  title: 'Longest sleep',
                  value: _stats.longestSleepLabel,
                  subtitle: 'Best stretch',
                  icon: Icons.hotel_rounded,
                ),
                _HighlightCard(
                  title: 'Care streak',
                  value: _stats.trackingStreakLabel,
                  subtitle: 'Active streak',
                  icon: Icons.local_fire_department_rounded,
                  alert: _stats.currentStreak == 0,
                ),
                _HighlightCard(
                  title: 'Inventory alerts',
                  value: '${_stats.lowStockCount}',
                  subtitle: 'Low stock',
                  icon: Icons.inventory_2_rounded,
                  alert: _stats.lowStockCount > 0,
                ),
                _HighlightCard(
                  title: 'Baby age',
                  value: _ageLabel(widget.profile.birthDate),
                  subtitle: 'Profile age',
                  icon: Icons.child_friendly_rounded,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _ageLabel(DateTime? birthDate) {
    if (birthDate == null) {
      return 'Not set';
    }
    final days = DateTime.now().difference(birthDate).inDays;
    final weeks = days ~/ 7;
    final remainingDays = days % 7;
    if (weeks > 0) {
      return '$weeks w, $remainingDays d';
    }
    return '$days d';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.iconColor,
    required this.labelColor,
    required this.valueColor,
    required this.subtitleColor,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final Color iconColor;
  final Color labelColor;
  final Color valueColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return HomeStyleInfoCard(
      title: title,
      value: value,
      subtitle: subtitle,
      icon: icon,
      gradientColors: gradientColors,
      iconColor: iconColor,
      labelColor: labelColor,
      valueColor: valueColor,
      subtitleColor: subtitleColor,
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.alert = false,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return HomeStyleInfoCard(
      title: title,
      value: value,
      subtitle: subtitle,
      icon: icon,
      gradientColors:
          alert
              ? const [Color(0xFFFFF7ED), Color(0xFFFFEDD5)]
              : const [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
      iconColor: alert ? const Color(0xFFF97316) : const Color(0xFF8B5CF6),
      labelColor: alert ? const Color(0xFF9A3412) : const Color(0xFF6D28D9),
      valueColor: alert ? const Color(0xFF7C2D12) : const Color(0xFF4C1D95),
      subtitleColor: alert ? const Color(0xFFEA580C) : const Color(0xFF8B5CF6),
    );
  }
}

class _StatsData {
  const _StatsData({
    required this.totalFeedings,
    required this.totalDiapers,
    required this.wetCount,
    required this.dirtyCount,
    required this.bothCount,
    required this.totalSleepMinutes,
    required this.lastMedicine,
    required this.dailyEventCounts,
    required this.averageSleepMinutes,
    required this.averageFeedsPerDay,
    required this.longestSleepMinutes,
    required this.currentStreak,
    required this.lowStockCount,
  });

  final int totalFeedings;
  final int totalDiapers;
  final int wetCount;
  final int dirtyCount;
  final int bothCount;
  final int totalSleepMinutes;
  final BabyEvent? lastMedicine;
  final List<DailyCount> dailyEventCounts;
  final double averageSleepMinutes;
  final double averageFeedsPerDay;
  final int longestSleepMinutes;
  final int currentStreak;
  final int lowStockCount;

  factory _StatsData.empty() {
    return const _StatsData(
      totalFeedings: 0,
      totalDiapers: 0,
      wetCount: 0,
      dirtyCount: 0,
      bothCount: 0,
      totalSleepMinutes: 0,
      lastMedicine: null,
      dailyEventCounts: [],
      averageSleepMinutes: 0,
      averageFeedsPerDay: 0,
      longestSleepMinutes: 0,
      currentStreak: 0,
      lowStockCount: 0,
    );
  }

  factory _StatsData.fromEvents({
    required List<BabyEvent> recentEvents,
    required List<BabyEvent> weekEvents,
    required List<BabyEvent> allEvents,
    required int lowStockCount,
  }) {
    final totalFeedings =
        recentEvents.where((event) => event.type == EventType.feeding).length;
    final diaperEvents =
        recentEvents.where((event) => event.type == EventType.diaper).toList();
    final totalSleepMinutes = recentEvents
        .where((event) => event.type == EventType.sleep)
        .fold<int>(0, (sum, event) => sum + (event.sleepDuration ?? 0));

    final now = DateTime.now();
    final startDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));

    final dailyCounts = List<DailyCount>.generate(7, (index) {
      final date = startDate.add(Duration(days: index));
      final count =
          weekEvents.where((event) {
            final eventDate = DateTime(
              event.timestamp.year,
              event.timestamp.month,
              event.timestamp.day,
            );
            return eventDate == date;
          }).length;
      return DailyCount(
        label: DateFormat.E().format(date),
        value: count.toDouble(),
      );
    });

    final sleepByDay = List<int>.generate(7, (index) {
      final date = startDate.add(Duration(days: index));
      return weekEvents
          .where((event) {
            if (event.type != EventType.sleep) {
              return false;
            }
            final eventDate = DateTime(
              event.timestamp.year,
              event.timestamp.month,
              event.timestamp.day,
            );
            return eventDate == date;
          })
          .fold<int>(0, (sum, event) => sum + (event.sleepDuration ?? 0));
    });

    final feedByDay = List<int>.generate(7, (index) {
      final date = startDate.add(Duration(days: index));
      return weekEvents.where((event) {
        final eventDate = DateTime(
          event.timestamp.year,
          event.timestamp.month,
          event.timestamp.day,
        );
        return eventDate == date && event.type == EventType.feeding;
      }).length;
    });

    final medicineEvents =
        allEvents.where((event) => event.type == EventType.medicine).toList();
    final sleepEvents =
        allEvents.where((event) => event.type == EventType.sleep).toList();

    return _StatsData(
      totalFeedings: totalFeedings,
      totalDiapers: diaperEvents.length,
      wetCount: diaperEvents.where((event) => event.diaperType == 'Wet').length,
      dirtyCount:
          diaperEvents.where((event) => event.diaperType == 'Dirty').length,
      bothCount:
          diaperEvents.where((event) => event.diaperType == 'Both').length,
      totalSleepMinutes: totalSleepMinutes,
      lastMedicine: medicineEvents.isEmpty ? null : medicineEvents.first,
      dailyEventCounts: dailyCounts,
      averageSleepMinutes:
          sleepByDay.fold<int>(0, (sum, minutes) => sum + minutes) / 7,
      averageFeedsPerDay:
          feedByDay.fold<int>(0, (sum, count) => sum + count) / 7,
      longestSleepMinutes: sleepEvents.fold<int>(
        0,
        (max, event) =>
            (event.sleepDuration ?? 0) > max ? (event.sleepDuration ?? 0) : max,
      ),
      currentStreak: _calculateStreak(allEvents),
      lowStockCount: lowStockCount,
    );
  }

  String get sleepHoursLabel =>
      '${(totalSleepMinutes / 60).toStringAsFixed(1)} hrs';

  String get averageSleepLabel =>
      '${(averageSleepMinutes / 60).toStringAsFixed(1)} hrs/day';

  String get averageFeedsLabel => averageFeedsPerDay.toStringAsFixed(1);

  String get longestSleepLabel =>
      longestSleepMinutes == 0
          ? 'None yet'
          : '${(longestSleepMinutes / 60).toStringAsFixed(1)} hrs';

  String get trackingStreakLabel =>
      currentStreak == 0 ? 'Start today' : '$currentStreak days';

  String get lastMedicineLabel {
    if (lastMedicine == null) {
      return 'No dose yet';
    }
    final time = DateFormat('MMM d, h:mm a').format(lastMedicine!.timestamp);
    final dose = [
      if ((lastMedicine!.medicineDose ?? '').isNotEmpty)
        lastMedicine!.medicineDose,
      if ((lastMedicine!.medicineUnit ?? '').isNotEmpty)
        lastMedicine!.medicineUnit,
    ].join(' ');

    String result = dose.isEmpty ? time : '$time $dose';
    if (result.length > 25) {
      result = result.substring(0, 22) + '...';
    }
    return result;
  }

  static int _calculateStreak(List<BabyEvent> allEvents) {
    if (allEvents.isEmpty) {
      return 0;
    }
    final uniqueDates =
        allEvents
            .map(
              (event) => DateTime(
                event.timestamp.year,
                event.timestamp.month,
                event.timestamp.day,
              ),
            )
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    var streak = 0;
    for (final date in uniqueDates) {
      if (date == cursor) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else if (date.isAfter(cursor)) {
        continue;
      } else {
        break;
      }
    }
    return streak;
  }
}
