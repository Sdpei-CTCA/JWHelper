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
  });
}
