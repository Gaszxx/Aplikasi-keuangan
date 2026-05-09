import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  // Singleton pattern agar service ini hanya ada 1 di seluruh aplikasi
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Inisialisasi zona waktu Indonesia
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    // Pengaturan icon notifikasi untuk Android (Pastikan Anda punya icon mipmap/ic_launcher)
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Pengaturan untuk iOS
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notifikasi ditekan: ${response.payload}');
        // Nanti kita bisa arahkan Bos ke layar hutang saat notifikasi diklik
      },
    );
  }

  // --- FUNGSI THE KILLER: JADWALKAN ALARM H-7 ---
  Future<void> scheduleDebtReminder({
    required int id,
    required String creditorName,
    required double amount,
    required DateTime dueDate,
  }) async {
    // Hitung waktu H-7 dari tanggal jatuh tempo (Set jam 08:00 Pagi)
    DateTime reminderDate = dueDate.subtract(const Duration(days: 7));
    DateTime scheduledTime = DateTime(reminderDate.year, reminderDate.month, reminderDate.day, 8, 0);

    // Jika H-7 sudah lewat dari hari ini, kita tidak usah setel alarm H-7
    if (scheduledTime.isBefore(DateTime.now())) {
      debugPrint("Waktu H-7 sudah lewat, alarm dilewati.");
      return; 
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id, // ID unik agar alarm tidak bertabrakan
      '🔔 Pengingat Tagihan: $creditorName',
      'Siapkan dana! Tagihan Anda akan jatuh tempo dalam 7 hari.',
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'debt_reminder_channel',
          'Pengingat Tagihan',
          channelDescription: 'Alarm H-7 untuk tagihan dan cicilan',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFE65100), // Warna Orange
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Tetap bunyi meski HP sleep
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, 
    );
    
    debugPrint("✅ Alarm H-7 berhasil disetel untuk $creditorName pada $scheduledTime");
  }
}