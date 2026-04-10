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

  final Map<int, String> _periodStartTimes = {
    1: '08:00',
    2: '08:55',
    3: '10:00',
    4: '10:55',
    5: '13:30',
    6: '14:25',
    7: '15:20',
    8: '16:25',
    9: '17:20',
    10: '18:30',
    11: '19:25',
    12: '20:20',
  };

  Future<void> scheduleClassReminders({
    required List<ScheduleItem> schedule,
    required DateTime startDay,
  }) async {
    if (!_initialized) await init();

    // Clear previous scheduled notifications
    await flutterLocalNotificationsPlugin.cancelAll();

    if (!(await isEnabled)) {
      return;
    }

    final now = DateTime.now();
    int scheduledCount = 0;

    for (var item in schedule) {
      if (scheduledCount >= 60) break; // iOS limit is 64, leave some buffer

      for (int week = item.weekStart; week <= item.weekEnd; week++) {
        // Calculate date for this specific class
        final daysToAdd = (week - 1) * 7 + item.dayIndex;
        final classBaseDate = startDay.add(Duration(days: daysToAdd));

        final timeStr = _periodStartTimes[item.startUnit];
        if (timeStr == null) continue;

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
}