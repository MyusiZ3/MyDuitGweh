import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'notif_local_db_service.dart';

// ─── Task name constant ───────────────────────────────────────────────────────
const _kSyncTaskName = 'notifSyncTask';
const _kSyncTaskTag = 'notif_sync';
const _prefKeyInterval = 'notif_sync_interval_minutes';

// ─── Workmanager callback (top-level function, wajib di luar class) ───────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _kSyncTaskName) {
      try {
        await NotifSyncService.syncToFirestore();
        return Future.value(true);
      } catch (e) {
        debugPrint('Sync task error: $e');
        return Future.value(false);
      }
    }
    return Future.value(false);
  });
}

/// Service untuk sinkronisasi notifikasi lokal ke Firestore via Workmanager
class NotifSyncService {
  // ─── Init Workmanager ─────────────────────────────────────────────────────
  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  // ─── Daftarkan periodic sync task ────────────────────────────────────────
  static Future<void> scheduleSync({int intervalMinutes = 60}) async {
    // Simpan interval ke prefs
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyInterval, intervalMinutes);

    // Cancel task lama biar tidak double-schedule
    await Workmanager().cancelByTag(_kSyncTaskTag);

    // Android minimum interval: 15 menit sesuai OS constraint
    final effectiveInterval = intervalMinutes < 15 ? 15 : intervalMinutes;

    await Workmanager().registerPeriodicTask(
      _kSyncTaskName,
      _kSyncTaskName,
      tag: _kSyncTaskTag,
      frequency: Duration(minutes: effectiveInterval),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 5),
    );

    debugPrint('NotifSync: scheduled every $effectiveInterval minutes');
  }

  // ─── Batalkan semua scheduled sync ──────────────────────────────────────
  static Future<void> cancelSync() async {
    await Workmanager().cancelByTag(_kSyncTaskTag);
    debugPrint('NotifSync: cancelled');
  }

  // ─── Ambil interval tersimpan ────────────────────────────────────────────
  static Future<int> getSavedInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKeyInterval) ?? 60;
  }

  // ─── Logika sync utama (dipanggil Workmanager & manual trigger) ──────────
  static Future<Map<String, dynamic>> syncToFirestore() async {
    int uploaded = 0;
    String status = 'success';

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return {'status': 'no_user', 'uploaded': 0};

      final unsynced = await NotifLocalDbService.getUnsynced(limit: 100);
      if (unsynced.isEmpty) return {'status': 'nothing_to_sync', 'uploaded': 0};

      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('captured_notifications');

      // Batch write untuk efisiensi (max 500 per batch)
      final batch = FirebaseFirestore.instance.batch();
      final syncedIds = <String>[];

      for (final notif in unsynced) {
        final docRef = collection.doc(notif.id);
        batch.set(docRef, notif.toFirestoreMap(), SetOptions(merge: true));
        syncedIds.add(notif.id);
      }

      await batch.commit();
      await NotifLocalDbService.markSynced(syncedIds);
      uploaded = syncedIds.length;

      // Cleanup: hapus yang sudah synced lebih dari 7 hari
      _cleanupOldSynced();

      debugPrint('NotifSync: uploaded $uploaded notifications');
    } catch (e) {
      status = 'error: $e';
      debugPrint('NotifSync error: $e');
    }

    return {'status': status, 'uploaded': uploaded};
  }

  // ─── Hapus data synced yang sudah lebih dari 7 hari dari SQLite ──────────
  static void _cleanupOldSynced() {
    NotifLocalDbService.deleteOldSynced(olderThanDays: 7);
  }
}
