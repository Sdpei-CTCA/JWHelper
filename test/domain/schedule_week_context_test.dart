import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/app/domain/schedule_week_context.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

ScheduleItem _item({int weekStart = 1, int weekEnd = 16, int dayIndex = 0}) {
  return ScheduleItem(
    name: '高等数学',
    teacher: '张老师',
    classroom: 'A101',
    dayIndex: dayIndex,
    startUnit: 1,
    endUnit: 2,
    weekStart: weekStart,
    weekEnd: weekEnd,
  );
}

void main() {
  group('ScheduleWeekContext', () {
    test('hasClassesInWeek returns true when current week is in range', () {
      final items = [_item(weekStart: 1, weekEnd: 16)];
      expect(ScheduleWeekContext.hasClassesInWeek(items, 10), isTrue);
    });

    test('hasClassesInWeek returns false when current week is outside range', () {
      final items = [_item(weekStart: 1, weekEnd: 16)];
      expect(ScheduleWeekContext.hasClassesInWeek(items, 17), isFalse);
    });

    test('weekStart/weekEnd of 0 means all semester', () {
      final items = [_item(weekStart: 0, weekEnd: 0)];
      expect(ScheduleWeekContext.hasClassesInWeek(items, 20), isTrue);
    });

    test('isExamPeriod is true when no classes in current week', () {
      final items = [_item(weekStart: 1, weekEnd: 16)];
      expect(ScheduleWeekContext.isExamPeriod(items, 17), isTrue);
    });

    test('isExamPeriod is false when classes exist in current week', () {
      final items = [_item(weekStart: 1, weekEnd: 16)];
      expect(ScheduleWeekContext.isExamPeriod(items, 8), isFalse);
    });

    test('empty schedule with currentWeek <= 0 is exam period', () {
      expect(ScheduleWeekContext.isExamPeriod([], 0), isTrue);
      expect(ScheduleWeekContext.hasClassesInWeek([], 0), isFalse);
    });
  });
}
