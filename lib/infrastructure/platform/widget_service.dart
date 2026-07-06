import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:JWHelper/app/domain/schedule_week_context.dart';
import 'package:JWHelper/features/exam/domain/exam.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

class WidgetService {
  // Use group ID for iOS if needed, usually configured in Xcode
  static const String appGroupId = 'group.com.jwhelper.shared';
  static const String displayModeSchedule = 'schedule';
  static const String displayModeExam = 'exam';

  static const Map<int, int> _periodEndMinutes = {
    1: 8 * 60 + 45,
    2: 9 * 60 + 30,
    3: 10 * 60 + 45,
    4: 11 * 60 + 30,
    5: 14 * 60 + 15,
    6: 15 * 60,
    7: 16 * 60 + 15,
    8: 17 * 60,
    9: 19 * 60 + 45,
    10: 20 * 60 + 30,
  };

  static bool get _isHomeWidgetSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static List<Map<String, String>> examsToWidgetPayload(List<Exam> exams) {
    return exams
        .map((exam) => {
              'courseName': exam.courseName,
              'time': exam.time,
              'location': exam.location,
            })
        .toList();
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

  static Future<void> updateScheduleWidget(
    List<ScheduleItem> allItems, {
    int currentWeek = 0,
    List<Exam> upcomingExams = const [],
  }) async {
    if (!_isHomeWidgetSupported) return;

    final isExamPeriod =
        ScheduleWeekContext.isExamPeriod(allItems, currentWeek);
    if (isExamPeriod && upcomingExams.isNotEmpty) {
      await _saveExamWidgetData(upcomingExams);
      await HomeWidget.updateWidget(
        name: 'ScheduleWidgetProvider',
        iOSName: 'ScheduleWidget',
      );
      return;
    }

    await _saveScheduleWidgetData(
      allItems: allItems,
      currentWeek: currentWeek,
    );
    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetProvider',
      iOSName: 'ScheduleWidget',
    );
  }

  static Future<void> _saveExamWidgetData(List<Exam> upcomingExams) async {
    final payload = examsToWidgetPayload(upcomingExams);
    await HomeWidget.saveWidgetData<String>(
      'widget_display_mode',
      displayModeExam,
    );
    await HomeWidget.saveWidgetData<String>(
      'upcoming_exams',
      jsonEncode(payload),
    );
    final now = DateTime.now();
    await HomeWidget.saveWidgetData<String>(
      'today_date',
      '考试周',
    );
    await HomeWidget.saveWidgetData<String>(
      'schedule_date_iso',
      _toIsoDate(DateTime(now.year, now.month, now.day)),
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_last_updated',
      now.toIso8601String(),
    );
  }

  static Future<void> _saveScheduleWidgetData({
    required List<ScheduleItem> allItems,
    required int currentWeek,
  }) async {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final todayIndex = now.weekday - 1;

    final todayItems =
        _itemsForDay(allItems, dayIndex: todayIndex, currentWeek: currentWeek);
    final shouldShowNextDay = todayItems.isNotEmpty &&
        todayItems.every((item) => _isClassPassed(item, now));

    DateTime displayDate = todayDate;
    int displayDayIndex = todayIndex;
    int displayWeek = currentWeek;
    List<ScheduleItem> displayItems = todayItems;

    if (shouldShowNextDay) {
      displayDate = todayDate.add(const Duration(days: 1));
      displayDayIndex = (todayIndex + 1) % 7;
      if (todayIndex == 6 && currentWeek > 0) {
        displayWeek = currentWeek + 1;
      }
      displayItems = _itemsForDay(
        allItems,
        dayIndex: displayDayIndex,
        currentWeek: displayWeek,
      );
    }

    final jsonString = jsonEncode(displayItems.map((e) => e.toJson()).toList());
    await HomeWidget.saveWidgetData<String>(
      'widget_display_mode',
      displayModeSchedule,
    );
    await HomeWidget.saveWidgetData<String>('today_schedule', jsonString);
    await HomeWidget.saveWidgetData<String>(
      'upcoming_exams',
      '[]',
    );
    await HomeWidget.saveWidgetData<String>(
      'today_date',
      '${displayDate.month}月${displayDate.day}日',
    );
    await HomeWidget.saveWidgetData<String>(
      'schedule_date_iso',
      _toIsoDate(displayDate),
    );
    await HomeWidget.saveWidgetData<String>(
      'current_week',
      '第$displayWeek周',
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_last_updated',
      DateTime.now().toIso8601String(),
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
