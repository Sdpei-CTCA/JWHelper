class ScheduleItem {
  /// 课表网格支持的最大教学周（与网格 PageView 页数一致）。
  static const int maxTeachingWeeks = 25;

  final String name;
  final String teacher;
  final String classroom;
  final int dayIndex; // 0-6
  final int startUnit;
  final int endUnit;
  final int weekStart;
  final int weekEnd;

  /// 明确的上课周次集合（升序、去重）。
  ///
  /// 为 null 时表示使用连续区间 [weekStart, weekEnd]（教务原始数据）。
  /// 调课 / 自定义课程会写入该字段，此时 weekStart/weekEnd 为其最小/最大值，
  /// 便于旧逻辑继续使用。
  final List<int>? weeks;

  ScheduleItem({
    required this.name,
    required this.teacher,
    required this.classroom,
    required this.dayIndex,
    required this.startUnit,
    required this.endUnit,
    this.weekStart = 0,
    this.weekEnd = 0,
    this.weeks,
  });

  /// 以明确周次集合创建课程，自动推算 weekStart/weekEnd。
  factory ScheduleItem.withWeeks({
    required String name,
    required String teacher,
    required String classroom,
    required int dayIndex,
    required int startUnit,
    required int endUnit,
    required Iterable<int> weeks,
  }) {
    final normalized = normalizeWeeks(weeks);
    return ScheduleItem(
      name: name,
      teacher: teacher,
      classroom: classroom,
      dayIndex: dayIndex,
      startUnit: startUnit,
      endUnit: endUnit,
      weekStart: normalized.isEmpty ? 0 : normalized.first,
      weekEnd: normalized.isEmpty ? 0 : normalized.last,
      weeks: normalized,
    );
  }

  static List<int> normalizeWeeks(Iterable<int> weeks) {
    final list = weeks.where((w) => w > 0).toSet().toList()..sort();
    return list;
  }

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    final rawWeeks = json['weeks'];
    List<int>? weeks;
    if (rawWeeks is List) {
      weeks = normalizeWeeks(rawWeeks.map((e) => (e as num).toInt()));
    }
    return ScheduleItem(
      name: json['name'] ?? "",
      teacher: json['teacher'] ?? "",
      classroom: json['classroom'] ?? "",
      dayIndex: json['dayIndex'] ?? 0,
      startUnit: json['startUnit'] ?? 0,
      endUnit: json['endUnit'] ?? 0,
      weekStart: json['weekStart'] ?? 0,
      weekEnd: json['weekEnd'] ?? 0,
      weeks: weeks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'teacher': teacher,
      'classroom': classroom,
      'dayIndex': dayIndex,
      'startUnit': startUnit,
      'endUnit': endUnit,
      'weekStart': weekStart,
      'weekEnd': weekEnd,
      if (weeks != null) 'weeks': weeks,
    };
  }

  /// 该课程在第 [week] 周是否上课。
  bool occursInWeek(int week) {
    if (weeks != null) return weeks!.contains(week);
    if (weekStart > 0 && weekEnd > 0) {
      return week >= weekStart && week <= weekEnd;
    }
    return true;
  }

  /// 所有上课周（未知周次时返回空列表）。
  List<int> get activeWeeks {
    if (weeks != null) return List<int>.from(weeks!);
    if (weekStart > 0 && weekEnd >= weekStart) {
      return [for (var w = weekStart; w <= weekEnd; w++) w];
    }
    return const [];
  }

  /// 是否有已知的周次信息。
  bool get hasWeekInfo => weeks != null || (weekStart > 0 && weekEnd > 0);

  ScheduleItem copyWith({
    String? name,
    String? teacher,
    String? classroom,
    int? dayIndex,
    int? startUnit,
    int? endUnit,
    Iterable<int>? weeks,
  }) {
    final base = ScheduleItem(
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      classroom: classroom ?? this.classroom,
      dayIndex: dayIndex ?? this.dayIndex,
      startUnit: startUnit ?? this.startUnit,
      endUnit: endUnit ?? this.endUnit,
      weekStart: weekStart,
      weekEnd: weekEnd,
      weeks: this.weeks,
    );
    if (weeks == null) return base;
    return ScheduleItem.withWeeks(
      name: base.name,
      teacher: base.teacher,
      classroom: base.classroom,
      dayIndex: base.dayIndex,
      startUnit: base.startUnit,
      endUnit: base.endUnit,
      weeks: weeks,
    );
  }

  String get periodString {
    return "$startPeriod-$endPeriod节";
  }

  int get startPeriod => startUnit;
  int get endPeriod => endUnit;

  int get unitSpan => endUnit - startUnit + 1;

  /// 周次的简短描述，例如 `1-16周`、`1-4,6-16周`、`1-15周(单)`。
  String get weeksLabel => formatWeeks(activeWeeks);

  static String formatWeeks(List<int> weeks) {
    if (weeks.isEmpty) return '';
    final sorted = normalizeWeeks(weeks);
    if (sorted.length >= 3) {
      final step = sorted[1] - sorted[0];
      var uniform = step == 2;
      for (var i = 2; i < sorted.length && uniform; i++) {
        if (sorted[i] - sorted[i - 1] != 2) uniform = false;
      }
      if (uniform) {
        final parity = sorted.first.isOdd ? '单' : '双';
        return '${sorted.first}-${sorted.last}周($parity)';
      }
    }
    final parts = <String>[];
    var start = sorted.first;
    var prev = sorted.first;
    for (var i = 1; i <= sorted.length; i++) {
      final isEnd = i == sorted.length || sorted[i] != prev + 1;
      if (isEnd) {
        parts.add(start == prev ? '$start' : '$start-$prev');
        if (i < sorted.length) {
          start = sorted[i];
          prev = sorted[i];
        }
      } else {
        prev = sorted[i];
      }
    }
    return '${parts.join(',')}周';
  }
}
