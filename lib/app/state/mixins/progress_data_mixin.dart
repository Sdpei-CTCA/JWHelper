part of data_provider;

extension ProgressDataMixin on DataProvider {

  List<ProgressGroup> get progressGroups => _progressGroups;
  List<ProgressInfo> get progressInfo => _progressInfo;
  bool get progressLoading => _progressLoading;
  bool get progressLoaded => _progressLoaded;

  String get _progressCacheKey => 'progress_cache_$_username';
  String get _progressCacheTimeKey => 'progress_cache_time_$_username';

  Future<void> loadProgress({bool forceRefresh = false}) async {
    if (_progressLoaded && !forceRefresh) return;
    if (_progressLoading) return;
    if (_username.isEmpty) return;

    _progressLoading = true;
    notifyStateChanged();

    try {
      final result = await ProgressLoaderUsecase.execute(
        service: _progressService,
        username: _username,
        forceRefresh: forceRefresh,
      );

      _progressGroups = result.groups;
      _progressInfo = result.info;
      _progressLoaded = result.loaded;
      _updateProgressWidget();
      _loadDetailsInBackground();
    } catch (e) {
      debugPrint("Error loading progress: $e");
    } finally {
      _progressLoading = false;
      notifyStateChanged();
    }
  }

  Future<void> _loadDetailsInBackground() async {
    if (_progressGroups.isEmpty) return;

    var futures = _progressGroups.map((group) async {
      try {
        if (group.courses == null) {
          group.courses = await _progressService.getGroupCourses(group.id);
          notifyStateChanged();
        }
      } catch (e) {
        debugPrint("Error loading courses for group ${group.id}: $e");
      }
    });

    await Future.wait(futures);
    await ProgressLoaderUsecase.saveToCache(
      username: _username,
      groups: _progressGroups,
      info: _progressInfo,
    );
  }

  Future<void> loadGroupCourses(ProgressGroup group) async {
    if (group.courses != null) return;

    try {
      var courses = await _progressService.getGroupCourses(group.id);
      group.courses = courses;
      await ProgressLoaderUsecase.saveToCache(
        username: _username,
        groups: _progressGroups,
        info: _progressInfo,
      );
      notifyStateChanged();
    } catch (e) {
      debugPrint("Error loading group courses: $e");
      group.courses = [];
      notifyStateChanged();
    }
  }
}
