import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/baby_profile.dart';
import '../models/event.dart';
import '../models/reminder.dart';
import '../services/reminder_repository.dart';
import '../widgets/add_event_bottom_sheet.dart';
import '../widgets/event_timeline_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.refreshTick,
    required this.babyName,
    required this.profile,
    required this.onChanged,
  });

  final int refreshTick;
  final String babyName;
  final BabyProfile profile;
  final Future<void> Function() onChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  List<BabyEvent> _todayEvents = const [];
  List<ReminderItem> _reminders = const [];
  List<InventoryItem> _lowStockItems = const [];
  _HomeInsights _insights = _HomeInsights.empty();
  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadData();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
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
      final events = await DatabaseHelper.instance.getTodayEvents();
      final lastFeeding = await DatabaseHelper.instance.getLatestEventByType(
        EventType.feeding,
      );
      final lastSleep = await DatabaseHelper.instance.getLatestEventByType(
        EventType.sleep,
      );
      final lowStockItems = await DatabaseHelper.instance.getLowStockItems();
      final reminders = await ReminderRepository.instance.loadReminders();

      if (!mounted) return;

      setState(() {
        _todayEvents = events;
        _lowStockItems = lowStockItems;
        _reminders = _sortReminders(reminders);
        _insights = _HomeInsights(
          lastFeeding: lastFeeding,
          lastSleep: lastSleep,
          lowStockCount: lowStockItems.length,
          activeReminderCount: reminders.length,
        );
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(error);
    }
  }

  Future<void> _openAddEventSheet(EventType initialType) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddEventBottomSheet(initialType: initialType),
    );
    if (created == true) {
      await _loadData();
      await widget.onChanged();
    }
  }

  Future<void> _openEditEventSheet(BabyEvent event) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => AddEventBottomSheet(initialType: event.type, event: event),
    );
    if (changed == true) {
      await _loadData();
      await widget.onChanged();
    }
  }

  Future<void> _deleteEvent(BabyEvent event) async {
    if (event.id == null) return;
    try {
      await DatabaseHelper.instance.deleteEvent(event.id!);
      await _loadData();
      await widget.onChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event deleted')));
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _saveReminder(ReminderItem reminder) async {
    final updated = [..._reminders];
    final index = updated.indexWhere((item) => item.id == reminder.id);
    if (index >= 0) {
      updated[index] = reminder;
    } else {
      updated.add(reminder);
    }

    final sorted = _sortReminders(updated);
    await ReminderRepository.instance.saveReminders(sorted);
    if (!mounted) return;

    setState(() {
      _reminders = sorted;
      _insights = _insights.copyWith(activeReminderCount: sorted.length);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(index >= 0 ? 'Reminder updated' : 'Reminder added'),
      ),
    );
  }

  Future<void> _deleteReminder(ReminderItem reminder) async {
    final updated = _reminders.where((item) => item.id != reminder.id).toList();
    await ReminderRepository.instance.saveReminders(updated);
    if (!mounted) return;

    setState(() {
      _reminders = updated;
      _insights = _insights.copyWith(activeReminderCount: updated.length);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reminder deleted')));
  }

  Future<void> _openReminderEditor({
    required DateTime date,
    ReminderItem? reminder,
  }) async {
    final result = await showModalBottomSheet<_ReminderEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (_) => _ReminderEditorSheet(initialDate: date, reminder: reminder),
    );

    if (result == null) {
      return;
    }

    if (result.deleted && reminder != null) {
      await _deleteReminder(reminder);
      return;
    }

    if (result.reminder != null) {
      await _saveReminder(result.reminder!);
    }
  }

  List<ReminderItem> _sortReminders(List<ReminderItem> reminders) {
    final now = DateTime.now();
    final sorted = [...reminders];
    sorted.sort(
      (a, b) => a.nextOccurrenceFrom(now).compareTo(b.nextOccurrenceFrom(now)),
    );
    return sorted;
  }

  List<ReminderItem> _remindersForDay(DateTime day) {
    final items = _reminders.where((reminder) => reminder.occursOnDay(day));
    return items.toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<_ScheduledReminder> _upcomingAppointments() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final upcoming =
        _reminders
            .map(
              (reminder) => _ScheduledReminder(
                reminder: reminder,
                occurrence: reminder.nextOccurrenceFrom(startOfToday),
              ),
            )
            .where(
              (entry) =>
                  !DateTime(
                    entry.occurrence.year,
                    entry.occurrence.month,
                    entry.occurrence.day,
                  ).isBefore(startOfToday),
            )
            .toList();

    upcoming.sort((a, b) => a.occurrence.compareTo(b.occurrence));
    return upcoming.take(5).toList();
  }

  List<ReminderItem> _dueTodayReminders() {
    final today = DateTime.now();
    return _remindersForDay(today);
  }

  String _getTimeAgo(DateTime? timestamp) {
    if (timestamp == null) return '';
    final difference = DateTime.now().difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final dueToday = _dueTodayReminders();
    final upcomingAppointments = _upcomingAppointments();
    final greetingName =
        widget.babyName.trim().isEmpty ? 'your baby' : widget.babyName.trim();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FigmaWelcomeHeader(
            babyName: greetingName,
            date: DateTime.now(),
            profile: widget.profile,
          ),
          const SizedBox(height: 16),
          _FigmaQuickStatsGrid(
            lastFeeding: _insights.lastFeeding,
            lastSleep: _insights.lastSleep,
            getTimeAgo: _getTimeAgo,
          ),
          const SizedBox(height: 16),
          if (_lowStockItems.isNotEmpty) ...[
            _FigmaLowStockAlert(items: _lowStockItems),
            const SizedBox(height: 16),
          ],
          if (dueToday.isNotEmpty) ...[
            _FigmaTodaysReminders(reminders: dueToday),
            const SizedBox(height: 16),
          ],
          _FigmaQuickActionsGrid(onActionTap: _openAddEventSheet),
          const SizedBox(height: 16),
          _FigmaUpcomingAppointments(
            appointments: upcomingAppointments,
            selectedDate: _selectedDate,
            focusedMonth: _focusedMonth,
            reminders: _reminders,
            onMonthChanged: (month) {
              setState(() => _focusedMonth = DateTime(month.year, month.month));
            },
            onDateSelected: (day) {
              setState(() {
                _selectedDate = DateTime(day.year, day.month, day.day);
                _focusedMonth = DateTime(day.year, day.month);
              });
            },
            onAddReminder: () => _openReminderEditor(date: _selectedDate),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                "Today's timeline",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (_todayEvents.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_todayEvents.length} events',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_todayEvents.isEmpty)
            _FigmaEmptyTimeline(
              onAddEvent: () => _openAddEventSheet(EventType.feeding),
            )
          else
            ..._todayEvents.map(
              (event) => EventTimelineItem(
                event: event,
                onTap: () => _openEditEventSheet(event),
                onDelete: () => _deleteEvent(event),
              ),
            ),
        ],
      ),
    );
  }
}

