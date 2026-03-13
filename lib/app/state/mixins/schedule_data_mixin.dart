part of data_provider;

extension ScheduleDataMixin on DataProvider {

  List<ScheduleItem> get schedule => _schedule;
  bool get scheduleLoading => _scheduleLoading;
  bool get scheduleLoaded => _scheduleLoaded;
  int get currentWeek => _currentWeek;
  int get daysUntilStart => _daysUntilStart;

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

  Future<void> loadSchedule({bool forceRefresh = false}) async {
    if (_scheduleLoaded && !forceRefresh) return;
    if (_scheduleLoading) return;
    if (_username.isEmpty) return;

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
        _calculateCurrentWeek(startDayStr);
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
      debugPrint("Calculated Current Week: $_currentWeek (Start: $startDayStr), DaysUntilStart: $_daysUntilStart");
    } catch (e) {
      debugPrint("Error calculating current week: $e");
    }
  }
}
