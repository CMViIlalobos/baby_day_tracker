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

  BabyEvent? _lastFeeding;
  BabyEvent? _lastDiaper;
  BabyEvent? _lastSleep;
  BabyEvent? _activeSleep;
  BabyEvent? _activeFeeding;

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
    setState(() => _isLoading = true);
    try {
      final events = await DatabaseHelper.instance.getTodayEvents();
      final lastFeeding = await DatabaseHelper.instance.getLatestEventByType(
        EventType.feeding,
      );
      final lastDiaper = await DatabaseHelper.instance.getLatestEventByType(
        EventType.diaper,
      );
      final lastSleep = await DatabaseHelper.instance.getLatestEventByType(
        EventType.sleep,
      );

      BabyEvent? activeSleep;
      if (lastSleep != null &&
          (lastSleep.sleepDuration == null || lastSleep.sleepDuration == 0)) {
        activeSleep = lastSleep;
      }

      BabyEvent? activeFeeding;
      if (lastFeeding != null &&
          (lastFeeding.feedingDuration == null ||
              lastFeeding.feedingDuration == 0)) {
        activeFeeding = lastFeeding;
      }

      final lowStockItems = await DatabaseHelper.instance.getLowStockItems();
      final reminders = await ReminderRepository.instance.loadReminders();

      if (!mounted) return;

      setState(() {
        _todayEvents = events;
        _lowStockItems = lowStockItems;
        _reminders = _sortReminders(reminders);
        _lastFeeding = lastFeeding;
        _lastDiaper = lastDiaper;
        _lastSleep = lastSleep;
        _activeSleep = activeSleep;
        _activeFeeding = activeFeeding;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(error);
    }
  }

  String _getTimeAgo(DateTime? timestamp) {
    if (timestamp == null) return '';
    final diff = DateTime.now().difference(timestamp);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Future<void> _toggleFeed() async {
    if (_activeFeeding != null) {
      final duration = DateTime.now().difference(_activeFeeding!.timestamp);
      final updatedEvent = _activeFeeding!.copyWith(
        feedingDuration: duration.inMinutes,
      );
      await DatabaseHelper.instance.updateEvent(updatedEvent);
      await _loadData();
      await widget.onChanged();
      if (!mounted) return;

      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🍼 Feeding ended (${hours > 0 ? "$hours hr $minutes min" : "${minutes}min"}',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _undoFeedEnd(updatedEvent),
          ),
        ),
      );
    } else {
      final event = BabyEvent(
        type: EventType.feeding,
        timestamp: DateTime.now(),
        feedingDuration: null,
      );
      await _saveWithUndo(event, '🍼 Feeding started');
    }
  }

  Future<void> _twoTapDiaper() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                const Text(
                  'Diaper Type',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildQuickOption(
                  Icons.water_drop,
                  'Wet',
                  Colors.blue,
                  () => Navigator.pop(context, 'Wet'),
                ),
                _buildQuickOption(
                  Icons.water_drop,
                  'Dirty',
                  Colors.brown,
                  () => Navigator.pop(context, 'Dirty'),
                ),
                _buildQuickOption(
                  Icons.water_drop,
                  'Both',
                  Colors.green,
                  () => Navigator.pop(context, 'Both'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
    if (type == null) return;

    final event = BabyEvent(
      type: EventType.diaper,
      timestamp: DateTime.now(),
      diaperType: type,
    );
    await _saveWithUndo(event, '💩 $type diaper');
  }

  Future<void> _toggleSleep() async {
    if (_activeSleep != null) {
      final duration = DateTime.now().difference(_activeSleep!.timestamp);
      final updatedEvent = _activeSleep!.copyWith(
        sleepDuration: duration.inMinutes,
      );
      await DatabaseHelper.instance.updateEvent(updatedEvent);
      await _loadData();
      await widget.onChanged();
      if (!mounted) return;

      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '😴 Sleep ended (${hours > 0 ? "$hours hr $minutes min" : "${minutes}min"}',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _undoSleepEnd(updatedEvent),
          ),
        ),
      );
    } else {
      final event = BabyEvent(
        type: EventType.sleep,
        timestamp: DateTime.now(),
        sleepDuration: null,
      );
      await _saveWithUndo(event, '😴 Sleep started');
    }
  }

  Future<void> _openMedicineForm() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _MedicineFormSheet(),
    );
    if (result == true) {
      await _loadData();
      await widget.onChanged();
    }
  }

  Future<void> _saveWithUndo(BabyEvent event, String message) async {
    await DatabaseHelper.instance.insertEvent(event);
    await _loadData();
    await widget.onChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _undoLastEvent(event),
        ),
      ),
    );
  }

  Future<void> _undoLastEvent(BabyEvent event) async {
    if (event.id != null) {
      await DatabaseHelper.instance.deleteEvent(event.id!);
      await _loadData();
      await widget.onChanged();
    }
  }

  Future<void> _undoSleepEnd(BabyEvent originalEvent) async {
    final reverted = originalEvent.copyWith(sleepDuration: null);
    await DatabaseHelper.instance.updateEvent(reverted);
    await _loadData();
    await widget.onChanged();
  }

  Future<void> _undoFeedEnd(BabyEvent originalEvent) async {
    final reverted = originalEvent.copyWith(feedingDuration: null);
    await DatabaseHelper.instance.updateEvent(reverted);
    await _loadData();
    await widget.onChanged();
  }

  Widget _buildQuickOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(icon, color: color),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
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
    await DatabaseHelper.instance.deleteEvent(event.id!);
    await _loadData();
    await widget.onChanged();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Event deleted')));
  }

  Future<void> _saveReminder(ReminderItem reminder) async {
    final updated = [..._reminders];
    final index = updated.indexWhere((item) => item.id == reminder.id);
    if (index >= 0)
      updated[index] = reminder;
    else
      updated.add(reminder);
    await ReminderRepository.instance.saveReminders(_sortReminders(updated));
    if (!mounted) return;
    setState(() => _reminders = _sortReminders(updated));
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
    setState(() => _reminders = updated);
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
    if (result == null) return;
    if (result.deleted && reminder != null) await _deleteReminder(reminder);
    if (result.reminder != null) await _saveReminder(result.reminder!);
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
    return _reminders.where((reminder) => reminder.occursOnDay(day)).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
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

  List<ReminderItem> _dueTodayReminders() => _remindersForDay(DateTime.now());

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
        widget.babyName.trim().isEmpty ? 'Baby' : widget.babyName.trim();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _Header(babyName: greetingName, profile: widget.profile),
            const SizedBox(height: 20),

            _StatusCards(
              lastFeeding: _lastFeeding,
              lastDiaper: _lastDiaper,
              activeSleep: _activeSleep,
              activeFeeding: _activeFeeding,
              lastSleep: _lastSleep,
              getTimeAgo: _getTimeAgo,
            ),
            const SizedBox(height: 20),

            _ActionButtons(
              onFeed: _toggleFeed,
              onDiaper: _twoTapDiaper,
              onSleep: _toggleSleep,
              onMedicine: _openMedicineForm,
              isFeedActive: _activeFeeding != null,
              isSleepActive: _activeSleep != null,
            ),
            const SizedBox(height: 20),

            if (_lowStockItems.isNotEmpty)
              _LowStockAlert(items: _lowStockItems),
            if (_lowStockItems.isNotEmpty) const SizedBox(height: 16),

            if (dueToday.isNotEmpty) ...[
              _RemindersSection(
                reminders: dueToday,
                onEdit: _openReminderEditor,
                onDelete: _deleteReminder,
              ),
              const SizedBox(height: 16),
            ],

            _AppointmentsSection(
              appointments: upcomingAppointments,
              selectedDate: _selectedDate,
              focusedMonth: _focusedMonth,
              reminders: _reminders,
              onMonthChanged:
                  (month) => setState(
                    () => _focusedMonth = DateTime(month.year, month.month),
                  ),
              onDateSelected:
                  (day) => setState(() {
                    _selectedDate = DateTime(day.year, day.month, day.day);
                    _focusedMonth = DateTime(day.year, day.month);
                  }),
              onAddReminder: () => _openReminderEditor(date: _selectedDate),
              onEditReminder:
                  (reminder) => _openReminderEditor(
                    date: reminder.dateTime,
                    reminder: reminder,
                  ),
              onDeleteReminder: _deleteReminder,
            ),
            const SizedBox(height: 24),

            _TimelineSection(
              events: _todayEvents,
              isLoading: _isLoading,
              onEdit: _openEditEventSheet,
              onDelete: _deleteEvent,
              onAddFirst: _toggleFeed,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.babyName, required this.profile});
  final String babyName;
  final BabyProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (profile.photoBytes != null) ...[
          CircleAvatar(
            radius: 28,
            backgroundImage: MemoryImage(profile.photoBytes!),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hello, Mom! 👋',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              Text(
                'How\'s $babyName today?',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            DateFormat('MMM d').format(DateTime.now()),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _StatusCards extends StatelessWidget {
  const _StatusCards({
    required this.lastFeeding,
    required this.lastDiaper,
    required this.activeSleep,
    required this.activeFeeding,
    required this.lastSleep,
    required this.getTimeAgo,
  });
  final BabyEvent? lastFeeding,
      lastDiaper,
      lastSleep,
      activeSleep,
      activeFeeding;
  final String Function(DateTime?) getTimeAgo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatusCard(
            icon: Icons.baby_changing_station,
            label: 'Feeding',
            value:
                activeFeeding != null
                    ? '🍼 Active'
                    : (lastFeeding != null
                        ? getTimeAgo(lastFeeding!.timestamp)
                        : '—'),
            color: Colors.orange,
            isActive: activeFeeding != null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatusCard(
            icon: Icons.water_drop,
            label: 'Diaper',
            value: lastDiaper != null ? getTimeAgo(lastDiaper!.timestamp) : '—',
            color: Colors.cyan,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatusCard(
            icon: Icons.nightlight_round,
            label: 'Sleep',
            value:
                activeSleep != null
                    ? '💤 Active'
                    : (lastSleep != null
                        ? getTimeAgo(lastSleep!.timestamp)
                        : '—'),
            color: Colors.purple,
            isActive: activeSleep != null,
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.isActive = false,
  });
  final IconData icon;
  final String label, value;
  final Color color;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.15) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? color : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: isActive ? color : Colors.grey.shade600, size: 28),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isActive ? color : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onFeed,
    required this.onDiaper,
    required this.onSleep,
    required this.onMedicine,
    required this.isFeedActive,
    required this.isSleepActive,
  });
  final VoidCallback onFeed, onDiaper, onSleep, onMedicine;
  final bool isFeedActive, isSleepActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionButton(
          icon: Icons.baby_changing_station,
          label: isFeedActive ? '🍼 END' : '🍼 FEED',
          color: Colors.orange,
          onTap: onFeed,
        ),
        const SizedBox(width: 12),
        _ActionButton(
          icon: Icons.water_drop,
          label: '💩 DIAPER',
          color: Colors.cyan,
          onTap: onDiaper,
        ),
        const SizedBox(width: 12),
        _ActionButton(
          icon: Icons.nightlight_round,
          label: isSleepActive ? '😴 END' : '😴 SLEEP',
          color: Colors.purple,
          onTap: onSleep,
        ),
        const SizedBox(width: 12),
        _ActionButton(
          icon: Icons.medication,
          label: '💊 MEDS',
          color: Colors.pink,
          onTap: onMedicine,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 36),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
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

