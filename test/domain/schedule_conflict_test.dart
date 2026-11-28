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

    group('mergeSameCourseItems', () {
      ScheduleItem raw({
        required String name,
        String teacher = '张老师',
        String classroom = '1602',
        int dayIndex = 0,
        int startUnit = 1,
        int endUnit = 2,
        int weekStart = 1,
        int weekEnd = 16,
        List<int>? weeks,
      }) {
        return ScheduleItem(
          name: name,
          teacher: teacher,
          classroom: classroom,
          dayIndex: dayIndex,
          startUnit: startUnit,
          endUnit: endUnit,
          weekStart: weekStart,
          weekEnd: weekEnd,
          weeks: weeks,
        );
      }

      test('merges 2 or 3 teachers for same course in same slot and dedups',
          () {
        final merged = ScheduleConflict.mergeSameCourseItems([
          raw(name: '计算机基础与应用', teacher: '王老师', classroom: '1602'),
          raw(name: '计算机基础与应用', teacher: '李老师', classroom: '1602'),
          raw(name: '计算机基础与应用', teacher: '王老师、赵老师', classroom: '1602'),
        ]);

        expect(merged, hasLength(1));
        expect(merged.first.teacher, '王老师、李老师、赵老师');
        expect(merged.first.classroom, '1602');
        expect(merged.first.weeks, isNull);
        expect(merged.first.weekStart, 1);
        expect(merged.first.weekEnd, 16);
      });

      test('merges split half-semester teachers into contiguous range', () {
        final merged = ScheduleConflict.mergeSameCourseItems([
          raw(
            name: '运动解剖学',
            teacher: '张老师',
            classroom: '3106',
            weekStart: 1,
            weekEnd: 8,
          ),
          raw(
            name: '运动解剖学',
            teacher: '李老师',
            classroom: '3106',
            weekStart: 9,
            weekEnd: 16,
          ),
        ]);

        expect(merged, hasLength(1));
        expect(merged.first.teacher, '张老师、李老师');
        expect(merged.first.weeks, isNull);
        expect(merged.first.weekStart, 1);
        expect(merged.first.weekEnd, 16);
      });

      test('merges non-contiguous weeks into explicit weeks list', () {
        final merged = ScheduleConflict.mergeSameCourseItems([
          raw(
            name: '管理学',
            teacher: '王老师',
            classroom: '3112',
            weekStart: 1,
            weekEnd: 4,
          ),
          raw(
            name: '管理学',
            teacher: '陈老师',
            classroom: '3112',
            weekStart: 9,
            weekEnd: 12,
          ),
        ]);

        expect(merged, hasLength(1));
        expect(merged.first.teacher, '王老师、陈老师');
        expect(merged.first.activeWeeks, [1, 2, 3, 4, 9, 10, 11, 12]);
        expect(merged.first.weeks, [1, 2, 3, 4, 9, 10, 11, 12]);
      });

      test('merges different classrooms when weeks overlap', () {
        final merged = ScheduleConflict.mergeSameCourseItems([
          raw(
            name: '大学外语1',
            teacher: '刘老师',
            classroom: '1602',
            weekStart: 1,
            weekEnd: 16,
          ),
          raw(
            name: '大学外语1',
            teacher: '周老师',
            classroom: '1603',
            weekStart: 5,
            weekEnd: 12,
          ),
        ]);

        expect(merged, hasLength(1));
        expect(merged.first.teacher, '刘老师、周老师');
        expect(merged.first.classroom, '1602/1603');
        expect(merged.first.weekStart, 1);
        expect(merged.first.weekEnd, 16);
      });

      test('keeps separate when classrooms differ and weeks do not overlap', () {
        final merged = ScheduleConflict.mergeSameCourseItems([
          raw(
            name: '大学外语1',
            teacher: '刘老师',
            classroom: '1602',
            weekStart: 1,
            weekEnd: 8,
          ),
          raw(
            name: '大学外语1',
            teacher: '周老师',
            classroom: '1603',
            weekStart: 9,
            weekEnd: 16,
          ),
        ]);

        expect(merged, hasLength(2));
        expect(merged[0].classroom, '1602');
        expect(merged[1].classroom, '1603');
      });

      test('does not merge different course names in the same slot', () {
        final merged = ScheduleConflict.mergeSameCourseItems([
          raw(name: '游泳', teacher: '王老师', classroom: '1'),
          raw(name: '篮球', teacher: '李老师', classroom: '2'),
        ]);

        expect(merged, hasLength(2));
      });

      test('is idempotent across repeated calls', () {
        final input = [
          raw(
            name: '计算机基础与应用',
            teacher: '王老师',
            classroom: '1602',
            weekStart: 1,
            weekEnd: 6,
          ),
          raw(
            name: '计算机基础与应用',
            teacher: '李老师',
            classroom: '1602',
            weekStart: 10,
            weekEnd: 14,
          ),
        ];

        final once = ScheduleConflict.mergeSameCourseItems(input);
        final twice = ScheduleConflict.mergeSameCourseItems(once);

        expect(twice, hasLength(1));
        expect(twice.first.teacher, once.first.teacher);
        expect(twice.first.classroom, once.first.classroom);
        expect(twice.first.activeWeeks, once.first.activeWeeks);
        expect(twice.first.weeks, once.first.weeks);
      });
    });
  });
}
