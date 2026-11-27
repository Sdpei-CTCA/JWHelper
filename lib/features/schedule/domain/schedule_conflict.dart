import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

class ScheduleConflict {
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
