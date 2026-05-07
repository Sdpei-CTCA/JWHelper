import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (response) {});
    _initialized = true;
  }

  Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('class_reminder_enabled') ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('class_reminder_enabled', value);
  }

  Future<void> scheduleClassReminders({
    required List<ScheduleItem> schedule,
    required DateTime startDay,
    String? campus, // passed to determine time
  }) async {
    if (!_initialized) await init();

    // Clear previous scheduled notifications
    await flutterLocalNotificationsPlugin.cancelAll();

    if (!(await isEnabled)) {
      return;
    }
    
    // get campus if not provided
    if (campus == null) {
      final prefs = await SharedPreferences.getInstance();
      campus = prefs.getString('campus') ?? '济南';
    }

    final now = DateTime.now();
    int scheduledCount = 0;

    for (var item in schedule) {
      if (scheduledCount >= 60) break; // iOS limit is 64, leave some buffer

      for (int week = item.weekStart; week <= item.weekEnd; week++) {
        // Calculate date for this specific class
        final daysToAdd = (week - 1) * 7 + item.dayIndex;
        final classBaseDate = startDay.add(Duration(days: daysToAdd));

        final timeStr = _getPeriodStartTime(item.startUnit, campus, classBaseDate);
        if (timeStr == null || timeStr.isEmpty) continue;

        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        var classDateTime = DateTime(
          classBaseDate.year,
          classBaseDate.month,
          classBaseDate.day,
          hour,
          minute,
        );

        // Reminder 10 mins before
        final reminderTime = classDateTime.subtract(const Duration(minutes: 10));

        if (reminderTime.isAfter(now) &&
            reminderTime.isBefore(now.add(const Duration(days: 14)))) {
          
          await _scheduleNotification(
            id: (reminderTime.millisecondsSinceEpoch ~/ 1000).remainder(100000), // Randomish ID that is max 32bit int
            title: '上课提醒',
            body: '${item.name} 还有10分钟在 ${item.classroom} 上课，不要迟到哦！',
            scheduledDate: reminderTime,
          );
          scheduledCount++;
          if (scheduledCount >= 60) break;
        }
      }
    }
    debugPrint('Scheduled $scheduledCount class reminders.');
  }

  String? _getPeriodStartTime(int period, String campus, DateTime targetDate) {
    if (campus == '济南') {
      switch (period) {
        case 1: return "08:00";
        case 2: return "08:50";
        case 3: return "10:00";
        case 4: return "10:50";
        case 5: return "13:30";
        case 6: return "14:20";
        case 7: return "15:30";
        case 8: return "16:20";
        case 9: return "18:00";
        case 10: return "18:50";
        case 11: return "20:00";
        case 12: return "20:50";
        default: return null;
      }
    } else {
      // 日照校区
      // 判断是否夏令时: 5月1日至10月1日
      bool isSummer = false;
      if (targetDate.month > 5 && targetDate.month < 10) {
        isSummer = true;
      } else if (targetDate.month == 5 || targetDate.month == 10) {
        isSummer = targetDate.month == 5; 
      }

      switch (period) {
        case 1: return "08:00";
        case 2: return "08:50";
        case 3: return "10:00";
        case 4: return "10:50";
        case 5: return isSummer ? "14:30" : "14:00";
        case 6: return isSummer ? "15:20" : "14:50";
        case 7: return isSummer ? "16:30" : "16:00";
        case 8: return isSummer ? "17:20" : "16:50";
        case 9: return "19:00";
        case 10: return "19:50";
        case 11: return "20:40";
        case 12: return "21:30";
        default: return null;
      }
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'class_reminder_channel',
          '上课提醒',
          channelDescription: '课前十分钟提醒',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    if (!_initialized) await init();

    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'debug_reminder_channel',
          '测试提醒',
          channelDescription: '测试发送的通知',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }
}