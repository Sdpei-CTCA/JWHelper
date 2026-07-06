import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/app/coordinators/home_navigation_coordinator.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

ScheduleItem _item({int weekStart = 1, int weekEnd = 16}) {
  return ScheduleItem(
    name: '高等数学',
    teacher: '张老师',
    classroom: 'A101',
    dayIndex: 0,
    startUnit: 1,
    endUnit: 2,
    weekStart: weekStart,
    weekEnd: weekEnd,
  );
}

void main() {
  group('HomeNavigationCoordinator', () {
    test('resolveDefaultTab returns exam tab during exam period', () {
      final schedule = [_item(weekStart: 1, weekEnd: 16)];
      expect(
        HomeNavigationCoordinator.resolveDefaultTab(
          schedule: schedule,
          currentWeek: 17,
        ),
        HomeNavigationCoordinator.examTab,
      );
    });

    test('resolveDefaultTab returns schedule tab when classes exist', () {
      final schedule = [_item(weekStart: 1, weekEnd: 16)];
      expect(
        HomeNavigationCoordinator.resolveDefaultTab(
          schedule: schedule,
          currentWeek: 10,
        ),
        HomeNavigationCoordinator.scheduleTab,
      );
    });

    test('tabIndexFromWidgetHost maps schedule and exam hosts', () {
      expect(
        HomeNavigationCoordinator.tabIndexFromWidgetHost('schedule'),
        HomeNavigationCoordinator.scheduleTab,
      );
      expect(
        HomeNavigationCoordinator.tabIndexFromWidgetHost('exam'),
        HomeNavigationCoordinator.examTab,
      );
      expect(HomeNavigationCoordinator.tabIndexFromWidgetHost('progress'), 3);
      expect(HomeNavigationCoordinator.tabIndexFromWidgetHost(null), isNull);
    });
  });
}
