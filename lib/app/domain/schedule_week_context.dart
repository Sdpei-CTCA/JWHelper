import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

class ScheduleWeekContext {
  /// 当前教学周是否还有常规课程
  static bool hasClassesInWeek(List<ScheduleItem> items, int currentWeek) {
    if (items.isEmpty || currentWeek <= 0) return items.isNotEmpty;
    return items.any((item) => _isInCurrentWeek(item, currentWeek));
  }

  /// 是否处于考试周（本周及以后无常规课）
  static bool isExamPeriod(List<ScheduleItem> items, int currentWeek) {
    return !hasClassesInWeek(items, currentWeek);
  }

  static bool _isInCurrentWeek(ScheduleItem item, int currentWeek) {
    if (item.weekStart > 0 && item.weekEnd > 0) {
      return currentWeek >= item.weekStart && currentWeek <= item.weekEnd;
    }
    return true;
  }
}
