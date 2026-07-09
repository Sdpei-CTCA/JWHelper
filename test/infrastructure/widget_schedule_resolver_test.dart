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
    test('resolveWeekForDate advances week every 7 days', () {
      final anchorDate = DateTime(2026, 2, 16);
      final targetDate = DateTime(2026, 3, 2);

      expect(
        WidgetScheduleResolver.resolveWeekForDate(
          anchorWeek: 10,
          anchorDate: anchorDate,
          targetDate: targetDate,
        ),
        12,
      );
    });

    test('weekFromStartDay matches academic week calculation', () {
      expect(
        WidgetScheduleResolver.weekFromStartDay(
          '2026-02-16',
          DateTime(2026, 3, 2),
        ),
        3,
      );
    });

    test('resolveTodayFromCache prefers startDay over anchor fallback', () {
      final items = [
        _item(dayIndex: 0, weekStart: 3, weekEnd: 3),
        _item(dayIndex: 1, weekStart: 3, weekEnd: 3),
      ];
      final mondayMorning = DateTime(2026, 3, 2, 8, 0);

      final resolved = WidgetScheduleResolver.resolveTodayFromCache(
        allItems: items,
        anchorWeek: 1,
        anchorDate: DateTime(2026, 2, 1),
        startDay: '2026-02-16',
        now: mondayMorning,
      );

      expect(resolved.displayWeek, 3);
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
        startDay: '2026-02-16',
      );

      expect(resolved.displayDate, DateTime(2026, 7, 7));
    });
  });
}
