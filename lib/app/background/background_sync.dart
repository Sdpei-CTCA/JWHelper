import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:JWHelper/app/cache/offline_cache_keys.dart';
import 'package:JWHelper/features/attendance/data/attendance_credential_store.dart';
import 'package:JWHelper/features/attendance/data/sso_token_service.dart';
import 'package:JWHelper/features/notice/data/notice_cache_store.dart';
import 'package:JWHelper/features/notice/data/notice_source.dart';
import 'package:JWHelper/features/notice/data/pubinfo_notice_source.dart';
import 'package:JWHelper/features/notice/domain/notice_item.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';
import 'package:JWHelper/infrastructure/notifications/notification_service.dart';

/// 后台任务标识。iOS 的 `BGTaskSchedulerPermittedIdentifiers` 必须包含它。
const String backgroundSyncUniqueName = 'edu.sdpei.JWSystem.backgroundSync';
const String backgroundSyncTaskName = 'jwhelperSync';

/// 后台任务入口。必须是顶层函数，并带 `vm:entry-point`，
/// 否则 release 包裁剪后后台 isolate 找不到它。
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await BackgroundSync.runOnce();
    } catch (e, s) {
      debugPrint('Background sync failed: $e\n$s');
    }
    // 始终返回 true：网络类失败交给下一次周期，不要让系统立刻重试刷屏。
    return true;
  });
}

/// 后台轮询：通知公告检查新通知、课程提醒续排未来两周。
///
/// 说明两点边界：
/// 1. 定时由系统调度，实际间隔可能被拉长（尤其国产 ROM 的省电策略）；
/// 2. iOS 的 BGAppRefreshTask 是「机会式」的，不保证按小时执行。
class BackgroundSync {
  static const String noticePollingKey = 'background_notice_polling';
  static const String classPollingKey = 'background_class_polling';

