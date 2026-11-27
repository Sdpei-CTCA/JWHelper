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
      !_scheduleKeptStaleCache &&
      ScheduleTermState.isTermUnavailable(
        schedule: _schedule,
        startDay: _scheduleStartDay,
      );

  bool get isScheduleKeptStaleCache => _scheduleKeptStaleCache;

  String? get scheduleTermSubtitle =>
      isScheduleTermUnavailable ? ScheduleTermState.unavailableSubtitle : null;

  String? get scheduleTermHint =>
      isScheduleTermUnavailable ? ScheduleTermState.unavailableMessage : null;

  String? get scheduleKeptStaleSubtitle =>
      _scheduleKeptStaleCache ? ScheduleTermState.keptStaleSubtitle : null;

  String? get scheduleKeptStaleHint =>
      _scheduleKeptStaleCache ? ScheduleTermState.keptStaleHint : null;

  void _applyScheduleResult({
    required List<ScheduleItem> schedule,
    required String? startDay,
    required bool loaded,
  }) {
    _clearKeptStaleCacheFlag();
    _setSchedule(schedule);
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

  void _applyKeptStaleCacheResult(ScheduleLoadResult result) {
    _scheduleKeptStaleCache = true;
    _setSchedule(result.schedule);
    _scheduleLoaded = result.loaded;
    if (result.startDay != null && result.startDay!.trim().isNotEmpty) {
      _scheduleStartDay = result.startDay;
      _calculateCurrentWeek(result.startDay!);
    } else {
      _scheduleStartDay = null;
      _currentWeek = 0;
      _daysUntilStart = 0;
    }
  }

  void _clearKeptStaleCacheFlag() {
    _scheduleKeptStaleCache = false;
  }

  Map<int, List<ScheduleItem>> get scheduleGroupedByDay {
    final cached = _cachedScheduleGroupedByDay;
    if (cached != null) return cached;

    final Map<int, List<ScheduleItem>> grouped = {};
    for (final item in _schedule) {
      (grouped[item.dayIndex] ??= []).add(item);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.startUnit.compareTo(b.startUnit));
    }
    _cachedScheduleGroupedByDay = grouped;
    return grouped;
  }

  String get _scheduleCacheKey => OfflineCacheKeys.schedule(_username);
  String get _scheduleCacheTimeKey => OfflineCacheKeys.scheduleTime(_username);

  /// 仅用内存已有课表重排本地课前提醒与桌面小组件，不触发网络刷新。
  Future<void> rescheduleScheduleOutputs() => _afterScheduleChanged();

  /// Load schedule from cache only (no network, no loading spinner).
  /// Call this in initState before the first frame.
  Future<void> loadScheduleFromCache() async {
    if (_scheduleLoaded || _username.isEmpty) return;
    try {
      final result = await ScheduleLoaderUsecase.readCacheOnly(_username);
      if (result == null || !result.loaded || _scheduleLoaded) return;

      final shouldApply = result.localMode ||
          result.schedule.isNotEmpty ||
          ScheduleTermState.isTermUnavailable(
            schedule: result.schedule,
            startDay: result.startDay,
          );
      if (!shouldApply) return;

      _scheduleLocalMode = result.localMode;
      _applyScheduleResult(
        schedule: result.schedule,
        startDay: result.startDay,
        loaded: result.loaded,
      );
      notifyStateChanged();
      // 仅更新本地桌面小组件，避免在登录态建立前于考试周触发网络拉取考试列表。
      _updateScheduleWidget();
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
      _scheduleLocalMode = result.localMode;

      if (result.keptLocalCacheOnEmpty) {
        refreshMessage = '教务未返回数据，已保留本地课表';
        _applyKeptStaleCacheResult(result);
        return refreshMessage;
      }

      if (result.evaluationRequired) {
        _evaluationRequired = true;
        if (result.schedule.isNotEmpty ||
            ScheduleTermState.isTermUnavailable(
              schedule: result.schedule,
              startDay: result.startDay,
            )) {
          _applyScheduleResult(
            schedule: result.schedule,
            startDay: result.startDay,
            loaded: result.loaded,
          );
        }
        return refreshMessage;
      }

      _applyScheduleResult(
        schedule: result.schedule,
        startDay: result.startDay,
        loaded: result.loaded,
      );

      await _afterScheduleChanged();
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
