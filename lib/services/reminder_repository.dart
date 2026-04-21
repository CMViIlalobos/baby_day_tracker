import '../models/reminder.dart';
import 'storage_backend_base.dart';
import 'storage_backend.dart';

class ReminderRepository {
  ReminderRepository._();

  static final ReminderRepository instance = ReminderRepository._();
  static const _storageKey = 'baby_day_tracker_reminders';
  final StorageBackend _backend = createStorageBackend();

  Future<List<ReminderItem>> loadReminders() async {
    final raw = await _backend.read(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      return ReminderItem.decodeList(raw);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveReminders(List<ReminderItem> reminders) {
    return _backend.write(_storageKey, ReminderItem.encodeList(reminders));
  }
}
