import 'package:JWHelper/features/schedule/domain/schedule_conflict.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

/// 调课 / 自定义课程的纯函数逻辑，不依赖 Flutter，便于单测。
///
/// 课程通过 [ScheduleConflict.itemKey] 定位；所有方法都返回新的列表，
/// 不修改入参。
class ScheduleEditor {
  static int _indexOf(List<ScheduleItem> all, ScheduleItem target) {
    final key = ScheduleConflict.itemKey(target);
    final identicalIndex = all.indexWhere((e) => identical(e, target));
    if (identicalIndex >= 0) return identicalIndex;
    return all.indexWhere((e) => ScheduleConflict.itemKey(e) == key);
  }

  /// 删除 [target] 在第 [week] 周的这一次课；若删除后没有剩余周次则移除整条。
  static List<ScheduleItem> removeOccurrence(
    List<ScheduleItem> all,
    ScheduleItem target,
    int week,
  ) {
    final index = _indexOf(all, target);
    if (index < 0) return List<ScheduleItem>.from(all);
    final item = all[index];
    final result = List<ScheduleItem>.from(all);
    if (!item.occursInWeek(week)) return result;

    final remaining = item.activeWeeks.where((w) => w != week).toList();
    if (remaining.isEmpty) {
      result.removeAt(index);
    } else {
      result[index] = item.copyWith(weeks: remaining);
    }
    return result;
  }

  /// 把 [target] 第 [fromWeek] 周的这一次课移到第 [toWeek] 周的
  /// 星期 [toDay]、第 [toStartUnit] 节开始（节数长度不变）。
  static List<ScheduleItem> moveOccurrence(
    List<ScheduleItem> all,
    ScheduleItem target, {
    required int fromWeek,
    required int toWeek,
    required int toDay,
    required int toStartUnit,
  }) {
    final index = _indexOf(all, target);
    if (index < 0) return List<ScheduleItem>.from(all);
    final item = all[index];
    final span = item.unitSpan;

    if (fromWeek == toWeek &&
        toDay == item.dayIndex &&
        toStartUnit == item.startUnit) {
      return List<ScheduleItem>.from(all);
    }

    final result = removeOccurrence(all, item, fromWeek);
    final moved = ScheduleItem.withWeeks(
      name: item.name,
      teacher: item.teacher,
      classroom: item.classroom,
      dayIndex: toDay,
      startUnit: toStartUnit,
      endUnit: toStartUnit + span - 1,
      weeks: [toWeek],
    );
    result.add(moved);
    return result;
  }

  static List<ScheduleItem> add(List<ScheduleItem> all, ScheduleItem item) {
    return List<ScheduleItem>.from(all)..add(item);
  }

  static List<ScheduleItem> replace(
    List<ScheduleItem> all,
    ScheduleItem oldItem,
    ScheduleItem newItem,
  ) {
    final index = _indexOf(all, oldItem);
    final result = List<ScheduleItem>.from(all);
    if (index < 0) {
      result.add(newItem);
    } else {
      result[index] = newItem;
    }
    return result;
  }

  static List<ScheduleItem> removeCourse(
    List<ScheduleItem> all,
    ScheduleItem target,
  ) {
    final index = _indexOf(all, target);
    final result = List<ScheduleItem>.from(all);
    if (index >= 0) result.removeAt(index);
    return result;
  }

  /// 第 [week] 周星期 [day] 的第 [start]-[end] 节是否已被其他课程占用。
  static bool hasConflict(
    List<ScheduleItem> all, {
    required int week,
    required int day,
    required int start,
    required int end,
    ScheduleItem? ignore,
  }) {
    final ignoreKey = ignore == null ? null : ScheduleConflict.itemKey(ignore);
    for (final item in all) {
      if (ignore != null &&
          (identical(item, ignore) ||
              ScheduleConflict.itemKey(item) == ignoreKey)) {
        continue;
      }
      if (item.dayIndex != day) continue;
      if (!item.occursInWeek(week)) continue;
      if (item.startUnit <= end && start <= item.endUnit) return true;
    }
    return false;
  }

  /// 能否把 [target] 第 [fromWeek] 周的课移到目标位置：
  /// 不超过 [maxUnit] 节，且与（移除原课次后的）其他课程不冲突。
  static bool canMoveOccurrence(
    List<ScheduleItem> all,
    ScheduleItem target, {
    required int fromWeek,
    required int toWeek,
    required int toDay,
    required int toStartUnit,
    required int maxUnit,
  }) {
    final end = toStartUnit + target.unitSpan - 1;
    if (toStartUnit < 1 || end > maxUnit) return false;
    if (toWeek < 1 || toWeek > ScheduleItem.maxTeachingWeeks) return false;

    final targetIndex = _indexOf(all, target);
    for (var i = 0; i < all.length; i++) {
      // 移除 [target] 在 [fromWeek] 的课次后，同一周内 [target] 自身不再占用原时段；
      // 若移动到其他周 [toWeek]，原课程在 [toWeek] 的既有课次仍然存在，需参与冲突判定。
      if (i == targetIndex && toWeek == fromWeek) continue;
      final item = all[i];
      if (item.dayIndex != toDay) continue;
      if (!item.occursInWeek(toWeek)) continue;
      if (item.startUnit <= end && toStartUnit <= item.endUnit) {
        return false;
      }
    }
    return true;
  }

  /// 编辑课程时检测与其他课程在任一周的冲突，返回冲突的周次。
  static List<int> conflictWeeks(
    List<ScheduleItem> all,
    ScheduleItem candidate, {
    ScheduleItem? ignore,
  }) {
    final weeks = <int>[];
    for (final w in candidate.activeWeeks) {
      if (hasConflict(
        all,
        week: w,
        day: candidate.dayIndex,
        start: candidate.startUnit,
        end: candidate.endUnit,
        ignore: ignore,
      )) {
        weeks.add(w);
      }
    }
    return weeks;
  }
}
