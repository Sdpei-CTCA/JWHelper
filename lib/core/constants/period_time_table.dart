/// Canonical class period times for all campuses.
/// Keep in sync with [ScheduleWidgetTimeTable.kt].
class PeriodTimeTable {
  static const String campusJinan = '济南';
  static const String campusRizhao = '日照';

  static const Map<int, int> _jinanStartMinutes = {
    1: 8 * 60,
    2: 8 * 60 + 45,
    3: 10 * 60,
    4: 10 * 60 + 45,
    5: 13 * 60 + 30,
    6: 14 * 60 + 15,
    7: 15 * 60 + 30,
    8: 16 * 60 + 15,
    9: 19 * 60,
    10: 19 * 60 + 45,
    11: 20 * 60 + 30,
    12: 21 * 60 + 15,
  };

  static const Map<int, int> _jinanEndMinutes = {
    1: 8 * 60 + 45,
    2: 9 * 60 + 30,
    3: 10 * 60 + 45,
    4: 11 * 60 + 30,
    5: 14 * 60 + 15,
    6: 15 * 60,
    7: 16 * 60 + 15,
    8: 17 * 60,
    9: 19 * 60 + 45,
    10: 20 * 60 + 30,
    11: 21 * 60 + 15,
    12: 22 * 60,
  };

  static bool isSummer(DateTime date) {
    final month = date.month;
    if (month > 5 && month < 10) return true;
    if (month == 5) return true;
    return false;
  }

  static int? periodStartMinutes(
    int period, {
    required String campus,
    required DateTime date,
  }) {
    if (campus != campusRizhao) {
      return _jinanStartMinutes[period];
    }
    if (period <= 4) {
      return _jinanStartMinutes[period];
    }

    final summer = isSummer(date);
    switch (period) {
      case 5:
        return summer ? 14 * 60 + 30 : 14 * 60;
      case 6:
        return summer ? 15 * 60 + 20 : 14 * 60 + 50;
      case 7:
        return summer ? 16 * 60 + 30 : 16 * 60;
      case 8:
        return summer ? 17 * 60 + 20 : 16 * 60 + 50;
      case 9:
        return 19 * 60;
      case 10:
        return 19 * 60 + 50;
      case 11:
        return 20 * 60 + 40;
      case 12:
        return 21 * 60 + 30;
      default:
        return null;
    }
  }

  static int? periodEndMinutes(
    int period, {
    required String campus,
    required DateTime date,
  }) {
    if (campus != campusRizhao) {
      return _jinanEndMinutes[period];
    }
    if (period <= 4) {
      return _jinanEndMinutes[period];
    }

    final summer = isSummer(date);
    switch (period) {
      case 5:
        return summer ? 15 * 60 + 10 : 14 * 60 + 40;
      case 6:
        return summer ? 16 * 60 : 15 * 60 + 30;
      case 7:
        return summer ? 17 * 60 + 10 : 16 * 60 + 40;
      case 8:
        return summer ? 18 * 60 : 17 * 60 + 30;
      case 9:
        return 20 * 60 + 30;
      case 10:
        return 21 * 60 + 20;
      case 11:
        return 22 * 60 + 10;
      case 12:
        return 23 * 60;
      default:
        return null;
    }
  }

  static int endMinutesForUnit(
    int endUnit, {
    required String campus,
    required DateTime date,
  }) {
    return periodEndMinutes(endUnit, campus: campus, date: date) ??
        (23 * 60 + 59);
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
    required DateTime date,
  }) {
    final start = periodStartMinutes(startPeriod, campus: campus, date: date) ?? 0;
    final end = periodEndMinutes(endPeriod, campus: campus, date: date) ?? 0;
    return '${formatMinutes(start)} - ${formatMinutes(end)}';
  }

  static String formatScheduleCell(
    int period, {
    required String campus,
    required DateTime date,
  }) {
    final start = periodStartMinutes(period, campus: campus, date: date);
    final end = periodEndMinutes(period, campus: campus, date: date);
    if (start == null || end == null) return '';
    return '${_shortTime(start)}\n${_shortTime(end)}';
  }

  static String? periodStartTime(
    int period, {
    required String campus,
    required DateTime date,
  }) {
    final start = periodStartMinutes(period, campus: campus, date: date);
    if (start == null) return null;
    return formatMinutes(start);
  }

  static String _shortTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '$hour:${minute.toString().padLeft(2, '0')}';
  }
}
