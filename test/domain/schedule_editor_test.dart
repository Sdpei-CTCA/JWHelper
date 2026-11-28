import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/features/schedule/domain/schedule_conflict.dart';
import 'package:JWHelper/features/schedule/domain/schedule_editor.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

ScheduleItem _course({
  String name = '高等数学',
  int dayIndex = 0,
  int startUnit = 1,
  int endUnit = 2,
  int weekStart = 1,
  int weekEnd = 8,
  List<int>? weeks,
}) {
  if (weeks != null) {
    return ScheduleItem.withWeeks(
      name: name,
      teacher: '张老师',
      classroom: 'A101',
      dayIndex: dayIndex,
      startUnit: startUnit,
      endUnit: endUnit,
      weeks: weeks,
    );
  }
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
  group('ScheduleEditor', () {
    test('removeOccurrence splits out only the deleted week', () {
      final math = _course(weekStart: 1, weekEnd: 4);
      final next = ScheduleEditor.removeOccurrence([math], math, 2);

      expect(next, hasLength(1));
      expect(next.first.activeWeeks, [1, 3, 4]);
      expect(next.first.occursInWeek(2), isFalse);
      expect(next.first.occursInWeek(3), isTrue);
    });

    test('removeOccurrence deletes whole item when last week is removed', () {
      final single = _course(weeks: [5]);
      final next = ScheduleEditor.removeOccurrence([single], single, 5);

      expect(next, isEmpty);
    });

    test('moveOccurrence moves only fromWeek to target week/day/unit', () {
      final math = _course(dayIndex: 0, startUnit: 1, endUnit: 2, weekStart: 1, weekEnd: 4);
      final next = ScheduleEditor.moveOccurrence(
        [math],
        math,
        fromWeek: 2,
        toWeek: 6,
        toDay: 2,
        toStartUnit: 5,
      );

      expect(next, hasLength(2));
      final original = next.firstWhere((e) => e.dayIndex == 0);
      final moved = next.firstWhere((e) => e.dayIndex == 2);

      expect(original.activeWeeks, [1, 3, 4]);
      expect(moved.activeWeeks, [6]);
      expect(moved.startUnit, 5);
      expect(moved.endUnit, 6);
    });

    test('add, replace, and removeCourse update schedule cleanly', () {
      final c1 = _course(name: '物理', weeks: [1, 2]);
      final c2 = _course(name: '化学', dayIndex: 1, weeks: [1, 2]);
      final added = ScheduleEditor.add([c1], c2);
      expect(added, hasLength(2));

      final c2Edited = c2.copyWith(name: '有机化学', weeks: [1, 3]);
      final replaced = ScheduleEditor.replace(added, c2, c2Edited);
      expect(replaced.map((e) => e.name), ['物理', '有机化学']);

      final removed = ScheduleEditor.removeCourse(replaced, c1);
      expect(removed.map((e) => e.name), ['有机化学']);
    });

    test('hasConflict and canMoveOccurrence check overlap and period bounds', () {
      final c1 = _course(name: '高数', dayIndex: 0, startUnit: 1, endUnit: 2, weeks: [1, 2]);
      final c2 = _course(name: '英语', dayIndex: 0, startUnit: 3, endUnit: 4, weeks: [1]);
      final all = [c1, c2];

      // Moving c1 in week 1 to period 3 conflicts with c2
      expect(
        ScheduleEditor.canMoveOccurrence(
          all,
          c1,
          fromWeek: 1,
          toWeek: 1,
          toDay: 0,
          toStartUnit: 3,
          maxUnit: 12,
        ),
        isFalse,
      );

      // Moving c1 in week 1 to week 2 period 3 has no conflict
      expect(
        ScheduleEditor.canMoveOccurrence(
          all,
          c1,
          fromWeek: 1,
          toWeek: 2,
          toDay: 0,
          toStartUnit: 3,
          maxUnit: 12,
        ),
        isTrue,
      );

      // Moving a 2-unit course to period 12 exceeds maxUnit=12
      expect(
        ScheduleEditor.canMoveOccurrence(
          all,
          c1,
          fromWeek: 1,
          toWeek: 1,
          toDay: 1,
          toStartUnit: 12,
          maxUnit: 12,
        ),
        isFalse,
      );
    });

    test('canMoveOccurrence handles self overlap and bounds without copying',
        () {
      final c1 = _course(
        name: '高数',
        dayIndex: 0,
        startUnit: 1,
        endUnit: 2,
        weeks: [1, 2],
      );
      final all = [c1];

      // Moving within the same week onto a slot overlapping its own old slot is allowed
      expect(
        ScheduleEditor.canMoveOccurrence(
          all,
          c1,
          fromWeek: 1,
          toWeek: 1,
          toDay: 0,
          toStartUnit: 2,
          maxUnit: 12,
        ),
        isTrue,
      );

      // Moving to a different week where c1 already occurs at that slot conflicts with itself
      expect(
        ScheduleEditor.canMoveOccurrence(
          all,
          c1,
          fromWeek: 1,
          toWeek: 2,
          toDay: 0,
          toStartUnit: 2,
          maxUnit: 12,
        ),
        isFalse,
      );

      // Out-of-bounds startUnit or week is rejected
      expect(
        ScheduleEditor.canMoveOccurrence(
          all,
          c1,
          fromWeek: 1,
          toWeek: 1,
          toDay: 0,
          toStartUnit: 0,
          maxUnit: 12,
        ),
        isFalse,
      );
      expect(
        ScheduleEditor.canMoveOccurrence(
          all,
          c1,
          fromWeek: 1,
          toWeek: 0,
          toDay: 1,
          toStartUnit: 1,
          maxUnit: 12,
        ),
        isFalse,
      );
      expect(
        ScheduleEditor.canMoveOccurrence(
          all,
          c1,
          fromWeek: 1,
          toWeek: ScheduleItem.maxTeachingWeeks + 1,
          toDay: 1,
          toStartUnit: 1,
          maxUnit: 12,
        ),
        isFalse,
      );
    });

    test('moving merged multi-teacher course leaves nothing in original slot for that week',
        () {
      final rawItems = [
        ScheduleItem(
          name: '计算机基础与应用',
          teacher: '张老师',
          classroom: '1602',
          dayIndex: 3,
          startUnit: 6,
          endUnit: 7,
          weekStart: 1,
          weekEnd: 16,
        ),
        ScheduleItem(
          name: '计算机基础与应用',
          teacher: '李老师',
          classroom: '1602',
          dayIndex: 3,
          startUnit: 6,
          endUnit: 7,
          weekStart: 1,
          weekEnd: 16,
        ),
      ];
      final merged = ScheduleConflict.mergeSameCourseItems(rawItems);
      expect(merged, hasLength(1));

      final afterMove = ScheduleEditor.moveOccurrence(
        merged,
        merged.first,
        fromWeek: 12,
        toWeek: 12,
        toDay: 3,
        toStartUnit: 4,
      );

      final week12AtOldSlot = afterMove
          .where((e) =>
              e.dayIndex == 3 && e.startUnit == 6 && e.occursInWeek(12))
          .toList();
      expect(week12AtOldSlot, isEmpty);

      final week12AtNewSlot = afterMove
          .where((e) =>
              e.dayIndex == 3 && e.startUnit == 4 && e.occursInWeek(12))
          .toList();
      expect(week12AtNewSlot, hasLength(1));
      expect(week12AtNewSlot.first.teacher, '张老师、李老师');
      expect(week12AtNewSlot.first.endUnit, 5);
    });

    test('moving an occurrence back to its original slot re-merges weeks', () {
      final course = _course(
        name: '管理学',
        dayIndex: 2,
        startUnit: 8,
        endUnit: 9,
        weekStart: 1,
        weekEnd: 4,
      );
      final movedOut = ScheduleEditor.moveOccurrence(
        [course],
        course,
        fromWeek: 2,
        toWeek: 2,
        toDay: 4,
        toStartUnit: 1,
      );
      expect(movedOut, hasLength(2));

      final movedPiece = movedOut.firstWhere((e) => e.dayIndex == 4);
      final movedBack = ScheduleEditor.moveOccurrence(
        movedOut,
        movedPiece,
        fromWeek: 2,
        toWeek: 2,
        toDay: 2,
        toStartUnit: 8,
      );

      expect(movedBack, hasLength(1));
      expect(movedBack.first.activeWeeks, [1, 2, 3, 4]);
    });
  });
}