class _FigmaWelcomeHeader extends StatelessWidget {
  const _FigmaWelcomeHeader({
    required this.babyName,
    required this.date,
    required this.profile,
  });

  final String babyName;
  final DateTime date;
  final BabyProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello! 👋',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (profile.photoBytes != null) ...[
              CircleAvatar(
                radius: 24,
                backgroundImage: MemoryImage(profile.photoBytes!),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                'How\'s $babyName today?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('MMM d').format(date),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FigmaQuickStatsGrid extends StatelessWidget {
  const _FigmaQuickStatsGrid({
    required this.lastFeeding,
    required this.lastSleep,
    required this.getTimeAgo,
  });

  final BabyEvent? lastFeeding;
  final BabyEvent? lastSleep;
  final String Function(DateTime?) getTimeAgo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FigmaStatCard(
            gradientColors: const [Color(0xFFFDF2F8), Color(0xFFFCE7F3)],
            iconColor: const Color(0xFFEC4899),
            icon: Icons.child_care_rounded,
            label: 'Last Feed',
            labelColor: const Color(0xFFBE185D),
            value:
                lastFeeding != null
                    ? DateFormat('h:mm a').format(lastFeeding!.timestamp)
                    : '--:--',
            valueColor: const Color(0xFF831843),
            subtitle:
                lastFeeding != null
                    ? getTimeAgo(lastFeeding!.timestamp)
                    : 'No feeds yet',
            subtitleColor: const Color(0xFFDB2777),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FigmaStatCard(
            gradientColors: const [Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
            iconColor: const Color(0xFFA855F7),
            icon: Icons.bedtime_rounded,
            label: 'Last Sleep',
            labelColor: const Color(0xFF7E22CE),
            value:
                lastSleep != null
                    ? DateFormat('h:mm a').format(lastSleep!.timestamp)
                    : '--:--',
            valueColor: const Color(0xFF4C1D95),
            subtitle:
                lastSleep != null
                    ? getTimeAgo(lastSleep!.timestamp)
                    : 'No sleep logged',
            subtitleColor: const Color(0xFF9333EA),
          ),
        ),
      ],
    );
  }
}

