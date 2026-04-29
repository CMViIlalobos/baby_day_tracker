import 'dart:convert';
import 'dart:typed_data';

enum AppThemeColor { blue, pink, mint }

extension AppThemeColorX on AppThemeColor {
  String get label => switch (this) {
    AppThemeColor.blue => 'Blue',
    AppThemeColor.pink => 'Pink',
    AppThemeColor.mint => 'Mint Green',
  };

  String get dbValue => name;

  static AppThemeColor fromDbValue(String? value) {
    return AppThemeColor.values.firstWhere(
      (theme) => theme.name == value,
      orElse: () => AppThemeColor.blue,
    );
  }
}

class BabyProfile {
  const BabyProfile({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.themeColorValue,
    required this.photoBase64,
    required this.notificationsEnabled,
    required this.reminderTimes,
  });

  final int id;
  final String name;
  final DateTime? birthDate;
  final AppThemeColor themeColorValue;
  final String? photoBase64;
  final bool notificationsEnabled;
  final List<String> reminderTimes;

  factory BabyProfile.empty() {
    return const BabyProfile(
      id: 1,
      name: '',
      birthDate: null,
      themeColorValue: AppThemeColor.blue,
      photoBase64: null,
      notificationsEnabled: false,
      reminderTimes: [],
    );
  }

  BabyProfile copyWith({
    int? id,
    String? name,
    DateTime? birthDate,
    bool clearBirthDate = false,
    AppThemeColor? themeColorValue,
    String? photoBase64,
    bool clearPhoto = false,
    bool? notificationsEnabled,
    List<String>? reminderTimes,
  }) {
    return BabyProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      themeColorValue: themeColorValue ?? this.themeColorValue,
      photoBase64: clearPhoto ? null : (photoBase64 ?? this.photoBase64),
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderTimes: reminderTimes ?? this.reminderTimes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'birthDate': birthDate?.toIso8601String(),
      'themeColor': themeColorValue.dbValue,
      'photoBase64': photoBase64,
      'notificationsEnabled': notificationsEnabled ? 1 : 0,
      'reminderTimes': jsonEncode(reminderTimes),
    };
  }

  factory BabyProfile.fromMap(Map<String, dynamic> map) {
    final reminderJson = map['reminderTimes'] as String?;
    return BabyProfile(
      id: map['id'] as int? ?? 1,
      name: map['name'] as String? ?? '',
      birthDate:
          map['birthDate'] == null
              ? null
              : DateTime.tryParse(map['birthDate'] as String),
      themeColorValue: AppThemeColorX.fromDbValue(map['themeColor'] as String?),
      photoBase64: map['photoBase64'] as String?,
      notificationsEnabled: (map['notificationsEnabled'] as int? ?? 0) == 1,
      reminderTimes:
          reminderJson == null || reminderJson.isEmpty
              ? []
              : List<String>.from(jsonDecode(reminderJson) as List<dynamic>),
    );
  }

  Uint8List? get photoBytes {
    final value = photoBase64;
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }
}

class GrowthEntry {
  const GrowthEntry({
    this.id,
    required this.recordedAt,
    this.weightKg,
    this.heightCm,
    this.headCircumferenceCm,
    this.notes,
  });

  final int? id;
  final DateTime recordedAt;
  final double? weightKg;
  final double? heightCm;
  final double? headCircumferenceCm;
  final String? notes;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recordedAt': recordedAt.toIso8601String(),
      'weightKg': weightKg,
      'heightCm': heightCm,
      'headCircumferenceCm': headCircumferenceCm,
      'notes': notes,
    };
  }

  factory GrowthEntry.fromMap(Map<String, dynamic> map) {
    return GrowthEntry(
      id: map['id'] as int?,
      recordedAt: DateTime.parse(map['recordedAt'] as String),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      headCircumferenceCm: (map['headCircumferenceCm'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
    );
  }
}

class MilestoneEntry {
  const MilestoneEntry({
    this.id,
    required this.title,
    required this.category,
    required this.achievedAt,
    this.notes,
  });

  final int? id;
  final String title;
  final String category;
  final DateTime achievedAt;
  final String? notes;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'achievedAt': achievedAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory MilestoneEntry.fromMap(Map<String, dynamic> map) {
    return MilestoneEntry(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      achievedAt: DateTime.parse(map['achievedAt'] as String),
      notes: map['notes'] as String?,
    );
  }
}

class BabyPhoto {
  const BabyPhoto({
    this.id,
    required this.month,
    required this.photoBase64,
    required this.createdAt,
    this.caption,
  });

  final int? id;
  final int month;
  final String photoBase64;
  final DateTime createdAt;
  final String? caption;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'month': month,
      'photoBase64': photoBase64,
      'createdAt': createdAt.toIso8601String(),
      'caption': caption,
    };
  }

  factory BabyPhoto.fromMap(Map<String, dynamic> map) {
    return BabyPhoto(
      id: map['id'] as int?,
      month: map['month'] as int? ?? 1,
      photoBase64: map['photoBase64'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      caption: map['caption'] as String?,
    );
  }

  Uint8List? get photoBytes {
    if (photoBase64.isEmpty) {
      return null;
    }
    try {
      return base64Decode(photoBase64);
    } catch (_) {
      return null;
    }
  }
}
