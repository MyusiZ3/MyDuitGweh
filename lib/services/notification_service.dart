import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      print('Timezone init error: $e');
    }

    if (Platform.isAndroid) {
      final androidPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Minta izin notifikasi (Android 13+)
      await androidPlugin?.requestNotificationsPermission();

      // Minta izin exact alarm (Android 12+)
      await androidPlugin?.requestExactAlarmsPermission();

      // Bikin channel dengan importance MAX agar muncul heads-up / pop-up
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'daily_reminder_channel',
        'Pengingat Harian',
        description: 'Notifikasi pengingat jurnal harian keuangan',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await androidPlugin?.createNotificationChannel(channel);

      const AndroidNotificationChannel broadcastChannel =
          AndroidNotificationChannel(
        'broadcast_channel',
        'Pesan Broadcast',
        description: 'Notifikasi pesan penting dari admin',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await androidPlugin?.createNotificationChannel(broadcastChannel);
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  /// Jadwalkan notifikasi harian pada jam & menit tertentu
  Future<void> scheduleDailyReminder({int hour = 20, int minute = 0}) async {
    try {
      // Batalkan semua notifikasi lama dulu
      await _notificationsPlugin.cancelAll();

      // Hitung waktu terjadwal berikutnya
      final tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);

      // Gunakan zonedSchedule dengan matchDateTimeComponents.time
      // agar notifikasi BERULANG SETIAP HARI pada jam yang sama
      await _notificationsPlugin.zonedSchedule(
        101,
        'Waktunya Catat Jurnal! 💰',
        'Yuk catat pengeluaranmu hari ini agar dompet tetap aman!',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder_channel',
            'Pengingat Harian',
            channelDescription: 'Notifikasi pengingat jurnal harian keuangan',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            showWhen: true,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.public,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      // Tampilkan notifikasi konfirmasi langsung (opsional)
      final String jamStr =
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      await _notificationsPlugin.show(
        100,
        'Pengingat Aktif! 🔔',
        'Kami akan mengingatkanmu setiap hari jam $jamStr.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder_channel',
            'Pengingat Harian',
            channelDescription: 'Notifikasi pengingat jurnal harian keuangan',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );

      print('Notification Scheduled Successfully for $jamStr');
    } catch (e) {
      print('Critical Notification Error: $e');
    }
  }

  /// Hitung kapan waktu terjadwal berikutnya
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Kalau jamnya sudah lewat hari ini, jadwalkan untuk besok
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Tampilkan notifikasi instan (untuk Broadcast)
  Future<void> showInstant(
      {int id = 0, required String title, required String body}) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'broadcast_channel',
        'Pesan Broadcast',
        channelDescription: 'Notifikasi pesan penting dari admin',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _notificationsPlugin.show(
        id,
        title,
        body,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
      );
    } catch (e) {
      print('Error showing instant notification: $e');
    }
  }
}
