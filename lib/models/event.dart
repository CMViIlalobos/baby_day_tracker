import 'package:flutter/material.dart';

enum EventType { feeding, diaper, sleep, medicine }

extension EventTypeX on EventType {
  String get label => switch (this) {
    EventType.feeding => 'Feeding',
    EventType.diaper => 'Diaper',
    EventType.sleep => 'Sleep',
    EventType.medicine => 'Medicine',
  };

  String get dbValue => name;

  IconData get icon => switch (this) {
    EventType.feeding => Icons.baby_changing_station_rounded,
    EventType.diaper => Icons.water_drop_rounded,
    EventType.sleep => Icons.nightlight_round_rounded,
    EventType.medicine => Icons.medication_liquid_rounded,
  };

  Color get accentColor => switch (this) {
    EventType.feeding => const Color(0xFF9FC5F8),
    EventType.diaper => const Color(0xFFFFD6A5),
    EventType.sleep => const Color(0xFFB5B8FF),
    EventType.medicine => const Color(0xFFA8E6CF),
  };

  static EventType fromDbValue(String value) {
    return EventType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => EventType.feeding,
    );
  }
}

class BabyEvent {
  const BabyEvent({
    this.id,
    required this.type,
    required this.timestamp,
    this.notes,
    this.feedingDuration,
    this.feedingSide,
    this.diaperType,
    this.sleepDuration,
    this.medicineDose,
    this.medicineUnit,
  });

  final int? id;
  final EventType type;
  final DateTime timestamp;
  final String? notes;
  final int? feedingDuration;
  final String? feedingSide;
  final String? diaperType;
  final int? sleepDuration;
  final String? medicineDose;
  final String? medicineUnit;

  BabyEvent copyWith({
    int? id,
    EventType? type,
    DateTime? timestamp,
    String? notes,
    bool clearNotes = false,
    int? feedingDuration,
    String? feedingSide,
    String? diaperType,
    int? sleepDuration,
    String? medicineDose,
    String? medicineUnit,
  }) {
    return BabyEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      notes: clearNotes ? null : (notes ?? this.notes),
      feedingDuration: feedingDuration ?? this.feedingDuration,
      feedingSide: feedingSide ?? this.feedingSide,
      diaperType: diaperType ?? this.diaperType,
      sleepDuration: sleepDuration ?? this.sleepDuration,
      medicineDose: medicineDose ?? this.medicineDose,
      medicineUnit: medicineUnit ?? this.medicineUnit,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.dbValue,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
      'feedingDuration': feedingDuration,
      'feedingSide': feedingSide,
      'diaperType': diaperType,
      'sleepDuration': sleepDuration,
      'medicineDose': medicineDose,
      'medicineUnit': medicineUnit,
    };
  }

  factory BabyEvent.fromMap(Map<String, dynamic> map) {
    return BabyEvent(
      id: map['id'] as int?,
      type: EventTypeX.fromDbValue(map['type'] as String? ?? 'feeding'),
      timestamp: DateTime.parse(map['timestamp'] as String),
      notes: map['notes'] as String?,
      feedingDuration: map['feedingDuration'] as int?,
      feedingSide: map['feedingSide'] as String?,
      diaperType: map['diaperType'] as String?,
      sleepDuration: map['sleepDuration'] as int?,
      medicineDose: map['medicineDose'] as String?,
      medicineUnit: map['medicineUnit'] as String?,
    );
  }
}

class InventoryItem {
  const InventoryItem({
    this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.lowStockThreshold,
    this.notes,
    required this.updatedAt,
  });

  final int? id;
  final String name;
  final String category;
  final int quantity;
  final String unit;
  final int lowStockThreshold;
  final String? notes;
  final DateTime updatedAt;

  bool get isLowStock => quantity <= lowStockThreshold;

  InventoryItem copyWith({
    int? id,
    String? name,
    String? category,
    int? quantity,
    String? unit,
    int? lowStockThreshold,
    String? notes,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'lowStockThreshold': lowStockThreshold,
      'notes': notes,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? 'Supplies',
      quantity: map['quantity'] as int? ?? 0,
      unit: map['unit'] as String? ?? 'pcs',
      lowStockThreshold: map['lowStockThreshold'] as int? ?? 0,
      notes: map['notes'] as String?,
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
