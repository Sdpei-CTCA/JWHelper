import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:JWHelper/core/constants/class_schedule.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

class WidgetService {
  // Use group ID for iOS if needed, usually configured in Xcode
  static const String appGroupId = 'group.com.jwhelper.shared';

  static bool get _isHomeWidgetSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static Future<void> init() async {
    if (!_isHomeWidgetSupported) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } on MissingPluginException {
      // Ignore on platforms where plugin methods are not implemented.
    }
  }

  static Future<void> updateProgressWidget({
    required String gpa,
    required String majorExtraCredits,
    required String earnedCredits,
    required String requiredCredits,
  }) async {
    if (!_isHomeWidgetSupported) return;
    await HomeWidget.saveWidgetData<String>('gpa', gpa);
    await HomeWidget.saveWidgetData<String>(
        'major_extra_credits', majorExtraCredits);
    await HomeWidget.saveWidgetData<String>('earned_credits', earnedCredits);
    await HomeWidget.saveWidgetData<String>(
        'required_credits', requiredCredits);
    await HomeWidget.saveWidgetData<String>(
      'widget_last_updated',
      DateTime.now().toIso8601String(),
    );

    await HomeWidget.updateWidget(
      name: 'ProgressWidgetProvider',
      iOSName: 'ProgressWidget',
    );
  }

  static Future<void> setWidgetDebugEnabled(bool enabled) async {
    if (!_isHomeWidgetSupported) return;
    await HomeWidget.saveWidgetData<bool>('widget_debug_enabled', enabled);
    await HomeWidget.saveWidgetData<String>(
      'widget_last_updated',
      DateTime.now().toIso8601String(),
    );
    await HomeWidget.updateWidget(
      name: 'ProgressWidgetProvider',
      iOSName: 'ProgressWidget',
    );
    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetProvider',
      iOSName: 'ScheduleWidget',
    );
  }

  static Future<void> updateScheduleWidget(List<ScheduleItem> allItems,
      {int currentWeek = 0, String? campus}) async {
    if (!_isHomeWidgetSupported) return;
    final widgetCampus = ClassSchedule.normalizeCampus(campus);
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    // ScheduleItem dayIndex: 0=Mon, 6=Sun
    // DateTime.weekday: 1=Mon, 7=Sun
    final todayIndex = now.weekday - 1;

    final todayItems =
        _itemsForDay(allItems, dayIndex: todayIndex, currentWeek: currentWeek);
    final shouldShowNextDay = todayItems.isNotEmpty &&
        todayItems.every((item) => _isClassPassed(item, now, widgetCampus));

    DateTime displayDate = todayDate;
    int displayDayIndex = todayIndex;
    int displayWeek = currentWeek;
    List<ScheduleItem> displayItems = todayItems;

    if (shouldShowNextDay) {
      displayDate = todayDate.add(const Duration(days: 1));
      displayDayIndex = (todayIndex + 1) % 7;
      if (todayIndex == 6 && currentWeek > 0) {
        // Sunday -> Monday crosses into next academic week.
        displayWeek = currentWeek + 1;
      }
      displayItems = _itemsForDay(allItems, dayIndex: displayDayIndex, currentWeek: displayWeek);
    }

    // Serialize to JSON（附带解析后的时间信息，见 encodeScheduleItems）
    final jsonString = encodeScheduleItems(displayItems, widgetCampus);
    await HomeWidget.saveWidgetData<String>('today_schedule', jsonString);
    await HomeWidget.saveWidgetData<String>(
        'today_date', "${displayDate.month}月${displayDate.day}日");
    await HomeWidget.saveWidgetData<String>(
        'schedule_date_iso', _toIsoDate(displayDate));
    await HomeWidget.saveWidgetData<String>('current_week', "第$displayWeek周");
    // 不再下发 campus：时间解析已在本方法完成（payload 已含 timeRange/endTime），
    // 原生与小组件端不再需要本地作息表。
    await HomeWidget.saveWidgetData<String>(
      'widget_last_updated',
      DateTime.now().toIso8601String(),
    );

    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetProvider',
      iOSName: 'ScheduleWidget',
    );
  }

  /// 将课程序列化为小组件展示用的 JSON 字符串。
  ///
  /// 每条记录在原始字段（name/teacher/classroom/startUnit/endUnit/dayIndex 等）
  /// 之外，附加两个由 [ClassSchedule] 解析后的时间字段：
  /// * `timeRange` —— 展示用，`"HH:mm - HH:mm"`；该校区的该节次无时间时为 `""`；
  /// * `endTime`   —— 判定用，`"HH:mm"`；该校区的该节次无时间时为 `""`。
  ///
  /// 由 Dart 侧统一解析后随数据下发，Android / iOS 小组件端不再维护本地作息表，
  /// 三端时间边界因此完全一致（例如济南第 10 节缺行、日照第 10 节为 17:15）。
  /// 空字符串表示“无时间信息”：端上会保持课程可见，不做“已上完”判定。
  @visibleForTesting
  static String encodeScheduleItems(List<ScheduleItem> items, String? campus) {
    final widgetCampus = ClassSchedule.normalizeCampus(campus);
    final payload = items.map((item) {
      final start = ClassSchedule.startTime(widgetCampus, item.startUnit);
      final end = ClassSchedule.endTime(widgetCampus, item.endUnit);
      return <String, dynamic>{
        ...item.toJson(),
        'timeRange': (start != null && end != null) ? '$start - $end' : '',
        'endTime': end ?? '',
      };
    }).toList();
    return jsonEncode(payload);
  }

  static List<ScheduleItem> _itemsForDay(
    List<ScheduleItem> allItems, {
    required int dayIndex,
    required int currentWeek,
  }) {
    final result = allItems.where((item) {
      if (item.dayIndex != dayIndex) return false;
      return _isInCurrentWeek(item, currentWeek);
    }).toList();
    result.sort((a, b) => a.startUnit.compareTo(b.startUnit));
    return result;
  }

  static bool _isInCurrentWeek(ScheduleItem item, int currentWeek) {
    if (currentWeek <= 0) return true;
    if (item.weekStart > 0 && item.weekEnd > 0) {
      return currentWeek >= item.weekStart && currentWeek <= item.weekEnd;
    }
    return true;
  }

  static bool _isClassPassed(ScheduleItem item, DateTime now, String campus) {
    final endTime = ClassSchedule.endTime(campus, item.endUnit);
    if (endTime == null) return false;
    final parts = endTime.split(':');
    final endMinutes =
        (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    final nowMinutes = now.hour * 60 + now.minute;
    return nowMinutes >= endMinutes;
  }

  static String _toIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
