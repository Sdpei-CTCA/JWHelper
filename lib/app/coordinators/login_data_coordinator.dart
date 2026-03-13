typedef LoadDataFn = Future<void> Function({bool forceRefresh});
typedef ClearCacheFn = Future<void> Function();

class LoginDataCoordinator {
  static Future<void> prepareOnline({
    required ClearCacheFn clearCache,
    required LoadDataFn loadGrades,
    required LoadDataFn loadSchedule,
    required LoadDataFn loadProgress,
    required LoadDataFn loadExamSemesters,
  }) async {
    loadGrades(forceRefresh: true);
    loadSchedule(forceRefresh: true);
    loadProgress(forceRefresh: true);
    loadExamSemesters(forceRefresh: true);
  }

  static void prepareOffline({
    required LoadDataFn loadGrades,
    required LoadDataFn loadSchedule,
    required LoadDataFn loadProgress,
    required LoadDataFn loadExamSemesters,
  }) {
    loadGrades();
    loadSchedule();
    loadProgress();
    loadExamSemesters();
  }
}
