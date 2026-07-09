import 'package:JWHelper/core/constants/period_time_table.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

/// Shared schedule resolution logic for home screen widgets.
class WidgetScheduleResolver {
  static int calendarDayIndex(DateTime date) => date.weekday - 1;

  static List<ScheduleItem> itemsForDay(
    List<ScheduleItem> allItems, {
    required int dayIndex,
    required int currentWeek,
  }) {
    final result = allItems.where((item) {
      if (item.dayIndex != dayIndex) return false;
      return isInCurrentWeek(item, currentWeek);
    }).toList();
    result.sort((a, b) => a.startUnit.compareTo(b.startUnit));
    return result;
  }

  static bool isInCurrentWeek(ScheduleItem item, int currentWeek) {
    if (currentWeek <= 0) return true;
    if (item.weekStart > 0 && item.weekEnd > 0) {
      return currentWeek >= item.weekStart && currentWeek <= item.weekEnd;
    }
    return true;
  }

  static bool isClassPassed(
    ScheduleItem item,
    DateTime now, {
    required String campus,
  }) {
    final endMinutes = PeriodTimeTable.endMinutesForUnit(
      item.endUnit,
      campus: campus,
      date: now,
    );
    final nowMinutes = now.hour * 60 + now.minute;
    return nowMinutes >= endMinutes;
  }

  static int resolveWeekForDate({
    required int anchorWeek,
    required DateTime anchorDate,
    required DateTime targetDate,
  }) {
    if (anchorWeek <= 0) return anchorWeek;
    final anchorDay = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    final targetDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    if (!targetDay.isAfter(anchorDay)) return anchorWeek;

    final daysBetween = targetDay.difference(anchorDay).inDays;
    return anchorWeek + daysBetween ~/ 7;
  }

  static int? weekFromStartDay(String? startDayStr, DateTime targetDate) {
    if (startDayStr == null || startDayStr.trim().isEmpty) return null;
    try {
      final parsed = DateTime.parse(startDayStr);
      final startDay = DateTime(parsed.year, parsed.month, parsed.day);
      final targetDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final diffDays = targetDay.difference(startDay).inDays;
      if (diffDays < 0) return 1;
      return (diffDays / 7).floor() + 1;
    } catch (_) {
      return null;
    }
  }

  static int resolveWeek({
    required DateTime targetDate,
    required int anchorWeek,
    required DateTime anchorDate,
    String? startDay,
  }) {
    return weekFromStartDay(startDay, targetDate) ??
        resolveWeekForDate(
          anchorWeek: anchorWeek,
          anchorDate: anchorDate,
          targetDate: targetDate,
        );
  }

  static ResolvedWidgetDay resolveDisplayDay({
    required List<ScheduleItem> allItems,
    required int currentWeek,
    required DateTime now,
    required String campus,
    String? startDay,
  }) {
    final todayDate = DateTime(now.year, now.month, now.day);
    final todayIndex = calendarDayIndex(now);

    final todayItems =
        itemsForDay(allItems, dayIndex: todayIndex, currentWeek: currentWeek);
    final shouldShowNextDay = todayItems.isNotEmpty &&
        todayItems.every((item) => isClassPassed(item, now, campus: campus));

    var displayDate = todayDate;
    var displayDayIndex = todayIndex;
    var displayWeek = currentWeek;
    var displayItems = todayItems;

    if (shouldShowNextDay) {
      displayDate = todayDate.add(const Duration(days: 1));
      displayDayIndex = (todayIndex + 1) % 7;
      displayWeek = resolveWeek(
        targetDate: displayDate,
        anchorWeek: currentWeek,
        anchorDate: todayDate,
        startDay: startDay,
      );
      displayItems = itemsForDay(
        allItems,
        dayIndex: displayDayIndex,
        currentWeek: displayWeek,
      );
    }

    return ResolvedWidgetDay(
      displayDate: displayDate,
      displayDayIndex: displayDayIndex,
      displayWeek: displayWeek,
      displayItems: displayItems,
    );
  }

  static ResolvedWidgetDay resolveTodayFromCache({
    required List<ScheduleItem> allItems,
    required int anchorWeek,
    required DateTime anchorDate,
    required DateTime now,
    String? startDay,
  }) {
    final todayDate = DateTime(now.year, now.month, now.day);
    final week = resolveWeek(
      targetDate: todayDate,
      anchorWeek: anchorWeek,
      anchorDate: anchorDate,
      startDay: startDay,
    );
    final dayIndex = calendarDayIndex(now);
    final items = itemsForDay(allItems, dayIndex: dayIndex, currentWeek: week);
    return ResolvedWidgetDay(
      displayDate: todayDate,
      displayDayIndex: dayIndex,
      displayWeek: week,
      displayItems: items,
    );
  }
}

class ResolvedWidgetDay {
  final DateTime displayDate;
  final int displayDayIndex;
  final int displayWeek;
  final List<ScheduleItem> displayItems;

  const ResolvedWidgetDay({
    required this.displayDate,
    required this.displayDayIndex,
    required this.displayWeek,
    required this.displayItems,
  });
}
