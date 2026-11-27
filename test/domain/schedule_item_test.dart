import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

void main() {
  group('ScheduleItem', () {
    final item = ScheduleItem(
      name: '操作系统',
      teacher: '张老师',
      classroom: '教学楼A101',
      dayIndex: 2,
      startUnit: 3,
      endUnit: 4,
      weekStart: 1,
      weekEnd: 16,
    );

    test('toJson and fromJson roundtrip', () {
      final restored = ScheduleItem.fromJson(item.toJson());

      expect(restored.name, item.name);
      expect(restored.teacher, item.teacher);
      expect(restored.classroom, item.classroom);
      expect(restored.dayIndex, item.dayIndex);
      expect(restored.startUnit, item.startUnit);
      expect(restored.endUnit, item.endUnit);
      expect(restored.weekStart, item.weekStart);
      expect(restored.weekEnd, item.weekEnd);
    });

    test('periodString uses start and end units', () {
      expect(item.periodString, '3-4节');
    });

    test('occursInWeek uses explicit weeks when present', () {
      final custom = ScheduleItem.withWeeks(
        name: '线性代数',
        teacher: '李老师',
        classroom: 'B201',
        dayIndex: 1,
        startUnit: 1,
        endUnit: 2,
        weeks: [1, 3, 5, 7],
      );

      expect(custom.weekStart, 1);
      expect(custom.weekEnd, 7);
      expect(custom.occursInWeek(3), isTrue);
      expect(custom.occursInWeek(4), isFalse);
      expect(custom.weeksLabel, '1-7周(单)');
    });

    test('toJson and fromJson preserve explicit weeks and stay backward compatible', () {
      final custom = ScheduleItem.withWeeks(
        name: '数据结构',
        teacher: '王老师',
        classroom: 'C301',
        dayIndex: 3,
        startUnit: 5,
        endUnit: 6,
        weeks: [1, 2, 3, 4, 6, 7, 8],
      );

      final json = custom.toJson();
      expect(json['weeks'], [1, 2, 3, 4, 6, 7, 8]);

      final restored = ScheduleItem.fromJson(json);
      expect(restored.weeks, [1, 2, 3, 4, 6, 7, 8]);
      expect(restored.occursInWeek(5), isFalse);
      expect(restored.weeksLabel, '1-4,6-8周');

      // Legacy JSON without weeks key
      final legacy = ScheduleItem.fromJson(item.toJson());
      expect(legacy.weeks, isNull);
      expect(legacy.occursInWeek(8), isTrue);
      expect(legacy.occursInWeek(17), isFalse);
      expect(legacy.weeksLabel, '1-16周');
    });
  });
}
