import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../models/schedule_item.dart';

class WidgetService {
  // Use group ID for iOS if needed, usually configured in Xcode
  static const String appGroupId = 'group.com.jwhelper.shared'; 

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(appGroupId);
  }
  
  static Future<void> updateProgressWidget({
    required String gpa,
    required String majorExtraCredits,
    required String earnedCredits,
    required String requiredCredits,
  }) async {
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
    final now = DateTime.now();
    // ScheduleItem dayIndex: 0=Mon, 6=Sun
    // DateTime.weekday: 1=Mon, 7=Sun
    final todayIndex = now.weekday - 1;
    final tomorrowIndex = (todayIndex + 1) % 7; // Handles Sunday (6) -> Monday (0)

    List<ScheduleItem> filterForDay(int dayIndex, {int? weekOverride}) {
      final week = weekOverride ?? currentWeek;
      final items = allItems.where((item) {
        if (item.dayIndex != dayIndex) return false;
        if (week > 0) {
          if (item.weekStart > 0 && item.weekEnd > 0) {
            if (week < item.weekStart || week > item.weekEnd) return false;
          }
        }
        return true;
      }).toList();
      items.sort((a, b) => a.startUnit.compareTo(b.startUnit));
      return items;
    }

    final todayItems = filterForDay(todayIndex);
    final tomorrow = now.add(const Duration(days: 1));
    // When tomorrow is Monday (tomorrowIndex == 0), it belongs to the next academic week
    final tomorrowWeek = (tomorrowIndex == 0 && currentWeek > 0) ? currentWeek + 1 : currentWeek;
    final tomorrowItems = filterForDay(tomorrowIndex, weekOverride: tomorrowWeek);

    // Save today's schedule
    final todayJson = jsonEncode(todayItems.map((e) => e.toJson()).toList());
    await HomeWidget.saveWidgetData<String>('today_schedule', todayJson);
    await HomeWidget.saveWidgetData<String>('today_date', "${now.month}月${now.day}日");

    // Save tomorrow's schedule so the widget can fall back to it when today is done
    final tomorrowJson = jsonEncode(tomorrowItems.map((e) => e.toJson()).toList());
    await HomeWidget.saveWidgetData<String>('tomorrow_schedule', tomorrowJson);
    await HomeWidget.saveWidgetData<String>('tomorrow_date', "${tomorrow.month}月${tomorrow.day}日");

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
}