class _LowStockAlert extends StatelessWidget {
  const _LowStockAlert({required this.items});
  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${items.length} low stock item${items.length > 1 ? 's' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemindersSection extends StatelessWidget {
  const _RemindersSection({
    required this.reminders,
    required this.onEdit,
    required this.onDelete,
  });
  final List<ReminderItem> reminders;
  final Function({required DateTime date, ReminderItem? reminder}) onEdit;
  final Function(ReminderItem) onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔔 Today\'s Reminders',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ...reminders.map(
            (r) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 16,
                child: Icon(r.type.icon, size: 16),
              ),
              title: Text(
                r.title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(DateFormat('h:mm a').format(r.dateTime)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => onEdit(date: r.dateTime, reminder: r),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: () => onDelete(r),
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

class _AppointmentsSection extends StatelessWidget {
  const _AppointmentsSection({
    required this.appointments,
    required this.selectedDate,
    required this.focusedMonth,
    required this.reminders,
    required this.onMonthChanged,
    required this.onDateSelected,
    required this.onAddReminder,
    required this.onEditReminder,
    required this.onDeleteReminder,
  });
  final List<_ScheduledReminder> appointments;
  final DateTime selectedDate, focusedMonth;
  final List<ReminderItem> reminders;
  final ValueChanged<DateTime> onMonthChanged, onDateSelected;
  final VoidCallback onAddReminder;
  final ValueChanged<ReminderItem> onEditReminder, onDeleteReminder;

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(focusedMonth);
    final weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final firstWeekday = firstDayOfMonth.weekday - 1;
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final daysBefore = firstWeekday;
    final totalDays = daysBefore + daysInMonth;
    final rows = (totalDays / 7).ceil();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📅 Appointments',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed:
                        () => onMonthChanged(
                          DateTime(focusedMonth.year, focusedMonth.month - 1),
                        ),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  Text(
                    monthLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed:
                        () => onMonthChanged(
                          DateTime(focusedMonth.year, focusedMonth.month + 1),
                        ),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: onAddReminder,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          Column(
            children: [
              Row(
                children:
                    weekdays
                        .map(
                          (day) => Expanded(
                            child: Center(
                              child: Text(
                                day,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 8),

              for (int row = 0; row < rows; row++) ...[
                Row(
                  children: List.generate(7, (col) {
                    final dayIndex = row * 7 + col;
                    final dayNumber = dayIndex - daysBefore + 1;
                    final isCurrentMonth =
                        dayNumber >= 1 && dayNumber <= daysInMonth;
                    final date = DateTime(
                      focusedMonth.year,
                      focusedMonth.month,
                      dayNumber,
                    );
                    final isSelected =
                        isCurrentMonth &&
                        DateUtils.isSameDay(date, selectedDate);
                    final isToday =
                        isCurrentMonth &&
                        DateUtils.isSameDay(date, DateTime.now());
                    final hasReminder =
                        isCurrentMonth &&
                        reminders.any((r) => r.occursOnDay(date));

                    return Expanded(
                      child: InkWell(
                        onTap:
                            isCurrentMonth ? () => onDateSelected(date) : null,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? Colors.indigo
                                    : (isToday
                                        ? Colors.indigo.shade100
                                        : Colors.transparent),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                isCurrentMonth ? dayNumber.toString() : '',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : (isToday
                                              ? Colors.indigo
                                              : Colors.black87),
                                ),
                              ),
                              if (hasReminder && !isSelected)
                                Positioned(
                                  bottom: 2,
                                  child: Container(
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: Colors.indigo,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                if (row < rows - 1) const SizedBox(height: 4),
              ],
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 12),

          if (appointments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No upcoming appointments',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...appointments
                .take(3)
                .map(
                  (apt) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.shade100,
                      child: Icon(
                        apt.reminder.type.icon,
                        size: 20,
                        color: Colors.indigo,
                      ),
                    ),
                    title: Text(
                      apt.reminder.title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${DateFormat('MMM d').format(apt.occurrence)} • ${DateFormat('h:mm a').format(apt.occurrence)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => onEditReminder(apt.reminder),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18),
                          onPressed: () => onDeleteReminder(apt.reminder),
                        ),
                      ],
                    ),
                  ),
                ),

          if (appointments.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+${appointments.length - 3} more',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({
    required this.events,
    required this.isLoading,
    required this.onEdit,
    required this.onDelete,
    required this.onAddFirst,
  });
  final List<BabyEvent> events;
  final bool isLoading;
  final Function(BabyEvent) onEdit, onDelete;
  final VoidCallback onAddFirst;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Today\'s Timeline',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (events.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${events.length} events',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (events.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.hourglass_empty, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'No events yet today',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onAddFirst,
                  child: const Text('Log First Event'),
                ),
              ],
            ),
          )
        else
          ...events.map(
            (event) => EventTimelineItem(
              event: event,
              onTap: () => onEdit(event),
              onDelete: () => onDelete(event),
            ),
          ),
      ],
    );
  }
}

class _MedicineFormSheet extends StatefulWidget {
  const _MedicineFormSheet();

  @override
  State<_MedicineFormSheet> createState() => _MedicineFormSheetState();
}

class _MedicineFormSheetState extends State<_MedicineFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _doseController;
  late TextEditingController _unitController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _doseController = TextEditingController();
    _unitController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _doseController.dispose();
    _unitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    final event = BabyEvent(
      type: EventType.medicine,
      timestamp: DateTime.now(),
      medicineDose: _doseController.text.trim(),
      medicineUnit: _unitController.text.trim(),
      notes:
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
    );

    await DatabaseHelper.instance.insertEvent(event);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '💊 Log Medicine',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _doseController,
                    decoration: const InputDecoration(
                      labelText: 'Dose',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., 2.5',
                    ),
                    keyboardType: TextInputType.number,
                    validator:
                        (v) => v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                      hintText: 'ml, tablet, drop',
                    ),
                    validator:
                        (v) => v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g., After meal, with water',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saveMedicine,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Save Medicine Log',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
  late final TextEditingController _titleController, _notesController;
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
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
    setState(() => _isDeleting = true);
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
              const SizedBox(height: 16),
              DropdownButtonFormField<ReminderType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items:
                    ReminderType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Row(
                              children: [
                                Icon(type.icon),
                                const SizedBox(width: 8),
                                Text(type.label),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _type = value!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        DateFormat('MMM d, yyyy').format(_selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(_selectedTime.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                onChanged: (value) => setState(() => _repeat = value!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              if (isEditing)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isDeleting ? null : _delete,
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete reminder'),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(isEditing ? 'Save' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
