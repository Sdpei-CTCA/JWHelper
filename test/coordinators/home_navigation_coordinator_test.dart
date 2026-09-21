import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/app/coordinators/home_navigation_coordinator.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';
import 'package:JWHelper/infrastructure/notifications/notification_service.dart';

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

    test('tabIndexFromToken maps widget hosts and notification payloads', () {
      // 小组件深链 jwhelper://<host>
      expect(
        HomeNavigationCoordinator.tabIndexFromToken('schedule'),
        HomeNavigationCoordinator.scheduleTab,
      );
      expect(
        HomeNavigationCoordinator.tabIndexFromToken('exam'),
        HomeNavigationCoordinator.examTab,
      );
      expect(
        HomeNavigationCoordinator.tabIndexFromToken('progress'),
        HomeNavigationCoordinator.progressTab,
      );
      // 上课提醒通知的 payload
      expect(
        HomeNavigationCoordinator.tabIndexFromToken('attendance'),
        HomeNavigationCoordinator.attendanceTab,
      );
      expect(
        HomeNavigationCoordinator.tabIndexFromToken(
          NotificationService.attendancePayload,
        ),
        HomeNavigationCoordinator.attendanceTab,
      );
      expect(HomeNavigationCoordinator.tabIndexFromToken(null), isNull);
      expect(HomeNavigationCoordinator.tabIndexFromToken('unknown'), isNull);
    });

    test('tab indices match the bottom navigation order', () {
      // 底部导航顺序：课表 / 考勤 / 考试 / 成绩 / 进度
      expect(HomeNavigationCoordinator.scheduleTab, 0);
      expect(HomeNavigationCoordinator.attendanceTab, 1);
      expect(HomeNavigationCoordinator.examTab, 2);
      expect(HomeNavigationCoordinator.gradesTab, 3);
      expect(HomeNavigationCoordinator.progressTab, 4);
    });
  });
}
