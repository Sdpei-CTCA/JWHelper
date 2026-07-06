import 'package:JWHelper/features/exam/domain/exam.dart';

class UpcomingExamSelector {
  static List<Exam> select(List<Exam> exams, {int limit = 2}) {
    final now = DateTime.now();
    final upcoming = exams.where((exam) => !_isPast(exam, now)).toList();
    upcoming.sort((a, b) {
      final aTime = _parseSortTime(a.time);
      final bTime = _parseSortTime(b.time);
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return aTime.compareTo(bTime);
    });
    if (upcoming.length <= limit) return upcoming;
    return upcoming.sublist(0, limit);
  }

  static bool _isPast(Exam exam, DateTime now) {
    final examTime = _parseSortTime(exam.time);
    if (examTime == null) return false;
    return examTime.isBefore(now);
  }

  /// Parses common periodTime formats; returns null when unparseable.
  static DateTime? _parseSortTime(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final normalized = trimmed.replaceAll('/', '-');
    final direct = DateTime.tryParse(normalized);
    if (direct != null) return direct;

    final dateTimeMatch = RegExp(
      r'(\d{4}[-/]\d{1,2}[-/]\d{1,2}).*?(\d{1,2}:\d{2})',
    ).firstMatch(trimmed);
    if (dateTimeMatch != null) {
      final datePart = dateTimeMatch.group(1)!.replaceAll('/', '-');
      final timePart = dateTimeMatch.group(2)!;
      return DateTime.tryParse('$datePart $timePart');
    }

    final dateOnly = RegExp(r'(\d{4}[-/]\d{1,2}[-/]\d{1,2})').firstMatch(trimmed);
    if (dateOnly != null) {
      return DateTime.tryParse(dateOnly.group(1)!.replaceAll('/', '-'));
    }

    return null;
  }
}
