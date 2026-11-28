import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

class ScheduleConflict {
  static final RegExp _teacherSplitRe = RegExp(r'[、,，/]+');

  /// 将同一时段、同一门课但因不同教师或分段周次拆开的多条记录合并为一条。
  ///
  /// 保持首次出现顺序，并且对已合并列表再次调用时完全幂等。
  static List<ScheduleItem> mergeSameCourseItems(List<ScheduleItem> items) {
    if (items.length <= 1) return List<ScheduleItem>.from(items);

    final groups = <List<ScheduleItem>>[];
    final assigned = List<bool>.filled(items.length, false);

    for (var i = 0; i < items.length; i++) {
      if (assigned[i]) continue;
      assigned[i] = true;
      final group = <ScheduleItem>[items[i]];

      var foundMore = true;
      while (foundMore) {
        foundMore = false;
        for (var j = 0; j < items.length; j++) {
          if (assigned[j]) continue;
          final candidate = items[j];
          if (group.any((existing) => _canMergeSameCourse(existing, candidate))) {
            group.add(candidate);
            assigned[j] = true;
            foundMore = true;
          }
        }
      }
      groups.add(group);
    }

    return groups.map(_mergeSameCourseGroup).toList();
  }

  static bool _canMergeSameCourse(ScheduleItem a, ScheduleItem b) {
    if (a.dayIndex != b.dayIndex ||
        a.startUnit != b.startUnit ||
        a.endUnit != b.endUnit) {
      return false;
    }
    final nameA = a.name.trim();
    final nameB = b.name.trim();
    if (nameA.isEmpty || nameA != nameB) return false;

    final roomA = a.classroom.trim();
    final roomB = b.classroom.trim();
    if (roomA == roomB || roomA.isEmpty || roomB.isEmpty) {
      return true;
    }
    return _weeksOverlap(a, b);
  }

  static bool _weeksOverlap(ScheduleItem a, ScheduleItem b) {
    if (!a.hasWeekInfo || !b.hasWeekInfo) return true;
    final weeksA = a.activeWeeks.toSet();
    for (final w in b.activeWeeks) {
      if (weeksA.contains(w)) return true;
    }
    return false;
  }

  static ScheduleItem _mergeSameCourseGroup(List<ScheduleItem> group) {
    if (group.length == 1) return group.first;

    final teachers = <String>{};
    final classrooms = <String>{};
    for (final item in group) {
      for (final part in item.teacher.split(_teacherSplitRe)) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty) teachers.add(trimmed);
      }
      for (final part in item.classroom.split('/')) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty) classrooms.add(trimmed);
      }
    }

    final mergedName = group.first.name.trim();
    final mergedTeacher = teachers.join('、');
    final mergedClassroom = classrooms.join('/');
    final first = group.first;

    final withWeekInfo = group.where((e) => e.hasWeekInfo).toList();
    if (withWeekInfo.isEmpty) {
      return ScheduleItem(
        name: mergedName,
        teacher: mergedTeacher,
        classroom: mergedClassroom,
        dayIndex: first.dayIndex,
        startUnit: first.startUnit,
        endUnit: first.endUnit,
        weekStart: 0,
        weekEnd: 0,
      );
    }

    final mergedWeeks = ScheduleItem.normalizeWeeks(
      withWeekInfo.expand((e) => e.activeWeeks),
    );
    if (mergedWeeks.isEmpty) {
      return ScheduleItem(
        name: mergedName,
        teacher: mergedTeacher,
        classroom: mergedClassroom,
        dayIndex: first.dayIndex,
        startUnit: first.startUnit,
        endUnit: first.endUnit,
        weekStart: 0,
        weekEnd: 0,
      );
    }

    final isContiguous =
        mergedWeeks.last - mergedWeeks.first + 1 == mergedWeeks.length;
    if (group.every((e) => e.weeks == null) && isContiguous) {
      return ScheduleItem(
        name: mergedName,
        teacher: mergedTeacher,
        classroom: mergedClassroom,
        dayIndex: first.dayIndex,
        startUnit: first.startUnit,
        endUnit: first.endUnit,
        weekStart: mergedWeeks.first,
        weekEnd: mergedWeeks.last,
      );
    }

    return ScheduleItem.withWeeks(
      name: mergedName,
      teacher: mergedTeacher,
      classroom: mergedClassroom,
      dayIndex: first.dayIndex,
      startUnit: first.startUnit,
      endUnit: first.endUnit,
      weeks: mergedWeeks,
    );
  }

  static String itemKey(ScheduleItem item) {
    final base = '${item.dayIndex}_${item.startUnit}_${item.endUnit}_'
        '${item.name}_${item.teacher}_${item.classroom}_'
        '${item.weekStart}_${item.weekEnd}';
    // 只有带明确周次集合的课程才追加签名，保证旧数据的 key 不变
    // （已保存的冲突主显示选择仍然有效）。
    if (item.weeks == null) return base;
    return '${base}_w${item.weeks!.join('.')}';
  }

  static String groupKey(List<ScheduleItem> group) {
    final keys = group.map(itemKey).toList()..sort();
    return keys.join('|');
  }

  static bool overlaps(ScheduleItem a, ScheduleItem b) {
    if (a.dayIndex != b.dayIndex) return false;
    return a.startUnit <= b.endUnit && b.startUnit <= a.endUnit;
  }

  static List<List<ScheduleItem>> groupOverlapping(List<ScheduleItem> items) {
    if (items.isEmpty) return [];
    final keys = [for (final item in items) itemKey(item)];
    final groups = <List<ScheduleItem>>[];
    final assigned = <String>{};

    for (var i = 0; i < items.length; i++) {
      final key = keys[i];
      if (!assigned.add(key)) continue;

      final group = <ScheduleItem>[items[i]];

      var foundMore = true;
      while (foundMore) {
        foundMore = false;
        for (var j = 0; j < items.length; j++) {
          final otherKey = keys[j];
          if (assigned.contains(otherKey)) continue;
          final other = items[j];
          if (group.any((existing) => overlaps(existing, other))) {
            group.add(other);
            assigned.add(otherKey);
            foundMore = true;
          }
        }
      }
      groups.add(group);
    }
    return groups;
  }

  static ScheduleItem resolvePrimary({
    required List<ScheduleItem> group,
    required int weekNumber,
    String? savedItemKey,
  }) {
    if (group.length == 1) return group.first;

    if (savedItemKey != null) {
      for (final item in group) {
        if (itemKey(item) == savedItemKey) return item;
      }
    }

    return defaultPrimary(group, weekNumber);
  }

  static ScheduleItem defaultPrimary(List<ScheduleItem> group, int weekNumber) {
    final sorted = List<ScheduleItem>.from(group);
    sorted.sort((a, b) {
      int score(ScheduleItem item) {
        if (item.occursInWeek(weekNumber)) {
          return 0;
        }
        if (weekNumber < item.weekStart) return 1;
        return 2;
      }

      final scoreCompare = score(a).compareTo(score(b));
      if (scoreCompare != 0) return scoreCompare;
      return itemKey(a).compareTo(itemKey(b));
    });
    return sorted.first;
  }
}