  /// WorkManager 只在 Android / iOS 上有实现。
  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static Future<bool> isNoticePollingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(noticePollingKey) ?? false;
  }

  static Future<bool> isClassPollingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(classPollingKey) ?? false;
  }

  static Future<void> setNoticePollingEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(noticePollingKey, value);
    await reschedule();
  }

  static Future<void> setClassPollingEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(classPollingKey, value);
    await reschedule();
  }

  /// App 启动时调用一次：注册回调并按开关状态安排/取消周期任务。
  static Future<void> initialize() async {
    if (!isSupported) return;
    try {
      await Workmanager().initialize(backgroundSyncDispatcher);
      await reschedule();
    } catch (e) {
      debugPrint('Background sync init failed: $e');
    }
  }

  /// 任一开关打开就注册周期任务，全关就取消。
  static Future<void> reschedule() async {
    if (!isSupported) return;

    final prefs = await SharedPreferences.getInstance();
    final enabled = (prefs.getBool(noticePollingKey) ?? false) ||
        (prefs.getBool(classPollingKey) ?? false);

    try {
      if (!enabled) {
        await Workmanager().cancelByUniqueName(backgroundSyncUniqueName);
        return;
      }

      await Workmanager().registerPeriodicTask(
        backgroundSyncUniqueName,
        backgroundSyncTaskName,
        // Android 最小 15 分钟；一小时对「通知」这种非实时场景足够省电。
        frequency: const Duration(hours: 1),
        initialDelay: const Duration(minutes: 5),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
    } catch (e) {
      debugPrint('Background sync scheduling failed: $e');
    }
  }

  /// 后台任务主体。两个开关都关时直接返回。
  static Future<void> runOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final noticeEnabled = prefs.getBool(noticePollingKey) ?? false;
    final classEnabled = prefs.getBool(classPollingKey) ?? false;
    if (!noticeEnabled && !classEnabled) return;

    // 先排课程提醒：它会撤销上一批课前提醒，放在通知之后会把新通知提醒清掉。
    if (classEnabled) {
      await _refreshClassReminders(prefs);
    }
    if (noticeEnabled) {
      await _pollNotices();
    }
  }

  static Future<void> _pollNotices() async {
    final username = await AttendanceCredentialStore.readUsername();
    var tokens = await AttendanceCredentialStore.readTokens();
    if (tokens.isEmpty) {
      final renewed = await _relogin();
      if (renewed == null) return;
      tokens = renewed;
    }

    final source = PubinfoNoticeSource()
      ..updateCredentials(
        userToken: tokens.userToken,
        ctTicket: tokens.ctTicket,
        appCtTicket: tokens.appCtTicket,
      );

    List<NoticeItem> fetched;
    try {
      fetched = await source.fetchList();
    } on NoticeException catch (e) {
      if (e.kind != NoticeErrorKind.authFailed) {
        debugPrint('Background notice fetch failed: ${e.message}');
        return;
      }
      final renewed = await _relogin();
      if (renewed == null) return;
      source.updateCredentials(
        userToken: renewed.userToken,
        ctTicket: renewed.ctTicket,
        appCtTicket: renewed.appCtTicket,
      );
      fetched = await source.fetchList();
    }

    if (fetched.isEmpty) return;

    final store = NoticeCacheStore();
    final known = await store.readKnownIds(username);
    final fresh = fetched.where((e) => !known.contains(e.id)).toList();

    await store.saveList(username, fetched);
    await store.saveKnownIds(
      username,
      {...known, ...fetched.map((e) => e.id)},
    );

    // 首次运行（还没记录过任何通知）只入库，不弹提醒。
    debugPrint('Background notice: fetched=${fetched.length}, new=${fresh.length}');
    if (known.isEmpty || fresh.isEmpty) return;
    if (!await store.readReminderEnabled()) return;

    final today = _dayKey(DateTime.now());
    if (await store.readLastNotifyDay() == today) return;

    await NotificationService().showNoticeSummary(
      count: fresh.length,
      latestTitle: fresh.first.title,
    );
    await store.saveLastNotifyDay(today);
    debugPrint('Background notice: notified ${fresh.length} new items');
  }

  /// 用缓存的课表重排未来两周的上课提醒，让 14 天窗口一直往后滚。
  static Future<void> _refreshClassReminders(SharedPreferences prefs) async {
    if (!(prefs.getBool('class_reminder_enabled') ?? true)) return;

    final username = prefs.getString('username') ?? '';
    if (username.isEmpty) return;

    final raw = prefs.getString(OfflineCacheKeys.schedule(username));
    final startDayRaw =
        prefs.getString(OfflineCacheKeys.scheduleStartDay(username));
    if (raw == null || raw.isEmpty || startDayRaw == null) return;

    final startDay = DateTime.tryParse(startDayRaw);
    if (startDay == null) return;

    final List<ScheduleItem> items;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      items = decoded
          .whereType<Map>()
          .map((e) => ScheduleItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (e) {
      debugPrint('Background class reminder parse failed: $e');
      return;
    }
    if (items.isEmpty) return;

    await NotificationService().scheduleClassReminders(
      schedule: items,
      startDay: startDay,
      campus: prefs.getString('campus_$username') ??
          prefs.getString('campus') ??
          '济南',
    );
    debugPrint('Background class reminders refreshed');
  }

  /// 用保存的智慧山体账号密码重新换票。
  static Future<AttendanceSsoTokens?> _relogin() async {
    final username = await AttendanceCredentialStore.readUsername();
    final password = await AttendanceCredentialStore.readPassword();
    if (username.isEmpty || password.isEmpty) return null;

    final session = await SsoTokenService().loginAndFetchToken(
      username: username,
      password: password,
    );
    if (session == null || session.userToken.isEmpty) return null;

    final tokens = AttendanceSsoTokens(
      userToken: session.userToken,
      ctTicket: session.ctTicket,
      appCtTicket: session.appCtTicket,
    );
    await AttendanceCredentialStore.saveTokens(tokens);
    return tokens;
  }

  static String _dayKey(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '${time.year}-$month-$day';
  }
}
