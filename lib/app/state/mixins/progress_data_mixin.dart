part of data_provider;

extension ProgressDataMixin on DataProvider {
  List<ProgressGroup> get progressGroups => _progressGroups;
  List<ProgressInfo> get progressInfo => _progressInfo;
  bool get progressLoading => _progressLoading;
  bool get progressLoaded => _progressLoaded;
  int get progressRevision => _progressRevision;

  String get _progressCacheKey => 'progress_cache_$_username';
  String get _progressCacheTimeKey => 'progress_cache_time_$_username';

  void _bumpProgressRevision() {
    _progressRevision++;
  }

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

      final oldCoursesById = {
        for (final g in _progressGroups) g.id: g.courses,
      };
      _progressGroups = result.groups;
      for (final g in _progressGroups) {
        final cached = oldCoursesById[g.id];
        if (cached != null) {
          g.courses = cached;
        }
      }
      _progressInfo = result.info;
      _progressLoaded = result.loaded;
      _bumpProgressRevision();
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

    var changed = false;
    var futures = _progressGroups.map((group) async {
      try {
        if (group.courses == null) {
          group.courses = await _progressService.getGroupCourses(group.id);
          changed = true;
        }
      } catch (e) {
        debugPrint("Error loading courses for group ${group.id}: $e");
        group.courses = [];
        changed = true;
      }
    });

    await Future.wait(futures);
    if (changed) {
      _bumpProgressRevision();
      notifyStateChanged();
    }
    await ProgressLoaderUsecase.saveToCache(
      username: _username,
      groups: _progressGroups,
      info: _progressInfo,
    );
  }

  Future<void> loadGroupCoursesById(String groupId) async {
    final ProgressGroup group;
    try {
      group = _progressGroups.firstWhere((g) => g.id == groupId);
    } catch (_) {
      return;
    }
    if (group.courses != null) return;

    try {
      group.courses = await _progressService.getGroupCourses(group.id);
      await ProgressLoaderUsecase.saveToCache(
        username: _username,
        groups: _progressGroups,
        info: _progressInfo,
      );
      _bumpProgressRevision();
      notifyStateChanged();
    } catch (e) {
      debugPrint("Error loading group courses: $e");
      group.courses = [];
      _bumpProgressRevision();
      notifyStateChanged();
    }
  }
}
