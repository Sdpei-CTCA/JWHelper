import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

class ScheduleConflict {
  static String itemKey(ScheduleItem item) {
    return '${item.dayIndex}_${item.startUnit}_${item.endUnit}_'
        '${item.name}_${item.teacher}_${item.classroom}_'
        '${item.weekStart}_${item.weekEnd}';
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
    final groups = <List<ScheduleItem>>[];
    final assigned = <String>{};

    for (final item in items) {
      final key = itemKey(item);
      if (assigned.contains(key)) continue;

      final group = <ScheduleItem>[item];
      assigned.add(key);

      var foundMore = true;
      while (foundMore) {
        foundMore = false;
        for (final other in items) {
          final otherKey = itemKey(other);
          if (assigned.contains(otherKey)) continue;
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
        if (weekNumber >= item.weekStart && weekNumber <= item.weekEnd) {
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
