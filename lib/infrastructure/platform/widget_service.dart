import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:JWHelper/app/domain/schedule_week_context.dart';
import 'package:JWHelper/features/exam/domain/exam.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';
import 'package:JWHelper/infrastructure/platform/widget_schedule_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WidgetService {
  // Use group ID for iOS if needed, usually configured in Xcode
  static String get appGroupId => kDebugMode
      ? 'group.com.jwhelper.shared.dev'
      : 'group.com.jwhelper.shared';
  static const String displayModeSchedule = 'schedule';
  static const String displayModeExam = 'exam';

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
    String? startDay,
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

    final prefs = await SharedPreferences.getInstance();
    final campus = prefs.getString('campus') ?? '济南';
    await _saveScheduleWidgetData(
      allItems: allItems,
      currentWeek: currentWeek,
      campus: campus,
      startDay: startDay,
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
    required String campus,
    String? startDay,
  }) async {
    final now = DateTime.now();
    final resolved = WidgetScheduleResolver.resolveDisplayDay(
      allItems: allItems,
      currentWeek: currentWeek,
      now: now,
      campus: campus,
      startDay: startDay,
    );
    final displayDate = resolved.displayDate;
    final displayWeek = resolved.displayWeek;
    final displayItems = resolved.displayItems;

    final jsonString = jsonEncode(displayItems.map((e) => e.toJson()).toList());
    final weekJson = jsonEncode(allItems.map((e) => e.toJson()).toList());
    await HomeWidget.saveWidgetData<String>(
      'widget_display_mode',
      displayModeSchedule,
    );
    await HomeWidget.saveWidgetData<String>('today_schedule', jsonString);
    await HomeWidget.saveWidgetData<String>('week_schedule', weekJson);
    await HomeWidget.saveWidgetData<String>(
      'widget_current_week',
      displayWeek.toString(),
    );
    await HomeWidget.saveWidgetData<String>('widget_campus', campus);
    await HomeWidget.saveWidgetData<String>(
      'schedule_start_day',
      startDay ?? '',
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_week_anchor_date',
      _toIsoDate(now),
    );
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

  static String _toIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