class _FigmaStatCard extends StatelessWidget {
  const _FigmaStatCard({
    required this.gradientColors,
    required this.iconColor,
    required this.icon,
    required this.label,
    required this.labelColor,
    required this.value,
    required this.valueColor,
    required this.subtitle,
    required this.subtitleColor,
  });

  final List<Color> gradientColors;
  final Color iconColor;
  final IconData icon;
  final String label;
  final Color labelColor;
  final String value;
  final Color valueColor;
  final String subtitle;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FigmaLowStockAlert extends StatelessWidget {
  const _FigmaLowStockAlert({required this.items});

  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFED7AA), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Low Stock Alert',
                style: TextStyle(
                  color: Color(0xFF7C2D12),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items
              .take(3)
              .map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          color: Color(0xFF374151),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              item.quantity <= item.lowStockThreshold ~/ 2
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFFFEDD5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${item.quantity} left',
                          style: TextStyle(
                            color:
                                item.quantity <= item.lowStockThreshold ~/ 2
                                    ? const Color(0xFF991B1B)
                                    : const Color(0xFF9A3412),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          if (items.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${items.length - 3} more items low',
                style: TextStyle(
                  color: const Color(0xFF9A3412).withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FigmaTodaysReminders extends StatelessWidget {
  const _FigmaTodaysReminders({required this.reminders});

  final List<ReminderItem> reminders;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Today\'s Reminders',
                style: TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...reminders.map(
            (reminder) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          reminder.type == ReminderType.vaccine
                              ? const Color(0xFF10B981)
                              : const Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.title,
                          style: const TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('h:mm a').format(reminder.dateTime),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FigmaQuickActionsGrid extends StatelessWidget {
  const _FigmaQuickActionsGrid({required this.onActionTap});

  final void Function(EventType) onActionTap;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        type: EventType.feeding,
        icon: Icons.baby_changing_station_rounded,
        label: 'Feeding',
        color: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFEF3C7),
      ),
      _QuickAction(
        type: EventType.diaper,
        icon: Icons.water_drop_rounded,
        label: 'Diaper',
        color: const Color(0xFF06B6D4),
        bgColor: const Color(0xFFCFFAFE),
      ),
      _QuickAction(
        type: EventType.sleep,
        icon: Icons.nightlight_round_rounded,
        label: 'Sleep',
        color: const Color(0xFF8B5CF6),
        bgColor: const Color(0xFFEDE9FE),
      ),
      _QuickAction(
        type: EventType.medicine,
        icon: Icons.medication_liquid_rounded,
        label: 'Medicine',
        color: const Color(0xFFEC4899),
        bgColor: const Color(0xFFFCE7F3),
      ),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.85,
      children:
          actions.map((action) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onActionTap(action.type),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: action.bgColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(action.icon, color: action.color, size: 26),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}

class _QuickAction {
  final EventType type;
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  _QuickAction({
    required this.type,
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });
}

class _FigmaUpcomingAppointments extends StatelessWidget {
  const _FigmaUpcomingAppointments({
    required this.appointments,
    required this.selectedDate,
    required this.focusedMonth,
    required this.reminders,
    required this.onMonthChanged,
    required this.onDateSelected,
    required this.onAddReminder,
  });

  final List<_ScheduledReminder> appointments;
  final DateTime selectedDate;
  final DateTime focusedMonth;
  final List<ReminderItem> reminders;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onAddReminder;

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(focusedMonth);
    final selectedDateLabel = DateFormat(
      'EEE, MMM d, yyyy',
    ).format(selectedDate);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Upcoming Appointments',
                  style: TextStyle(
                    color: Color(0xFF312E81),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: onAddReminder,
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed:
                    () => onMonthChanged(
                      DateTime(focusedMonth.year, focusedMonth.month - 1),
                    ),
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
              ),
              Text(
                monthLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4338CA),
                ),
              ),
              IconButton(
                onPressed:
                    () => onMonthChanged(
                      DateTime(focusedMonth.year, focusedMonth.month + 1),
                    ),
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Selected: $selectedDateLabel',
              style: const TextStyle(
                color: Color(0xFF4338CA),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _MiniCalendar(
            focusedMonth: focusedMonth,
            selectedDate: selectedDate,
            reminders: reminders,
            onDateSelected: onDateSelected,
          ),
          const SizedBox(height: 12),
          if (appointments.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'No upcoming appointments',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                ),
              ),
            )
          else
            ...appointments
                .take(2)
                .map(
                  (apt) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E7FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            apt.reminder.type.icon,
                            color: const Color(0xFF4F46E5),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      apt.reminder.title,
                                      style: const TextStyle(
                                        color: Color(0xFF1F2937),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0E7FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      DateFormat(
                                        'MMM d',
                                      ).format(apt.occurrence),
                                      style: const TextStyle(
                                        color: Color(0xFF4338CA),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('h:mm a').format(apt.occurrence),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              if (apt.reminder.notes.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  apt.reminder.notes,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _MiniCalendar extends StatelessWidget {
  const _MiniCalendar({
    required this.focusedMonth,
    required this.selectedDate,
    required this.reminders,
    required this.onDateSelected,
  });

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final List<ReminderItem> reminders;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month);
    final leadingOffset = firstDayOfMonth.weekday % 7;
    final gridStart = firstDayOfMonth.subtract(Duration(days: leadingOffset));
    final days = List.generate(
      42,
      (index) =>
          DateTime(gridStart.year, gridStart.month, gridStart.day + index),
    );

    final weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Column(
      children: [
        Row(
          children:
              weekdays.map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          itemCount: 42,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final day = days[index];
            final isCurrentMonth = day.month == focusedMonth.month;
            final isSelected = DateUtils.isSameDay(day, selectedDate);
            final isToday = DateUtils.isSameDay(day, DateTime.now());
            final hasReminder = reminders.any((r) => r.occursOnDay(day));

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onDateSelected(day),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? const Color(0xFF6366F1)
                            : isToday
                            ? const Color(0xFFE0E7FF)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected || isToday
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                          color:
                              isSelected
                                  ? Colors.white
                                  : isCurrentMonth
                                  ? const Color(0xFF1F2937)
                                  : Colors.grey.shade400,
                        ),
                      ),
                      if (hasReminder && !isSelected)
                        Positioned(
                          bottom: 2,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: Color(0xFF6366F1),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _FigmaEmptyTimeline extends StatelessWidget {
  const _FigmaEmptyTimeline({required this.onAddEvent});

  final VoidCallback onAddEvent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.hourglass_empty_rounded,
              size: 32,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No events logged yet today',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the quick actions above to log care events',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onAddEvent,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Log first event'),
          ),
        ],
      ),
    );
  }
}

class _HomeInsights {
  const _HomeInsights({
    required this.lastFeeding,
    required this.lastSleep,
    required this.lowStockCount,
    required this.activeReminderCount,
  });

  final BabyEvent? lastFeeding;
  final BabyEvent? lastSleep;
  final int lowStockCount;
  final int activeReminderCount;

  factory _HomeInsights.empty() {
    return const _HomeInsights(
      lastFeeding: null,
      lastSleep: null,
      lowStockCount: 0,
      activeReminderCount: 0,
    );
  }

  _HomeInsights copyWith({
    BabyEvent? lastFeeding,
    BabyEvent? lastSleep,
    int? lowStockCount,
    int? activeReminderCount,
  }) {
    return _HomeInsights(
      lastFeeding: lastFeeding ?? this.lastFeeding,
      lastSleep: lastSleep ?? this.lastSleep,
      lowStockCount: lowStockCount ?? this.lowStockCount,
      activeReminderCount: activeReminderCount ?? this.activeReminderCount,
    );
  }

  String get lastFeedingLabel {
    if (lastFeeding == null) return 'No feeds yet';
    return DateFormat('h:mm a').format(lastFeeding!.timestamp);
  }

  String get lastSleepLabel {
    if (lastSleep == null) return 'No sleep logged';
    return DateFormat('h:mm a').format(lastSleep!.timestamp);
  }
}

class _ScheduledReminder {
  const _ScheduledReminder({required this.reminder, required this.occurrence});

  final ReminderItem reminder;
  final DateTime occurrence;
}

class _ReminderEditorResult {
  const _ReminderEditorResult({this.reminder, this.deleted = false});

  final ReminderItem? reminder;
  final bool deleted;
}

class _ReminderEditorSheet extends StatefulWidget {
  const _ReminderEditorSheet({required this.initialDate, this.reminder});

  final DateTime initialDate;
  final ReminderItem? reminder;

  @override
  State<_ReminderEditorSheet> createState() => _ReminderEditorSheetState();
}

class _ReminderEditorSheetState extends State<_ReminderEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late ReminderType _type;
  late ReminderRepeat _repeat;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    final reminder = widget.reminder;
    final baseDate = reminder?.dateTime ?? widget.initialDate;
    _titleController = TextEditingController(text: reminder?.title ?? '');
    _notesController = TextEditingController(text: reminder?.notes ?? '');
    _type = reminder?.type ?? ReminderType.checkup;
    _repeat = reminder?.repeat ?? ReminderRepeat.once;
    _selectedDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    _selectedTime = TimeOfDay(
      hour: baseDate.hour == 0 && reminder == null ? 9 : baseDate.hour,
      minute: baseDate.minute,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    Navigator.of(context).pop(
      _ReminderEditorResult(
        reminder: ReminderItem(
          id:
              widget.reminder?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          type: _type,
          title: _titleController.text.trim(),
          dateTime: dateTime,
          notes: _notesController.text.trim(),
          repeat: _repeat,
        ),
      ),
    );
  }

  void _delete() {
    setState(() {
      _isDeleting = true;
    });
    Navigator.of(context).pop(const _ReminderEditorResult(deleted: true));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.reminder != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEditing ? 'Edit reminder' : 'New reminder',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 10),
              DropdownButtonFormField<ReminderType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Reminder type',
                  border: OutlineInputBorder(),
                ),
                items:
                    ReminderType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                Icon(type.icon, size: 18),
                                const SizedBox(width: 8),
                                Text(type.label),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _type = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Example: 6-month vaccine visit',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded),
                      label: Text(
                        DateFormat('MMM d, yyyy').format(_selectedDate),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(_selectedTime.format(context)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<ReminderRepeat>(
                value: _repeat,
                decoration: const InputDecoration(
                  labelText: 'Repeat',
                  border: OutlineInputBorder(),
                ),
                items:
                    ReminderRepeat.values
                        .map(
                          (repeat) => DropdownMenuItem(
                            value: repeat,
                            child: Text(repeat.label),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _repeat = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText:
                      'Doctor name, clinic, vaccine brand, or follow-up details',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              if (isEditing) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isDeleting ? null : _delete,
                    icon:
                        _isDeleting
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.delete_outline_rounded),
                    label: Text(
                      _isDeleting ? 'Deleting...' : 'Delete reminder',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isEditing ? 'Save changes' : 'Create reminder',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
