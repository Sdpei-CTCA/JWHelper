/// 教学作息时间表（官方《教学作息时间安排表》）
///
/// 官方作息时间仅以图片形式发布，接口（`ClassTimePatterns`）只返回
/// 节次与单位（Unit）的映射关系，不包含上下课时间，因此这里硬编码。
///
/// 说明：
/// * 每节 40 分钟。
/// * 济南、日照两校区第 1-9 节一致，仅第 10-12 节不同。
/// * 济南校区没有第 10 节（官方表中该行为 `/`）。
/// * 不分夏令时/冬令时，全天候使用同一张表。
class ClassSchedule {
  ClassSchedule._();

  static const String campusJinan = '济南';
  static const String campusRizhao = '日照';

  /// 节次 -> (开始时间, 结束时间)，时间格式为 `HH:mm`。
  static const Map<String, Map<int, (String, String)>> _table = {
    campusJinan: {
      1: ('08:00', '08:40'),
      2: ('08:45', '09:25'),
      3: ('09:45', '10:25'),
      4: ('10:30', '11:10'),
      5: ('11:15', '11:55'),
      6: ('14:00', '14:40'),
      7: ('14:45', '15:25'),
      8: ('15:45', '16:25'),
      9: ('16:30', '17:10'),
      11: ('18:30', '19:10'),
      12: ('19:15', '19:55'),
    },
    campusRizhao: {
      1: ('08:00', '08:40'),
      2: ('08:45', '09:25'),
      3: ('09:45', '10:25'),
      4: ('10:30', '11:10'),
      5: ('11:15', '11:55'),
      6: ('14:00', '14:40'),
      7: ('14:45', '15:25'),
      8: ('15:45', '16:25'),
      9: ('16:30', '17:10'),
      10: ('17:15', '17:55'),
      11: ('19:00', '19:40'),
      12: ('19:45', '20:25'),
    },
  };

  /// 归一化校区名称，未知校区按济南处理。
  static String normalizeCampus(String? campus) {
    return campus == campusRizhao ? campusRizhao : campusJinan;
  }

  /// 返回指定校区、指定节次的 `(开始时间, 结束时间)`；该节次不存在时返回 `null`。
  static (String, String)? rangeFor(String? campus, int period) {
    return _table[normalizeCampus(campus)]![period];
  }

  /// 指定节次的开始时间（`HH:mm`），节次不存在时返回 `null`。
  static String? startTime(String? campus, int period) => rangeFor(campus, period)?.$1;

  /// 指定节次的结束时间（`HH:mm`），节次不存在时返回 `null`。
  static String? endTime(String? campus, int period) => rangeFor(campus, period)?.$2;

  /// 指定节次的时间区间（`HH:mm-HH:mm`），节次不存在时返回 `null`。
  static String? timeRange(String? campus, int period) {
    final range = rangeFor(campus, period);
    return range == null ? null : '${range.$1}-${range.$2}';
  }

  /// 课程所在的自然时段（课表页“上午 / 下午 / 晚上”分组依据）。
  ///
  /// 按**开始时间**划分（校区感知）：12:00 前为上午，12:00–18:00 为下午，
  /// 18:00 及以后为晚上。例如第 5 节（11:15 开始）属于上午；
  /// 日照第 10 节（17:15）属于下午；第 11 节（济南 18:30 / 日照 19:00）起属于晚上。
  ///
  /// 若该校区没有对应节次的时间（例如济南没有第 10 节），回退到节次阈值
  /// （≤4 上午、≤8 下午、其余晚上），保证课程不会因缺少时间而丢失分组。
  static ClassSession sessionFor(String? campus, int startPeriod) {
    final start = startTime(campus, startPeriod);
    final hour = start == null ? null : int.tryParse(start.split(':').first);
    if (hour == null) {
      if (startPeriod <= 4) return ClassSession.morning;
      if (startPeriod <= 8) return ClassSession.afternoon;
      return ClassSession.evening;
    }
    if (hour < 12) return ClassSession.morning;
    if (hour < 18) return ClassSession.afternoon;
    return ClassSession.evening;
  }
}

/// 课表页“上午 / 下午 / 晚上”分组用的自然时段。
enum ClassSession { morning, afternoon, evening }
