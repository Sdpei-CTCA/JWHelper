import 'package:JWHelper/core/constants/period_time_table.dart';
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

  /// 点击上课提醒后要跳转的目标（由 app 层解析成具体 tab）。
  static const String attendancePayload = 'attendance';

  /// 点击「新通知」提醒后要跳转的目标（由 app 层打开通知中心）。
  static const String noticePayload = 'notice';

  /// 用户点击通知时回调 payload，由 app 层负责导航。
  ///
  /// 与 `ApiClient.onSessionExpired` 一样，用静态回调让基础设施层不必依赖
  /// 具体的页面与导航实现。
  static void Function(String? payload)? onNotificationSelected;

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

    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          onNotificationSelected?.call(response.payload);
        });
    _initialized = true;
  }

  /// 如果本次启动是用户点击通知触发的，返回该通知的 payload。
  ///
  /// 应用没在运行时点击通知会走冷启动，`onDidReceiveNotificationResponse`
  /// 不会触发，只能通过这里取回跳转目标。
  Future<String?> consumeLaunchPayload() async {
    if (!_initialized) await init();

    final launchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp != true) {
      return null;
    }

    return launchDetails?.notificationResponse?.payload;
  }

  /// 上课提醒的通知正文（含点击跳转提示）。
  static String buildClassReminderBody({
    required String courseName,
    required String classroom,
  }) {
    return '$courseName 还有10分钟在 $classroom 上课，不要迟到哦！点击可进入考勤签到';
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

    // 只撤销上一批「课前提醒」，不要 cancelAll —— 否则会把通知公告的提醒一起清掉。
    await _cancelScheduledClassReminders();

    if (!(await isEnabled)) {
      await _saveScheduledClassReminderIds(const []);
      return;
    }
    
    // get campus if not provided
    if (campus == null) {
      final prefs = await SharedPreferences.getInstance();
      campus = prefs.getString('campus') ?? '济南';
    }

    final now = DateTime.now();
    int scheduledCount = 0;
    final scheduledIds = <int>[];

    for (var item in schedule) {
      if (scheduledCount >= 60) break; // iOS limit is 64, leave some buffer

      for (int week = item.weekStart; week <= item.weekEnd; week++) {
        // Calculate date for this specific class
        final daysToAdd = (week - 1) * 7 + item.dayIndex;
        final classBaseDate = startDay.add(Duration(days: daysToAdd));

        final timeStr = PeriodTimeTable.periodStartTime(
          item.startUnit,
          campus: campus,
        );
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
          
          final id = (reminderTime.millisecondsSinceEpoch ~/ 1000).remainder(100000);
          await _scheduleNotification(
            id: id,
            title: '上课提醒',
            body: buildClassReminderBody(
              courseName: item.name,
              classroom: item.classroom,
            ),
            payload: attendancePayload,
            scheduledDate: reminderTime,
          );
          scheduledIds.add(id);
          scheduledCount++;
          if (scheduledCount >= 60) break;
        }
      }
    }

    await _saveScheduledClassReminderIds(scheduledIds);
    debugPrint('Scheduled $scheduledCount class reminders.');
  }

  static const String _scheduledIdsKey = 'class_reminder_notification_ids';

  /// 撤销「课前提醒」，不影响通知公告的提醒。
  ///
  /// 关闭课前提醒开关时用这个，别用 `cancelAll()`——那会把新通知提醒一起清掉。
  Future<void> cancelClassReminders() async {
    if (!_initialized) await init();
    await _cancelScheduledClassReminders();
  }

  /// 撤销上一批课前提醒（按记录下来的 id 逐个撤销）。
  Future<void> _cancelScheduledClassReminders() async {    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_scheduledIdsKey) ?? const [];
    for (final raw in ids) {
      final id = int.tryParse(raw);
      if (id == null) continue;
      await flutterLocalNotificationsPlugin.cancel(id: id);
    }
    await prefs.remove(_scheduledIdsKey);
  }

  Future<void> _saveScheduledClassReminderIds(List<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _scheduledIdsKey,
      ids.map((e) => '$e').toList(growable: false),
    );
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      payload: payload,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'class_reminder_channel',
          '上课提醒',
          channelDescription: '课前十分钟提醒',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          presentAlert: true,
          presentBadge: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// 新通知提醒：同类消息聚合成一条，避免一次装十条通知刷屏。
  ///
  /// 与上课提醒用不同渠道：重要性取默认值、不占用「闹钟」类别，这样用户可以在
  /// 系统设置里单独关掉它而不影响课前提醒。
  Future<void> showNoticeSummary({
    required int count,
    String? latestTitle,
  }) async {
    if (!_initialized) await init();

    final body = (latestTitle == null || latestTitle.isEmpty)
        ? '学校发布了 $count 条新通知，点击查看'
        : '$latestTitle${count > 1 ? ' 等 $count 条' : ''}，点击查看';

    await flutterLocalNotificationsPlugin.show(
      id: 9100,
      title: count > 1 ? '有 $count 条新通知' : '有 1 条新通知',
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'notice_channel',
          '通知公告',
          channelDescription: '学校发布新通知时提醒',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: true,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          presentAlert: true,
          presentBadge: true,
        ),
      ),
      payload: noticePayload,
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
          playSound: true,
          enableVibration: true,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          presentAlert: true,
          presentBadge: true,
        ),
      ),
      payload: payload,
    );
  }
}