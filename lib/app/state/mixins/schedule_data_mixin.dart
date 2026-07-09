part of data_provider;

extension ScheduleDataMixin on DataProvider {
  List<ScheduleItem> get schedule => _schedule;
  bool get scheduleLoading => _scheduleLoading;
  bool get scheduleLoaded => _scheduleLoaded;
  int get currentWeek => _currentWeek;
  int get daysUntilStart => _daysUntilStart;
  String? get scheduleStartDay => _scheduleStartDay;

  bool get isScheduleTermUnavailable =>
      _scheduleLoaded &&
      ScheduleTermState.isTermUnavailable(
        schedule: _schedule,
        startDay: _scheduleStartDay,
      );

  String? get scheduleTermSubtitle =>
      isScheduleTermUnavailable ? ScheduleTermState.unavailableSubtitle : null;

  String? get scheduleTermHint =>
      isScheduleTermUnavailable ? ScheduleTermState.unavailableMessage : null;

  void _applyScheduleResult({
    required List<ScheduleItem> schedule,
    required String? startDay,
    required bool loaded,
  }) {
    _schedule = schedule;
    if (ScheduleTermState.isTermUnavailable(
      schedule: schedule,
      startDay: startDay,
    )) {
      _scheduleStartDay = null;
      _currentWeek = 0;
      _daysUntilStart = 0;
    } else if (startDay != null) {
      _scheduleStartDay = startDay;
      _calculateCurrentWeek(startDay);
    }
    _scheduleLoaded = loaded;
  }

  Map<int, List<ScheduleItem>> get scheduleGroupedByDay {
    final Map<int, List<ScheduleItem>> grouped = {};
    for (var item in _schedule) {
      if (!grouped.containsKey(item.dayIndex)) {
        grouped[item.dayIndex] = [];
      }
      grouped[item.dayIndex]!.add(item);
    }
    for (var key in grouped.keys) {
      grouped[key]!.sort((a, b) => a.startUnit.compareTo(b.startUnit));
    }
    return grouped;
  }

  String get _scheduleCacheKey => 'schedule_cache_$_username';
  String get _scheduleCacheTimeKey => 'schedule_cache_time_$_username';

  /// Load schedule from cache synchronously (no loading spinner).
  /// Call this in initState before the first frame.
  Future<void> loadScheduleFromCache() async {
    if (_scheduleLoaded || _username.isEmpty) return;
    try {
      final result = await ScheduleLoaderUsecase.execute(
        service: _scheduleService,
        username: _username,
        forceRefresh: false,
      );
      if (!result.loaded) return;

      final shouldApply = result.schedule.isNotEmpty ||
          ScheduleTermState.isTermUnavailable(
            schedule: result.schedule,
            startDay: result.startDay,
          );
      if (!shouldApply) return;

      _applyScheduleResult(
        schedule: result.schedule,
        startDay: result.startDay,
        loaded: result.loaded,
      );
      notifyStateChanged();
      if (ScheduleWeekContext.isExamPeriod(_schedule, _currentWeek)) {
        loadDefaultExamsForWidget();
      } else {
        _updateScheduleWidget();
      }
    } catch (_) {}
  }

  Future<String?> loadSchedule({bool forceRefresh = false}) async {
    if (_scheduleLoaded && !forceRefresh) return null;
    if (_scheduleLoading && !forceRefresh) return null;
    if (_username.isEmpty) return null;

    if (forceRefresh) {
      _scheduleLoaded = false;
    }

    _scheduleLoading = true;
    notifyStateChanged();

    String? refreshMessage;
    try {
      final result = await ScheduleLoaderUsecase.execute(
        service: _scheduleService,
        username: _username,
        forceRefresh: forceRefresh,
      );

      if (result.keptLocalCacheOnEmpty) {
        refreshMessage = '教务未返回数据，已保留本地课表';
      }

      if (result.evaluationRequired) {
        _evaluationRequired = true;
        notifyStateChanged();
        return refreshMessage;
      }

      _applyScheduleResult(
        schedule: result.schedule,
        startDay: result.startDay,
        loaded: result.loaded,
      );

      if (!isScheduleTermUnavailable &&
          result.startDay != null &&
          result.schedule.isNotEmpty) {
        try {
          NotificationService().scheduleClassReminders(
            schedule: _schedule,
            startDay: DateTime.parse(result.startDay!),
            campus: _campus,
          );
        } catch (e) {
          debugPrint("Error scheduling notifications: $e");
        }
      }

      if (ScheduleWeekContext.isExamPeriod(_schedule, _currentWeek)) {
        await loadDefaultExamsForWidget();
      } else {
        await _updateScheduleWidget();
      }
    } catch (e) {
      debugPrint("Error loading schedule: $e");
    } finally {
      _scheduleLoading = false;
      notifyStateChanged();
    }
    return refreshMessage;
  }

  void _calculateCurrentWeek(String startDayStr) {
    try {
      DateTime startDay = DateTime.parse(startDayStr);
      DateTime now = DateTime.now();
      startDay = DateTime(startDay.year, startDay.month, startDay.day);
      now = DateTime(now.year, now.month, now.day);

      int diffDays = now.difference(startDay).inDays;
      debugPrint("Now: $now, StartDay: $startDay, DiffDays: $diffDays");

      if (diffDays >= 0) {
        _currentWeek = (diffDays / 7).floor() + 1;
        _daysUntilStart = 0;
      } else {
        _currentWeek = 1;
        _daysUntilStart = -diffDays;
      }
      debugPrint(
          "Calculated Current Week: $_currentWeek (Start: $startDayStr), DaysUntilStart: $_daysUntilStart");
    } catch (e) {
      debugPrint("Error calculating current week: $e");
    }
  }
}
