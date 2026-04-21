import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ReminderType { checkup, vaccine, growthMeasurement, other }

extension ReminderTypeX on ReminderType {
  String get label => switch (this) {
    ReminderType.checkup => 'Checkup',
    ReminderType.vaccine => 'Vaccine',
    ReminderType.growthMeasurement => 'Growth measurement',
    ReminderType.other => 'Other',
  };

  Color get accentColor => switch (this) {
    ReminderType.checkup => const Color(0xFFF6B8A2),
    ReminderType.vaccine => const Color(0xFF9FC7F3),
    ReminderType.growthMeasurement => const Color(0xFFAEE0CC),
    ReminderType.other => const Color(0xFFD7C4F5),
  };

  IconData get icon => switch (this) {
    ReminderType.checkup => Icons.health_and_safety_rounded,
    ReminderType.vaccine => Icons.vaccines_rounded,
    ReminderType.growthMeasurement => Icons.monitor_weight_rounded,
    ReminderType.other => Icons.event_note_rounded,
  };

  static ReminderType fromName(String? value) {
    return ReminderType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ReminderType.other,
    );
  }
}

enum ReminderRepeat { once, weekly, monthly }

extension ReminderRepeatX on ReminderRepeat {
  String get label => switch (this) {
    ReminderRepeat.once => 'Once',
    ReminderRepeat.weekly => 'Weekly',
    ReminderRepeat.monthly => 'Monthly',
  };

  static ReminderRepeat fromName(String? value) {
    return ReminderRepeat.values.firstWhere(
      (repeat) => repeat.name == value,
      orElse: () => ReminderRepeat.once,
    );
  }
}

class ReminderItem {
  const ReminderItem({
    required this.id,
    required this.type,
    required this.title,
    required this.dateTime,
    required this.notes,
    required this.repeat,
  });

  final String id;
  final ReminderType type;
  final String title;
  final DateTime dateTime;
  final String notes;
  final ReminderRepeat repeat;

  ReminderItem copyWith({
    String? id,
    ReminderType? type,
    String? title,
    DateTime? dateTime,
    String? notes,
    ReminderRepeat? repeat,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      notes: notes ?? this.notes,
      repeat: repeat ?? this.repeat,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'dateTime': dateTime.toIso8601String(),
      'notes': notes,
      'repeat': repeat.name,
    };
  }

  factory ReminderItem.fromMap(Map<String, dynamic> map) {
    return ReminderItem(
      id: map['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: ReminderTypeX.fromName(map['type'] as String?),
      title: map['title'] as String? ?? '',
      dateTime: DateTime.parse(map['dateTime'] as String),
      notes: map['notes'] as String? ?? '',
      repeat: ReminderRepeatX.fromName(map['repeat'] as String?),
    );
  }

  static List<ReminderItem> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => ReminderItem.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  static String encodeList(List<ReminderItem> reminders) {
    return jsonEncode(reminders.map((reminder) => reminder.toMap()).toList());
  }

  bool occursOnDay(DateTime day) {
    final base = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final target = DateTime(day.year, day.month, day.day);

    if (target.isBefore(base)) {
      return false;
    }

    return switch (repeat) {
      ReminderRepeat.once =>
        base.year == target.year &&
            base.month == target.month &&
            base.day == target.day,
      ReminderRepeat.weekly => target.difference(base).inDays % 7 == 0,
      ReminderRepeat.monthly =>
        base.day == target.day && !_isBeforeMonth(base, target),
    };
  }

  DateTime nextOccurrenceFrom(DateTime moment) {
    final dayStart = DateTime(moment.year, moment.month, moment.day);
    if (repeat == ReminderRepeat.once) {
      return dateTime;
    }

    var candidate = dateTime;
    while (DateTime(candidate.year, candidate.month, candidate.day)
        .isBefore(dayStart)) {
      candidate = switch (repeat) {
        ReminderRepeat.once => candidate,
        ReminderRepeat.weekly => candidate.add(const Duration(days: 7)),
        ReminderRepeat.monthly => _addMonths(candidate, 1),
      };
    }
    return candidate;
  }

  bool get isDueToday => occursOnDay(DateTime.now());

  String get dateLabel => DateFormat('EEE, MMM d').format(dateTime);

  String get timeLabel => DateFormat('h:mm a').format(dateTime);

  static bool _isBeforeMonth(DateTime base, DateTime target) {
    if (target.year < base.year) {
      return true;
    }
    if (target.year == base.year && target.month < base.month) {
      return true;
    }
    return false;
  }

  static DateTime _addMonths(DateTime value, int months) {
    final totalMonths = value.month + months;
    final year = value.year + ((totalMonths - 1) ~/ 12);
    final month = ((totalMonths - 1) % 12) + 1;
    final lastDay = DateUtils.getDaysInMonth(year, month);
    return DateTime(
      year,
      month,
      value.day > lastDay ? lastDay : value.day,
      value.hour,
      value.minute,
    );
  }
}
