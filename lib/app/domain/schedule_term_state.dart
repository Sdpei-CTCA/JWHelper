/// 课表学期/假期状态：用于区分「考试周无课」与「教务未发布课表」。
class ScheduleTermState {
  /// AppBar 等窄位展示用。
  static const String unavailableSubtitle = '假期或未发课表';

  /// 课表页空状态等可展示更多说明的场景。
  static const String unavailableMessage =
      '教务尚未发布课表，请稍后再试或前往教务系统确认';

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
