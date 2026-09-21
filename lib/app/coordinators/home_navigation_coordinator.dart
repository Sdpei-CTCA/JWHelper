import 'package:JWHelper/app/domain/schedule_week_context.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

class HomeNavigationCoordinator {
  static const int scheduleTab = 0;
  static const int attendanceTab = 1;
  static const int examTab = 2;
  static const int gradesTab = 3;
  static const int progressTab = 4;

  static int resolveDefaultTab({
    required List<ScheduleItem> schedule,
    required int currentWeek,
  }) {
    if (ScheduleWeekContext.isExamPeriod(schedule, currentWeek)) {
      return examTab;
    }
    return scheduleTab;
  }

  /// 把外部的跳转标识（桌面小组件的 `jwhelper://<token>` host、通知 payload）
  /// 解析成底部导航的 tab 下标；无法识别时返回 null。
  static int? tabIndexFromToken(String? token) {
    if (token == null) return null;
    if (token == 'schedule') return scheduleTab;
    if (token == 'attendance') return attendanceTab;
    if (token == 'exam') return examTab;
    if (token == 'grades') return gradesTab;
    if (token == 'progress') return progressTab;
    return null;
  }
}
