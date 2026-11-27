part of data_provider;

extension GradesDataMixin on DataProvider {
  List<Grade> get grades => _grades;
  bool get gradesLoading => _gradesLoading;
  bool get gradesLoaded => _gradesLoaded;

  List<String> get semesterList {
    final cached = _cachedSemesterList;
    if (cached != null) return cached;
    if (_grades.isEmpty) {
      _cachedSemesterList = const [];
      return _cachedSemesterList!;
    }
    final list = _grades.map((e) => e.semester).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    _cachedSemesterList = list;
    return list;
  }

  String get _gradesCacheKey => OfflineCacheKeys.grades(_username);
  String get _gradesCacheTimeKey => OfflineCacheKeys.gradesTime(_username);

  /// 仅从本地缓存预热成绩，不触发任何网络请求。
  Future<void> loadGradesFromCache() async {
    if (_gradesLoaded || _username.isEmpty) return;
    try {
      final cached = await GradesLoaderUsecase.readCacheOnly(_username);
      if (cached == null || _gradesLoaded) return;
      _setGrades(cached);
      _gradesLoaded = true;
      notifyStateChanged();
    } catch (_) {}
  }

  Future<void> loadGrades({bool forceRefresh = false}) async {
    if (_gradesLoaded && !forceRefresh) return;
    if (_gradesLoading && !forceRefresh) return;
    if (_username.isEmpty) return;

    if (forceRefresh) {
      _gradesLoaded = false;
    }

    _gradesLoading = true;
    notifyStateChanged();

    try {
      final result = await GradesLoaderUsecase.execute(
        service: _gradesService,
        username: _username,
        forceRefresh: forceRefresh,
      );

      if (result.evaluationRequired) {
        _evaluationRequired = true;
        if (result.grades.isNotEmpty) {
          _setGrades(result.grades);
          _gradesLoaded = result.loaded;
        }
        return;
      }

      _setGrades(result.grades);
      _gradesLoaded = result.loaded;
    } catch (e) {
      debugPrint("Error loading grades: $e");
      rethrow;
    } finally {
      _gradesLoading = false;
      notifyStateChanged();
    }
  }
}
