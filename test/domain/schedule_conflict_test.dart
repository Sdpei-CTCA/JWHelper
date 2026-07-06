import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/features/schedule/domain/schedule_conflict.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

ScheduleItem _item({
  required String name,
  int dayIndex = 0,
  int startUnit = 1,
  int endUnit = 2,
  int weekStart = 1,
  int weekEnd = 16,
}) {
  return ScheduleItem(
    name: name,
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
  group('ScheduleConflict', () {
    test('groups overlapping courses on the same day', () {
      final items = [
        _item(name: '数学', startUnit: 1, endUnit: 2),
        _item(name: '英语', startUnit: 1, endUnit: 2),
        _item(name: '体育', dayIndex: 1, startUnit: 3, endUnit: 4),
      ];

      final groups = ScheduleConflict.groupOverlapping(items);
      expect(groups.length, 2);
      expect(groups.first.length, 2);
      expect(groups.last.length, 1);
    });

    test('resolvePrimary uses saved item key when available', () {
      final group = [
        _item(name: '数学'),
        _item(name: '英语'),
      ];
      final englishKey = ScheduleConflict.itemKey(group[1]);

      final resolved = ScheduleConflict.resolvePrimary(
        group: group,
        weekNumber: 8,
        savedItemKey: englishKey,
      );

      expect(resolved.name, '英语');
    });

    test('defaultPrimary prefers current-week course', () {
      final group = [
        _item(name: '已结束', weekStart: 1, weekEnd: 5),
        _item(name: '当前课', weekStart: 6, weekEnd: 16),
      ];

      final resolved = ScheduleConflict.defaultPrimary(group, 8);
      expect(resolved.name, '当前课');
    });
  });
}
