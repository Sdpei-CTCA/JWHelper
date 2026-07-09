import 'package:shared_preferences/shared_preferences.dart';

class OfflineCacheKeys {
  static String grades(String username) => 'grades_cache_$username';
  static String schedule(String username) => 'schedule_cache_$username';
  static String progress(String username) => 'progress_cache_$username';
  static String examSemesters(String username) => 'exam_semesters_$username';

  static bool belongsToUser(String key, String username) {
    if (username.isEmpty) return false;
    return key.endsWith('_$username');
  }

  static bool isExamCacheKey(String key) {
    return key.startsWith('exam_') ||
        key.startsWith('exams_') ||
        key.startsWith('exam_rounds_');
  }

  static bool hasOfflineCache(SharedPreferences prefs, String username) {
    if (username.isEmpty) return false;

    final fixedKeys = <String>[
      grades(username),
      schedule(username),
      progress(username),
      examSemesters(username),
    ];

    for (final key in fixedKeys) {
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) {
        return true;
      }
    }

    for (final key in prefs.getKeys()) {
      if ((key.startsWith('exams_') || key.startsWith('exam_rounds_')) &&
          belongsToUser(key, username)) {
        final value = prefs.getString(key);
        if (value != null && value.isNotEmpty) {
          return true;
        }
      }
    }

    return false;
  }
}
