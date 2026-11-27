part of data_provider;

extension ProgressDataMixin on DataProvider {
  List<ProgressGroup> get progressGroups => _progressGroups;
  List<ProgressInfo> get progressInfo => _progressInfo;
  bool get progressLoading => _progressLoading;
  bool get progressLoaded => _progressLoaded;
  int get progressRevision => _progressRevision;

  String get _progressCacheKey => OfflineCacheKeys.progress(_username);
  String get _progressCacheTimeKey => OfflineCacheKeys.progressTime(_username);

  void _bumpProgressRevision() {
    _progressRevision++;
  }

  /// 仅从本地缓存预热学业进度，不触发任何网络请求。
  Future<void> loadProgressFromCache() async {
    if (_progressLoaded || _username.isEmpty) return;
    try {
      final cached = await ProgressLoaderUsecase.readCacheOnly(_username);
      if (cached == null || _progressLoaded) return;
      _progressGroups = cached.$1;
      _progressInfo = cached.$2;
      _progressLoaded = true;
      _bumpProgressRevision();
      notifyStateChanged();
      _updateProgressWidget();
    } catch (_) {}
  }

  Future<void> loadProgress({bool forceRefresh = false}) async {
    if (_progressLoaded && !forceRefresh) return;
    if (_progressLoading && !forceRefresh) return;
    if (_username.isEmpty) return;

    if (forceRefresh) {
      _progressLoaded = false;
    }

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

  Future<bool> _fetchGroupDetailDedup(ProgressGroup group) {
    final existing = _inFlightGroupLoads[group.id];
    if (existing != null) return existing;

    final future = _fetchGroupDetailInternal(group).whenComplete(() {
      _inFlightGroupLoads.remove(group.id);
    });
    _inFlightGroupLoads[group.id] = future;
    return future;
  }

  Future<bool> _fetchGroupDetailInternal(ProgressGroup group) async {
    final needsCourses = group.courses == null;
    final needsMinCredits =
        group.required <= 0 && group.id != 'out_of_program';
    if (!needsCourses && !needsMinCredits) return false;

    try {
      final detail = await _progressService.getGroupDetails(group.id);
      var changed = false;
      if (needsCourses) {
        group.courses = detail.courses;
        changed = true;
      }
      if (needsMinCredits &&
          detail.requiredCredits != null &&
          detail.requiredCredits! > 0) {
        group.required = detail.requiredCredits!;
        changed = true;
      }
      return changed;
    } catch (e) {
      debugPrint("Error loading courses for group ${group.id}: $e");
      if (group.courses == null) {
        group.courses = [];
        return true;
      }
      return false;
    }
  }

  Future<void> _loadDetailsInBackground() async {
    if (_progressGroups.isEmpty) return;

    final sessionToken = _dataSessionToken;
    final username = _username;
    final groupsSnapshot = List<ProgressGroup>.from(_progressGroups);

    final results = await Future.wait(
      groupsSnapshot.map(_fetchGroupDetailDedup),
    );
    if (sessionToken != _dataSessionToken || username != _username) return;

    final changed = results.any((updated) => updated);
    if (!changed) return;

    _bumpProgressRevision();
    notifyStateChanged();
    await ProgressLoaderUsecase.saveToCache(
      username: username,
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

    final sessionToken = _dataSessionToken;
    final username = _username;
    final changed = await _fetchGroupDetailDedup(group);
    if (!changed ||
        sessionToken != _dataSessionToken ||
        username != _username) {
      return;
    }

    await ProgressLoaderUsecase.saveToCache(
      username: username,
      groups: _progressGroups,
      info: _progressInfo,
    );
    _bumpProgressRevision();
    notifyStateChanged();
  }
}
