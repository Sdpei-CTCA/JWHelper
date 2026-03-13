part of data_provider;

extension WidgetSyncMixin on DataProvider {
  Future<void> _updateProgressWidget() async {
    if (_progressInfo.isEmpty) return;
    try {
      final gpa = _progressInfo
          .firstWhere((i) => i.label.contains("学位课程绩点"), orElse: () => ProgressInfo(label: "", value: "-"))
          .value;
      final gpaMatch = RegExp(r'\d+(\.\d+)?').firstMatch(gpa);
      final gpaValue = gpaMatch?.group(0) ?? (gpa.length > 4 ? gpa.substring(0, 4) : gpa);

      final majorExtra = _progressInfo
          .firstWhere((i) => i.label.contains("主修与方案外获得学分"), orElse: () => ProgressInfo(label: "", value: "-"))
          .value;
      final earned = _progressInfo
          .firstWhere((i) => i.label.contains("已获得学分"), orElse: () => ProgressInfo(label: "", value: "-"))
          .value;
      final required = _progressInfo
          .firstWhere((i) => i.label.contains("要求最低学分"), orElse: () => ProgressInfo(label: "", value: "-"))
          .value;

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
      await WidgetService.updateScheduleWidget(_schedule, currentWeek: _currentWeek);
    } catch (e) {
      debugPrint("Error updating schedule widget: $e");
    }
  }
}
