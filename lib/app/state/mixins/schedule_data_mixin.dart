part of data_provider;

extension ScheduleDataMixin on DataProvider {
  List<ScheduleItem> get schedule => _schedule;
  bool get scheduleLoading => _scheduleLoading;
  bool get scheduleLoaded => _scheduleLoaded;
  int get currentWeek => _currentWeek;
  int get daysUntilStart => _daysUntilStart;
  String? get scheduleStartDay => _scheduleStartDay;

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
      if (result.schedule.isNotEmpty) {
        _schedule = result.schedule;
        if (result.startDay != null) {
          _scheduleStartDay = result.startDay;
          _calculateCurrentWeek(result.startDay!);
        }
        _scheduleLoaded = result.loaded;
        notifyStateChanged();
      }
    } catch (_) {}
  }

  Future<void> loadSchedule({bool forceRefresh = false}) async {
    if (_scheduleLoaded && !forceRefresh) return;
    if (_scheduleLoading && !forceRefresh) return;
    if (_username.isEmpty) return;

    if (forceRefresh) {
      _scheduleLoaded = false;
    }

    _scheduleLoading = true;
    notifyStateChanged();

    try {
      final result = await ScheduleLoaderUsecase.execute(
        service: _scheduleService,
        username: _username,
        forceRefresh: forceRefresh,
      );

      if (result.evaluationRequired) {
        _evaluationRequired = true;
        notifyStateChanged();
        return;
      }

      _schedule = result.schedule;
      String? startDayStr = result.startDay;

      if (startDayStr != null) {
        _scheduleStartDay = startDayStr;
        _calculateCurrentWeek(startDayStr);
        // Trigger notification scheduling
        try {
          NotificationService().scheduleClassReminders(
            schedule: _schedule,
            startDay: DateTime.parse(startDayStr),
            campus: _campus,
          );
        } catch (e) {
          debugPrint("Error scheduling notifications: $e");
        }
      }

      _scheduleLoaded = result.loaded;
      _updateScheduleWidget();
    } catch (e) {
      debugPrint("Error loading schedule: $e");
    } finally {
      _scheduleLoading = false;
      notifyStateChanged();
    }
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
