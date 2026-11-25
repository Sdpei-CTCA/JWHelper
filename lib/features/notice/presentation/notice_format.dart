/// 通知列表里的日期文案：今天 / 昨天 / 11月25日 / 2025年11月25日。
///
/// 只精确到天：学校列表页一般只给日期，不问具体时刻，写「今天」比写
/// 「2026-11-25」更容易一眼扫过去。
String formatNoticeDate(DateTime? date) {
  if (date == null) return '';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = today.difference(target).inDays;

  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  if (date.year == now.year) return '${date.month}月${date.day}日';
  return '${date.year}年${date.month}月${date.day}日';
}

/// 详情页头部用的完整日期。
String formatNoticeFullDate(DateTime? date) {
  if (date == null) return '';
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
