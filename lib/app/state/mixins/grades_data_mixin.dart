part of data_provider;

extension GradesDataMixin on DataProvider {

  List<Grade> get grades => _grades;
  bool get gradesLoading => _gradesLoading;
  bool get gradesLoaded => _gradesLoaded;

  List<String> get semesterList {
    if (_grades.isEmpty) return [];
    return _grades.map((e) => e.semester).toSet().toList()..sort((a, b) => b.compareTo(a));
  }

  String get _gradesCacheKey => 'grades_cache_$_username';
  String get _gradesCacheTimeKey => 'grades_cache_time_$_username';

  Future<void> loadGrades({bool forceRefresh = false}) async {
    if (_gradesLoaded && !forceRefresh) return;
    if (_gradesLoading) return;
    if (_username.isEmpty) return;

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
        notifyStateChanged();
        return;
      }

      _grades = result.grades;
      _gradesLoaded = result.loaded;
    } catch (e) {
      debugPrint("Error loading grades: $e");
    } finally {
      _gradesLoading = false;
      notifyStateChanged();
    }
  }
}
