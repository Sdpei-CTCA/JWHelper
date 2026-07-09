typedef LoadDataFn = Future<void> Function({bool forceRefresh});

class LoginDataCoordinator {
  static Future<void> prepareOnline({
    required LoadDataFn loadGrades,
    required LoadDataFn loadSchedule,
    required LoadDataFn loadProgress,
    required LoadDataFn loadExamSemesters,
  }) async {
    await Future.wait([
      loadGrades(forceRefresh: true),
      loadSchedule(forceRefresh: true),
      loadProgress(forceRefresh: true),
      loadExamSemesters(forceRefresh: true),
    ]);
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
