/// 各校区教学作息时间表（官方《教学作息时间安排表》的正本）。
///
/// 官方作息仅以图片形式发布，接口（ClassTimePatterns）只返回节次与单位的映射，
/// 不含上下课时间，因此在这里硬编码；下列每个校区的 start/end 映射与官方表格
/// 逐行对应，便于直接对照核对。
///
/// * 每节 40 分钟。第 1-9 节两校区完全一致，仅第 10-12 节不同。
/// * 济南校区没有第 10 节（官方表中该行为 `/`），故其映射中不含 10。
/// * 官方表格不分夏令时/冬令时，全天候使用同一张表。
///
/// Keep in sync with [ScheduleWidgetTimeTable.kt] and the iOS widget's
/// `WidgetTimeTable`（ios/ScheduleWidget/WidgetShared.swift）。
class PeriodTimeTable {
  static const String campusJinan = '济南';
  static const String campusRizhao = '日照';

  /// 济南：第 1-9 节与日照相同，第 10 节不存在，第 11-12 节早于日照。
  static const Map<int, int> _jinanStartMinutes = {
    1: 8 * 60,
    2: 8 * 60 + 45,
    3: 9 * 60 + 45,
    4: 10 * 60 + 30,
    5: 11 * 60 + 15,
    6: 14 * 60,
    7: 14 * 60 + 45,
    8: 15 * 60 + 45,
    9: 16 * 60 + 30,
    11: 18 * 60 + 30,
    12: 19 * 60 + 15,
  };

  static const Map<int, int> _jinanEndMinutes = {
    1: 8 * 60 + 40,
    2: 9 * 60 + 25,
    3: 10 * 60 + 25,
    4: 11 * 60 + 10,
    5: 11 * 60 + 55,
    6: 14 * 60 + 40,
    7: 15 * 60 + 25,
    8: 16 * 60 + 25,
    9: 17 * 60 + 10,
    11: 19 * 60 + 10,
    12: 19 * 60 + 55,
  };

  static const Map<int, int> _rizhaoStartMinutes = {
    1: 8 * 60,
    2: 8 * 60 + 45,
    3: 9 * 60 + 45,
    4: 10 * 60 + 30,
    5: 11 * 60 + 15,
    6: 14 * 60,
    7: 14 * 60 + 45,
    8: 15 * 60 + 45,
    9: 16 * 60 + 30,
    10: 17 * 60 + 15,
    11: 19 * 60,
    12: 19 * 60 + 45,
  };

  static const Map<int, int> _rizhaoEndMinutes = {
    1: 8 * 60 + 40,
    2: 9 * 60 + 25,
    3: 10 * 60 + 25,
    4: 11 * 60 + 10,
    5: 11 * 60 + 55,
    6: 14 * 60 + 40,
    7: 15 * 60 + 25,
    8: 16 * 60 + 25,
    9: 17 * 60 + 10,
    10: 17 * 60 + 55,
    11: 19 * 60 + 40,
    12: 20 * 60 + 25,
  };

  static int? periodStartMinutes(int period, {required String campus}) {
    return (campus == campusRizhao ? _rizhaoStartMinutes : _jinanStartMinutes)[period];
  }

  static int? periodEndMinutes(int period, {required String campus}) {
    return (campus == campusRizhao ? _rizhaoEndMinutes : _jinanEndMinutes)[period];
  }

  /// 该校区该节次的下课时间（零点起的分钟数）。
  ///
  /// 节次不存在时（例如济南的第 10 节）返回当天最后一分钟，使调用方的
  /// “是否已下课”判定退化为“保持可见”，不会把课程误判为已结束而隐藏。
  static int endMinutesForUnit(int endUnit, {required String campus}) {
    return periodEndMinutes(endUnit, campus: campus) ?? (23 * 60 + 59);
  }

  static String formatMinutes(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static String formatTimeRange(
    int startPeriod,
    int endPeriod, {
    required String campus,
  }) {
    final start = periodStartMinutes(startPeriod, campus: campus) ?? 0;
    final end = periodEndMinutes(endPeriod, campus: campus) ?? 0;
    return '${formatMinutes(start)} - ${formatMinutes(end)}';
  }

  static String formatScheduleCell(
    int period, {
    required String campus,
  }) {
    final start = periodStartMinutes(period, campus: campus);
    final end = periodEndMinutes(period, campus: campus);
    if (start == null || end == null) return '';
    return '${_shortTime(start)}\n${_shortTime(end)}';
  }

  static String? periodStartTime(
    int period, {
    required String campus,
  }) {
    final start = periodStartMinutes(period, campus: campus);
    if (start == null) return null;
    return formatMinutes(start);
  }

  /// 课表页“上午 / 下午 / 晚上”分组，对应官方作息表的“时段”列。
  ///
  /// 该列按节次划分且两校区一致：上午 1-5 节、下午 6-10 节、晚上 11-12 节。
  /// 注意不能按时间阈值推断——第 5 节 11:15 开始属于上午，日照第 10 节
  /// 17:15 开始属于下午，按节次取值才能与官方表格一致。
  static ClassSession sessionForPeriod(int period) {
    if (period <= 5) return ClassSession.morning;
    if (period <= 10) return ClassSession.afternoon;
    return ClassSession.evening;
  }

  static String _shortTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '$hour:${minute.toString().padLeft(2, '0')}';
  }
}

/// 官方作息表“时段”列的取值：上午 / 下午 / 晚上。
enum ClassSession { morning, afternoon, evening }
