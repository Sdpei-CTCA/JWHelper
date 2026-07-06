import 'package:JWHelper/app/domain/schedule_week_context.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

class HomeNavigationCoordinator {
  static const int scheduleTab = 0;
  static const int examTab = 1;

  static int resolveDefaultTab({
    required List<ScheduleItem> schedule,
    required int currentWeek,
  }) {
    if (ScheduleWeekContext.isExamPeriod(schedule, currentWeek)) {
      return examTab;
    }
    return scheduleTab;
  }

  static int? tabIndexFromWidgetHost(String? host) {
    if (host == null) return null;
    if (host == 'schedule') return scheduleTab;
    if (host == 'exam') return examTab;
    if (host == 'progress') return 3;
    return null;
  }
}
