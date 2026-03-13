import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

class WidgetService {
  // Use group ID for iOS if needed, usually configured in Xcode
  static const String appGroupId = 'group.com.jwhelper.shared'; 
  static const Map<int, int> _periodEndMinutes = {
    1: 8 * 60 + 45,
    2: 9 * 60 + 40,
    3: 10 * 60 + 45,
    4: 11 * 60 + 40,
    5: 14 * 60 + 15,
    6: 15 * 60 + 10,
    7: 16 * 60 + 5,
    8: 17 * 60 + 10,
    9: 18 * 60 + 5,
    10: 19 * 60 + 15,
    11: 20 * 60 + 10,
    12: 21 * 60 + 5,
  };

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
    await HomeWidget.saveWidgetData<String>('major_extra_credits', majorExtraCredits);
    await HomeWidget.saveWidgetData<String>('earned_credits', earnedCredits);
    await HomeWidget.saveWidgetData<String>('required_credits', requiredCredits);
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

  static Future<void> updateScheduleWidget(List<ScheduleItem> allItems, {int currentWeek = 0}) async {
    if (!_isHomeWidgetSupported) return;
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    // ScheduleItem dayIndex: 0=Mon, 6=Sun
    // DateTime.weekday: 1=Mon, 7=Sun
    final todayIndex = now.weekday - 1; 

    final todayItems = _itemsForDay(allItems, dayIndex: todayIndex, currentWeek: currentWeek);
    final shouldShowNextDay = todayItems.isNotEmpty && todayItems.every((item) => _isClassPassed(item, now));

    DateTime displayDate = todayDate;
    int displayDayIndex = todayIndex;
    List<ScheduleItem> displayItems = todayItems;

    if (shouldShowNextDay) {
      displayDate = todayDate.add(const Duration(days: 1));
      displayDayIndex = (todayIndex + 1) % 7;
      displayItems = _itemsForDay(allItems, dayIndex: displayDayIndex, currentWeek: currentWeek);
    }

    // Serialize to JSON
    final jsonString = jsonEncode(displayItems.map((e) => e.toJson()).toList());
    await HomeWidget.saveWidgetData<String>('today_schedule', jsonString);
    await HomeWidget.saveWidgetData<String>('today_date', "${displayDate.month}月${displayDate.day}日");
    await HomeWidget.saveWidgetData<String>('schedule_date_iso', _toIsoDate(displayDate));
    await HomeWidget.saveWidgetData<String>('current_week', "第$currentWeek周");
    await HomeWidget.saveWidgetData<String>(
      'widget_last_updated',
      DateTime.now().toIso8601String(),
    );

    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetProvider',
      iOSName: 'ScheduleWidget',
    );
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

  static bool _isClassPassed(ScheduleItem item, DateTime now) {
    final endMinutes = _periodEndMinutes[item.endUnit];
    if (endMinutes == null) return false;
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
