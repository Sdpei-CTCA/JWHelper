part of data_provider;

extension WidgetSyncMixin on DataProvider {
  Future<void> _updateProgressWidget() async {
    if (_progressInfo.isEmpty) return;
    try {
      final gpaValue = ProgressInfo.extractGpaValue(_progressInfo);
      final majorExtra = ProgressInfo.valueContaining(_progressInfo, '主修与方案外获得学分');
      final earned = ProgressInfo.valueContaining(_progressInfo, '已获得学分');
      final required = ProgressInfo.valueContaining(_progressInfo, '要求最低学分');

      await WidgetService.updateProgressWidget(
        gpa: gpaValue,
        majorExtraCredits: majorExtra,
        earnedCredits: earned,
        requiredCredits: required,
      );
    } catch (e) {
      debugPrint("Error updating progress widget: $e");
    }
  }

  Future<void> _updateScheduleWidget() async {
    try {
      final upcoming = UpcomingExamSelector.select(_exams);
      await WidgetService.updateScheduleWidget(
        _schedule,
        currentWeek: _currentWeek,
        startDay: _scheduleStartDay,
        upcomingExams: upcoming,
        campus: _campus,
      );
    } catch (e) {
      debugPrint("Error updating schedule widget: $e");
    }
  }
}
