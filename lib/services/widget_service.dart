import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../models/schedule_item.dart';

class WidgetService {
  // Use group ID for iOS if needed, usually configured in Xcode
  static const String appGroupId = 'group.edu.sdpei.JWSystem.widget'; 
  
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
    
    await HomeWidget.updateWidget(
      name: 'ProgressWidgetProvider',
      iOSName: 'ProgressWidget',
    );
  }

  static Future<void> updateScheduleWidget(List<ScheduleItem> allItems, {int currentWeek = 0}) async {
    final now = DateTime.now();
    // ScheduleItem dayIndex: 0=Mon, 6=Sun
    // DateTime.weekday: 1=Mon, 7=Sun
    final todayIndex = now.weekday - 1; 
    
    final todayItems = allItems.where((item) {
        if (item.dayIndex != todayIndex) return false;
        
        // If currentWeek is valid (>0), filter by week
        if (currentWeek > 0) {
           // Assuming weekStart/End 0 means valid for all? 
           // Or strictly adhering to ranges. Usually 1-20. 
           // Let's assume strict if set.
           if (item.weekStart > 0 && item.weekEnd > 0) {
              if (currentWeek < item.weekStart || currentWeek > item.weekEnd) return false;
           }
        }
        return true;
    }).toList();

    // Sort by start unit
    todayItems.sort((a, b) => a.startUnit.compareTo(b.startUnit));

    // Serialize to JSON
    final jsonString = jsonEncode(todayItems.map((e) => e.toJson()).toList());
    await HomeWidget.saveWidgetData<String>('today_schedule', jsonString);
    await HomeWidget.saveWidgetData<String>('today_date', "${now.month}月${now.day}日");
    await HomeWidget.saveWidgetData<String>('current_week', "第$currentWeek周");

    await HomeWidget.updateWidget(
      name: 'ScheduleWidgetProvider',
      iOSName: 'ScheduleWidget',
    );
  }
}
