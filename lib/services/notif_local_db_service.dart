import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model lokal untuk notifikasi yang berhasil ditangkap
class CapturedNotification {
  final String id;
  final String package_;
  final String title;
  final String text;
  final int timestamp;
  final bool isSynced;

  const CapturedNotification({
    required this.id,
    required this.package_,
    required this.title,
    required this.text,
    required this.timestamp,
    this.isSynced = false,
  });

  factory CapturedNotification.fromMap(Map<String, dynamic> map) {
    return CapturedNotification(
      id: map['id'] as String,
      package_: map['package'] as String,
      title: map['title'] as String,
      text: map['text'] as String,
      timestamp: map['timestamp'] as int,
      isSynced: (map['is_synced'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'package': package_,
        'title': title,
        'text': text,
        'timestamp': timestamp,
        'is_synced': isSynced ? 1 : 0,
      };

  Map<String, dynamic> toFirestoreMap() => {
        'package': package_,
        'title': title,
        'text': text,
        'timestamp': Timestamp.fromMillisecondsSinceEpoch(timestamp), // Gunakan Timestamp asli
        'capturedAt': FieldValue.serverTimestamp(), // Waktu sinkronisasi
        'postedAt': DateTime.fromMillisecondsSinceEpoch(timestamp).toIso8601String(),
      };
}

/// Service untuk operasi SQLite lokal — insert, query, delete notif
class NotifLocalDbService {
  static Database? _db;
  static const _dbName = 'captured_notifications.db';
  static const _tableName = 'notifications';
  static const _maxQueue = 1000; // Tingkatkan batas max item di lokal

  static Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            package TEXT NOT NULL,
            title TEXT NOT NULL,
            text TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            is_synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
        // Index untuk query is_synced cepat
        await db.execute(
            'CREATE INDEX idx_synced ON $_tableName (is_synced)');
      },
    );
  }

  /// Insert notif baru. Skip jika ID sudah ada (duplicate guard).
  static Future<void> insertNotification(CapturedNotification notif) async {
    final db = await _database;

    // Cek apakah sudah sampai batas queue
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_tableName'));
    if ((count ?? 0) >= _maxQueue) {
      // Hapus 50 item paling lama untuk beri ruang
      await db.execute(
          'DELETE FROM $_tableName WHERE id IN (SELECT id FROM $_tableName ORDER BY timestamp ASC LIMIT 50)');
    }

    await db.insert(
      _tableName,
      notif.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore, // auto-skip duplicate
    );
  }

  /// Ambil semua notif yang belum di-sync ke Firestore
  static Future<List<CapturedNotification>> getUnsynced({int limit = 100}) async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      where: 'is_synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    return maps.map((m) => CapturedNotification.fromMap(m)).toList();
  }

  /// Ambil semua notif (untuk ditampilkan di UI log)
  static Future<List<CapturedNotification>> getAll({int limit = 200}) async {
    final db = await _database;
    final maps = await db.query(
      _tableName,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map((m) => CapturedNotification.fromMap(m)).toList();
  }

  /// Tandai notif sebagai sudah sync
  static Future<void> markSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _database;
    final placeholders = ids.map((_) => '?').join(',');
    await db.rawUpdate(
        'UPDATE $_tableName SET is_synced = 1 WHERE id IN ($placeholders)',
        ids);
  }

  /// Hapus semua notif dari lokal
  static Future<void> deleteAll() async {
    final db = await _database;
    await db.delete(_tableName);
  }

  /// Hapus hanya yang sudah ter-sync
  static Future<void> deleteSynced() async {
    final db = await _database;
    await db.delete(_tableName, where: 'is_synced = ?', whereArgs: [1]);
  }

  /// Count total dan unsynced
  static Future<Map<String, int>> getCounts() async {
    final db = await _database;
    final total = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_tableName')) ?? 0;
    final unsynced = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM $_tableName WHERE is_synced = 0')) ?? 0;
    return {'total': total, 'unsynced': unsynced};
  }

  /// Hapus data synced yang lebih tua dari N hari
  static Future<void> deleteOldSynced({int olderThanDays = 30}) async {
    final db = await _database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: olderThanDays))
        .millisecondsSinceEpoch;
    await db.rawDelete(
        'DELETE FROM $_tableName WHERE is_synced = 1 AND timestamp < ?',
        [cutoff]);
  }
}

