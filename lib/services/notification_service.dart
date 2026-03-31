import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      print('Timezone init error: $e');
    }
    
    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      await androidPlugin?.requestNotificationsPermission();
      
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel', 
        'Penting',
        description: 'Channel untuk notifikasi mendesak',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      
      await androidPlugin?.createNotificationChannel(channel);
    }

    const AndroidInitializationSettings initializationSettingsAndroid = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = 
        InitializationSettings(android: initializationSettingsAndroid);
    
    await _notificationsPlugin.initialize(initializationSettings);
  }


  Future<void> scheduleDailyReminder({int hour = 20, int minute = 0}) async {
    try {
      await _notificationsPlugin.cancelAll();

      // Gunakan periodicallyShow sebagai metode PALING STABIL
      await _notificationsPlugin.periodicallyShow(
        101,
        'Waktunya Catat Jurnal! 💰',
        'Yuk catat pengeluaranmu hari ini agar dompet tetap aman!',
        RepeatInterval.daily,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'Penting',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
          ),
        ),
        // Hapus androidScheduleMode karena versinya tidak dukung 'relaxed'
      );
      
      await _notificationsPlugin.show(
        100, 
        'Pengingat Aktif! 🔔', 
        'Kami akan mengingatkanmu setiap hari.', 
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'Penting',
            importance: Importance.low,
          )
        )
      );
      
      print('Notification Scheduled Successfully');
    } catch (e) {
      print('Critical Notification Error: $e');
    }
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
