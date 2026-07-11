/// 课表学期/假期状态：用于区分「考试周无课」与「教务未发布课表」。
class ScheduleTermState {
  /// AppBar 等窄位展示用。
  static const String unavailableSubtitle = '假期或未发课表';

  /// 课表页空状态等可展示更多说明的场景。
  static const String unavailableMessage =
      '教务尚未发布课表，请稍后再试或前往教务系统确认';

  /// 课表页在保留本地旧课表时展示的说明。
  static const String keptStaleHint =
      '教务未返回新课表，以下为上次同步的本地课表';

  /// AppBar 副标题：保留本地课表。
  static const String keptStaleSubtitle = '已保留本地课表';

  static bool isTermUnavailable({
    required List<dynamic> schedule,
    required String? startDay,
  }) {
    return schedule.isEmpty && !_hasStartDay(startDay);
  }

  static bool _hasStartDay(String? startDay) {
    return startDay != null && startDay.trim().isNotEmpty;
  }
}
