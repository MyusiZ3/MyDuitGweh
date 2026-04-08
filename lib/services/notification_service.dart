import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:ui';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      print('Timezone init error: $e');
      // Fallback ke Asia/Jakarta jika gagal deteksi otomatis
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      } catch (_) {
        // Fallback terakhir ke UTC jika semua gagal
        tz.setLocalLocation(tz.getLocation('UTC'));
      }
    }

    if (Platform.isAndroid) {
      final androidPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Minta izin notifikasi (Android 13+)
      await androidPlugin?.requestNotificationsPermission();

      // Channel untuk Daily Reminder
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'daily_jurnal_paling_penting_v3',
        'Pengingat Jurnal',
        description: 'Notifikasi pengingat harian tercinta',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await androidPlugin?.createNotificationChannel(channel);

      // Channel untuk Broadcast
      const AndroidNotificationChannel broadcastChannel =
          AndroidNotificationChannel(
        'broadcast_channel_v2',
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
        AndroidInitializationSettings('notif_icon');

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

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
         // Placeholder for notification interaction
         print('Notification tapped: ${details.payload}');
      },
    );
  }

  /// Jadwalkan notifikasi harian pada jam & menit tertentu
  Future<void> scheduleDailyReminder(
      {int hour = 20, int minute = 0, bool showConfirmation = false}) async {
    try {
      // Batalkan hanya ID 101 (Daily Reminder), jangan cancelAll agar broadcast tidak hilang
      await _notificationsPlugin.cancel(101);

      // Hitung waktu terjadwal berikutnya
      final tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);

      // Cek izin exact alarm di Android untuk menghindari crash
      AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final bool? canScheduleExact = await androidPlugin?.canScheduleExactNotifications();
        if (canScheduleExact == false) {
          scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
        }
      }

      await _notificationsPlugin.zonedSchedule(
        101,
        'Its Timee! o((>ω< ))o ',
        'Yuk catat pengeluaranmu hari ini biaar dompet tetep aman!',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_jurnal_paling_penting_v3',
            'Pengingat Jurnal',
            channelDescription: 'Notifikasi pengingat jurnal harian keuangan',
            importance: Importance.max,
            priority: Priority.max,
            ticker: 'Waktunya mencatat!',
            playSound: true,
            enableVibration: true,
            showWhen: true,
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.public,
            icon: 'notif_icon',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      // Tampilkan notifikasi konfirmasi langsung
      final String jamStr =
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      if (showConfirmation) {
        await _notificationsPlugin.show(
          100,
          'Pengingat dah Aktif..!',
          'Kamu akan diingetin tiap hari jam $jamStr. (〜￣▽￣)〜',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'daily_jurnal_paling_penting_v3',
              'Daily Reminder',
              channelDescription: 'Reminds you to record transactions',
              importance: Importance.max,
              priority: Priority.max,
              icon: 'notif_icon',
              color: Color(0xFF007AFF),
              playSound: true,
              enableVibration: true,
            ),
          ),
        );
      }
    } catch (e) {
      print('Critical Notification Error: $e');
    }
  }

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

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<void> showInstant(
      {int id = 0, required String title, required String body}) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'broadcast_channel_v2',
        'Pesan Broadcast',
        channelDescription: 'Notifikasi pesan penting dari admin',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        playSound: true,
        icon: 'notif_icon',
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

  Future<void> scheduleBroadcast({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      // Pastikan ID positif
      final int safeId = id.abs();
      
      // Inisialisasi timezone jika dipanggil mendadak
      if (tz.local.name == 'UTC' && Platform.isAndroid) {
        // Double check init jika local belum terdeteksi sempurna
        try {
          final String? timeZoneName = await FlutterTimezone.getLocalTimezone();
          if (timeZoneName != null) {
            tz.setLocalLocation(tz.getLocation(timeZoneName));
          }
        } catch (_) {}
      }

      final tz.TZDateTime tzScheduledTime =
          tz.TZDateTime.from(scheduledTime, tz.local);

      // Jangan jadwalkan jika waktu sudah lewat
      if (tzScheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
        print('Broadcast skipped: scheduled time is in the past');
        return;
      }

      // Cek izin exact alarm di Android
      AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final bool? canScheduleExact = await androidPlugin?.canScheduleExactNotifications();
        if (canScheduleExact == false) {
          scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
        }
      }

      const androidDetails = AndroidNotificationDetails(
        'broadcast_channel_v2',
        'Pesan Broadcast',
        channelDescription: 'Notifikasi pesan penting dari admin',
        importance: Importance.max,
        priority: Priority.high, // Consistent with pop-up behavior
        showWhen: true,
        playSound: true,
        icon: 'notif_icon',
        color: Color(0xFF007AFF),
        category: AndroidNotificationCategory.status, // More appropriate for broadcasts
        fullScreenIntent: false, // Prevent activity start issues
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _notificationsPlugin.zonedSchedule(
        safeId,
        title,
        body,
        tzScheduledTime,
        const NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      
      print('Broadcast scheduled successfully with ID: $safeId at $tzScheduledTime');
    } catch (e) {
      print('Error scheduling broadcast: $e');
    }
  }

  Future<void> testNotification() async {
    await _notificationsPlugin.show(
      999,
      'TEST: Pop-up Cortisol! (〜￣▽￣)〜',
      'Jika muncul ini sebagai pop-up di atas layar, artinya konfigurasi sudah benar!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_jurnal_paling_penting_v3',
          'Pengingat Jurnal',
          channelDescription: 'Notifikasi pengingat harian tercinta',
          importance: Importance.max,
          priority: Priority.max,
          ticker: 'Test running...',
          playSound: true,
          icon: 'notif_icon',
          color: Color(0xFF007AFF),
          fullScreenIntent: false,
        ),
      ),
    );
  }
}

