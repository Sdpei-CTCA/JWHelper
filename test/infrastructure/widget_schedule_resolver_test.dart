import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/core/constants/period_time_table.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';
import 'package:JWHelper/infrastructure/platform/widget_schedule_resolver.dart';

ScheduleItem _item({
  int dayIndex = 0,
  int startUnit = 1,
  int endUnit = 2,
  int weekStart = 1,
  int weekEnd = 16,
}) {
  return ScheduleItem(
    name: '高等数学',
    teacher: '张老师',
    classroom: 'A101',
    dayIndex: dayIndex,
    startUnit: startUnit,
    endUnit: endUnit,
    weekStart: weekStart,
    weekEnd: weekEnd,
  );
}

void main() {
  group('WidgetScheduleResolver', () {
    test('resolveWeekForDate increments after Sunday night', () {
      final savedDate = DateTime(2026, 7, 5);
      final monday = DateTime(2026, 7, 6);

      expect(
        WidgetScheduleResolver.resolveWeekForDate(
          storedWeek: 10,
          savedDate: savedDate,
          targetDate: monday,
        ),
        11,
      );
    });

    test('resolveTodayFromCache filters by day and week', () {
      final items = [
        _item(dayIndex: 0, weekStart: 11, weekEnd: 11),
        _item(dayIndex: 1, weekStart: 11, weekEnd: 11),
      ];
      final mondayMorning = DateTime(2026, 7, 6, 8, 0);

      final resolved = WidgetScheduleResolver.resolveTodayFromCache(
        allItems: items,
        storedWeek: 10,
        savedDate: DateTime(2026, 7, 5),
        now: mondayMorning,
      );

      expect(resolved.displayWeek, 11);
      expect(resolved.displayItems.length, 1);
      expect(resolved.displayItems.first.dayIndex, 0);
    });

    test('resolveDisplayDay rolls to next day after classes end', () {
      final items = [
        _item(dayIndex: 0, startUnit: 1, endUnit: 1),
      ];
      final evening = DateTime(2026, 7, 6, 21, 0);

      final resolved = WidgetScheduleResolver.resolveDisplayDay(
        allItems: items,
        currentWeek: 10,
        now: evening,
        campus: PeriodTimeTable.campusJinan,
      );

      expect(resolved.displayDate, DateTime(2026, 7, 7));
    });
  });
}
