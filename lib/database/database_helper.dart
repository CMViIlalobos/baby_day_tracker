import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/baby_profile.dart';
import '../models/event.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  static const _databaseName = 'baby_day_tracker.db';
  static const _databaseVersion = 2;

  Database? _database;

  Future<void> initialize() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } else {
      databaseFactory = sqflite.databaseFactorySqflitePlugin;
    }
    await database;
  }

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, _databaseName);
    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createEventsTable(db);
    await _createProfileTable(db);
    await _createInventoryTable(db);
    await _createGrowthTable(db);
    await _createMilestonesTable(db);
    await db.insert('baby_profile', BabyProfile.empty().toMap());
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createInventoryTable(db);
      await _createGrowthTable(db);
      await _createMilestonesTable(db);
    }
  }

  Future<void> _createEventsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        notes TEXT,
        feedingDuration INTEGER,
        feedingSide TEXT,
        diaperType TEXT,
        sleepDuration INTEGER,
        medicineDose TEXT,
        medicineUnit TEXT
      )
    ''');
  }

  Future<void> _createProfileTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS baby_profile (
        id INTEGER PRIMARY KEY,
        name TEXT,
        birthDate TEXT,
        themeColor TEXT NOT NULL,
        notificationsEnabled INTEGER NOT NULL DEFAULT 0,
        reminderTimes TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createInventoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit TEXT NOT NULL,
        lowStockThreshold INTEGER NOT NULL,
        notes TEXT,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createGrowthTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS growth_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recordedAt TEXT NOT NULL,
        weightKg REAL,
        heightCm REAL,
        headCircumferenceCm REAL,
        notes TEXT
      )
    ''');
  }

  Future<void> _createMilestonesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS milestones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        achievedAt TEXT NOT NULL,
        notes TEXT
      )
    ''');
  }

  Future<int> insertEvent(BabyEvent event) async {
    try {
      final db = await database;
      return await db.insert('events', event.toMap());
    } catch (error) {
      throw Exception('Failed to save event: $error');
    }
  }

  Future<int> deleteEvent(int id) async {
    try {
      final db = await database;
      return await db.delete('events', where: 'id = ?', whereArgs: [id]);
    } catch (error) {
      throw Exception('Failed to delete event: $error');
    }
  }

  Future<List<BabyEvent>> getTodayEvents() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return getEventsBetween(start, end);
  }

  Future<List<BabyEvent>> getEventsBetween(DateTime start, DateTime end) async {
    try {
      final db = await database;
      final maps = await db.query(
        'events',
        where: 'timestamp >= ? AND timestamp < ?',
        whereArgs: [start.toIso8601String(), end.toIso8601String()],
        orderBy: 'timestamp DESC',
      );
      return maps.map(BabyEvent.fromMap).toList();
    } catch (error) {
      throw Exception('Failed to load events: $error');
    }
  }

  Future<List<BabyEvent>> getAllEvents() async {
    try {
      final db = await database;
      final maps = await db.query('events', orderBy: 'timestamp DESC');
      return maps.map(BabyEvent.fromMap).toList();
    } catch (error) {
      throw Exception('Failed to load all events: $error');
    }
  }

  Future<BabyEvent?> getLatestEventByType(EventType type) async {
    try {
      final db = await database;
      final maps = await db.query(
        'events',
        where: 'type = ?',
        whereArgs: [type.dbValue],
        orderBy: 'timestamp DESC',
        limit: 1,
      );
      if (maps.isEmpty) {
        return null;
      }
      return BabyEvent.fromMap(maps.first);
    } catch (error) {
      throw Exception('Failed to load latest event: $error');
    }
  }

  Future<BabyProfile> getBabyProfile() async {
    try {
      final db = await database;
      final maps = await db.query(
        'baby_profile',
        where: 'id = ?',
        whereArgs: [1],
        limit: 1,
      );
      if (maps.isEmpty) {
        final empty = BabyProfile.empty();
        await saveBabyProfile(empty);
        return empty;
      }
      return BabyProfile.fromMap(maps.first);
    } catch (error) {
      throw Exception('Failed to load baby profile: $error');
    }
  }

  Future<void> saveBabyProfile(BabyProfile profile) async {
    try {
      final db = await database;
      await db.insert(
        'baby_profile',
        profile.copyWith(id: 1).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (error) {
      throw Exception('Failed to save baby profile: $error');
    }
  }

  Future<List<InventoryItem>> getInventoryItems() async {
    try {
      final db = await database;
      final maps = await db.query(
        'inventory_items',
        orderBy: 'category ASC, name COLLATE NOCASE ASC',
      );
      return maps.map(InventoryItem.fromMap).toList();
    } catch (error) {
      throw Exception('Failed to load inventory: $error');
    }
  }

  Future<List<InventoryItem>> getLowStockItems() async {
    try {
      final db = await database;
      final maps = await db.query(
        'inventory_items',
        where: 'quantity <= lowStockThreshold',
        orderBy: 'quantity ASC, name COLLATE NOCASE ASC',
      );
      return maps.map(InventoryItem.fromMap).toList();
    } catch (error) {
      throw Exception('Failed to load low-stock items: $error');
    }
  }

  Future<int> insertInventoryItem(InventoryItem item) async {
    try {
      final db = await database;
      return await db.insert('inventory_items', item.toMap());
    } catch (error) {
      throw Exception('Failed to add inventory item: $error');
    }
  }

  Future<int> updateInventoryItem(InventoryItem item) async {
    try {
      final db = await database;
      return await db.update(
        'inventory_items',
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
    } catch (error) {
      throw Exception('Failed to update inventory item: $error');
    }
  }

  Future<int> deleteInventoryItem(int id) async {
    try {
      final db = await database;
      return await db.delete(
        'inventory_items',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (error) {
      throw Exception('Failed to delete inventory item: $error');
    }
  }

  Future<void> adjustInventoryQuantity(int id, int delta) async {
    try {
      final db = await database;
      final maps = await db.query(
        'inventory_items',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (maps.isEmpty) {
        throw Exception('Inventory item not found');
      }
      final item = InventoryItem.fromMap(maps.first);
      final nextQuantity = (item.quantity + delta).clamp(0, 999999);
      await db.update(
        'inventory_items',
        item
            .copyWith(quantity: nextQuantity, updatedAt: DateTime.now())
            .toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (error) {
      throw Exception('Failed to adjust inventory: $error');
    }
  }

  Future<List<GrowthEntry>> getGrowthEntries() async {
    try {
      final db = await database;
      final maps = await db.query('growth_entries', orderBy: 'recordedAt DESC');
      return maps.map(GrowthEntry.fromMap).toList();
    } catch (error) {
      throw Exception('Failed to load growth entries: $error');
    }
  }

  Future<int> insertGrowthEntry(GrowthEntry entry) async {
    try {
      final db = await database;
      return await db.insert('growth_entries', entry.toMap());
    } catch (error) {
      throw Exception('Failed to save growth entry: $error');
    }
  }

  Future<int> deleteGrowthEntry(int id) async {
    try {
      final db = await database;
      return await db.delete(
        'growth_entries',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (error) {
      throw Exception('Failed to delete growth entry: $error');
    }
  }

  Future<List<MilestoneEntry>> getMilestones() async {
    try {
      final db = await database;
      final maps = await db.query('milestones', orderBy: 'achievedAt DESC');
      return maps.map(MilestoneEntry.fromMap).toList();
    } catch (error) {
      throw Exception('Failed to load milestones: $error');
    }
  }

  Future<int> insertMilestone(MilestoneEntry milestone) async {
    try {
      final db = await database;
      return await db.insert('milestones', milestone.toMap());
    } catch (error) {
      throw Exception('Failed to save milestone: $error');
    }
  }

  Future<int> deleteMilestone(int id) async {
    try {
      final db = await database;
      return await db.delete('milestones', where: 'id = ?', whereArgs: [id]);
    } catch (error) {
      throw Exception('Failed to delete milestone: $error');
    }
  }
}
