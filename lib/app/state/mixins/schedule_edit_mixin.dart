part of data_provider;

/// 调课 / 自定义课程 / 恢复课表。
///
/// 任何一次编辑都会把课表写入本地缓存并进入「本地模式」，此后不再自动与教务同步，
/// 直到用户手动恢复（[restoreScheduleFromServer]）。
extension ScheduleEditMixin on DataProvider {
  bool get isScheduleLocalMode => _scheduleLocalMode;

  /// 删除 [item] 在第 [week] 周的这一次课。
  Future<void> deleteScheduleOccurrence(ScheduleItem item, int week) {
    return _commitScheduleEdit(
      ScheduleEditor.removeOccurrence(_schedule, item, week),
    );
  }

  /// 把 [item] 第 [fromWeek] 周的这一次课调到第 [toWeek] 周星期 [toDay] 第 [toStartUnit] 节。
  Future<void> moveScheduleOccurrence(
    ScheduleItem item, {
    required int fromWeek,
    required int toWeek,
    required int toDay,
    required int toStartUnit,
  }) {
    return _commitScheduleEdit(
      ScheduleEditor.moveOccurrence(
        _schedule,
        item,
        fromWeek: fromWeek,
        toWeek: toWeek,
        toDay: toDay,
        toStartUnit: toStartUnit,
      ),
    );
  }

  Future<void> addCustomCourse(ScheduleItem item) {
    return _commitScheduleEdit(ScheduleEditor.add(_schedule, item));
  }

  Future<void> updateCourse(ScheduleItem oldItem, ScheduleItem newItem) {
    return _commitScheduleEdit(
      ScheduleEditor.replace(_schedule, oldItem, newItem),
    );
  }

  Future<void> removeCourse(ScheduleItem item) {
    return _commitScheduleEdit(ScheduleEditor.removeCourse(_schedule, item));
  }

  /// 从教务网站重新拉取课表，覆盖本地自定义课表。
  ///
  /// 返回给用户展示的结果文案。失败时本地课表保持不变。
  Future<String> restoreScheduleFromServer() async {
    if (_username.isEmpty) return '请先登录后再恢复课表';
    if (_scheduleLoading) return '课表正在加载，请稍后再试';

    _scheduleLoading = true;
    notifyStateChanged();
    try {
      final result = await ScheduleLoaderUsecase.restoreFromServer(
        service: _scheduleService,
        username: _username,
      );
      _scheduleLocalMode = false;
      _applyScheduleResult(
        schedule: result.schedule,
        startDay: result.startDay,
        loaded: true,
      );
      await _afterScheduleChanged();
      return '已从教务恢复最新课表';
    } on ScheduleRestoreException catch (e) {
      return e.message;
    } on EvaluationRequiredException {
      return '需要先完成教学评价才能获取课表，已保留当前课表';
    } catch (e) {
      debugPrint('Restore schedule failed: $e');
      return '恢复失败，已保留当前课表';
    } finally {
      _scheduleLoading = false;
      notifyStateChanged();
    }
  }

  Future<void> _commitScheduleEdit(List<ScheduleItem> next) async {
    _setSchedule(next);
    _scheduleLocalMode = true;
    _scheduleKeptStaleCache = false;
    _scheduleLoaded = true;
    notifyStateChanged();

    if (_username.isNotEmpty) {
      try {
        await ScheduleLoaderUsecase.saveLocalSchedule(
          username: _username,
          schedule: _schedule,
          startDay: _scheduleStartDay,
        );
      } catch (e) {
        debugPrint('Error saving local schedule: $e');
      }
    }
    await _afterScheduleChanged();
  }

  /// 课表变化后同步课前提醒与桌面小组件。
  Future<void> _afterScheduleChanged() async {
    final startDay = _scheduleStartDay;
    if (!isScheduleTermUnavailable &&
        startDay != null &&
        _schedule.isNotEmpty) {
      try {
        await NotificationService().scheduleClassReminders(
          schedule: _schedule,
          startDay: DateTime.parse(startDay),
          campus: _campus,
        );
      } catch (e) {
        debugPrint('Error scheduling notifications: $e');
      }
    }
    try {
      if (ScheduleWeekContext.isExamPeriod(_schedule, _currentWeek)) {
        await loadDefaultExamsForWidget();
      } else {
        await _updateScheduleWidget();
      }
    } catch (e) {
      debugPrint('Error updating schedule widget: $e');
    }
  }
}
