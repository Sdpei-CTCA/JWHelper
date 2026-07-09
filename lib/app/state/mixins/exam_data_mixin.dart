part of data_provider;

extension ExamDataMixin on DataProvider {
  List<Semester> get examSemesters => _examSemesters;
  List<ExamRound> get examRounds => _examRounds;
  List<Exam> get exams => _exams;
  bool get examsLoading => _examsLoading;
  bool get examsLoaded => _examsLoaded;

  Future<void> loadExamSemesters({bool forceRefresh = false}) async {
    if (_examSemesters.isNotEmpty && !forceRefresh) return;
    if (_username.isEmpty) return;

    try {
      final result = await ExamLoaderUsecase.loadSemesters(
        service: _examService,
        username: _username,
        forceRefresh: forceRefresh,
      );
      _examSemesters = result.semesters;
      notifyStateChanged();
    } catch (e) {
      debugPrint("Error loading exam semesters: $e");
    }
  }

  Future<void> loadExamRounds(String semId, {bool forceRefresh = false}) async {
    if (_username.isEmpty) return;

    if (_loadedExamSemId != semId) {
      _exams = [];
      _examsLoaded = false;
      _loadedExamSemId = null;
      _loadedExamRoundId = null;
      notifyStateChanged();
    }

    try {
      final result = await ExamLoaderUsecase.loadRounds(
        service: _examService,
        username: _username,
        semId: semId,
        forceRefresh: forceRefresh,
      );
      _examRounds = result.rounds;
      notifyStateChanged();
    } catch (e) {
      debugPrint("Error loading exam rounds: $e");
    }
  }

  Future<void> loadExams(String semId, String roundId,
      {bool forceRefresh = false}) async {
    if (_username.isEmpty) return;

    final sameSelection =
        _loadedExamSemId == semId && _loadedExamRoundId == roundId;
    if (_examsLoaded && sameSelection && !forceRefresh) return;
    if (_examsLoading && sameSelection && !forceRefresh) return;

    if (!sameSelection) {
      _exams = [];
      _examsLoaded = false;
    }

    if (forceRefresh) {
      _examsLoaded = false;
    }

    _examsLoading = true;
    notifyStateChanged();

    try {
      final result = await ExamLoaderUsecase.loadExams(
        service: _examService,
        username: _username,
        semId: semId,
        roundId: roundId,
        forceRefresh: forceRefresh,
      );
      _exams = result.exams;
      _examsLoaded = result.loaded;
      _loadedExamSemId = semId;
      _loadedExamRoundId = roundId;
    } catch (e) {
      debugPrint("Error loading exams: $e");
    } finally {
      _examsLoading = false;
      notifyStateChanged();
    }
  }

  Future<void> loadExamsFallback({
    required String semId,
    required String etId,
    required String semName,
    required String etName,
  }) async {
    if (_username.isEmpty) return;

    _examsLoading = true;
    notifyStateChanged();

    try {
      final result = await ExamLoaderUsecase.loadExamsFallback(
        service: _examService,
        username: _username,
        semId: semId,
        etId: etId,
        semName: semName,
        etName: etName,
      );
      _exams = result.exams;
      _examsLoaded = result.loaded;
      _loadedExamSemId = semId;
      _loadedExamRoundId = etId;
    } catch (e) {
      debugPrint("Error loading exams fallback: $e");
      rethrow;
    } finally {
      _examsLoading = false;
      notifyStateChanged();
    }
  }

  Future<List<int>> exportExamTable({
    required String semId,
    required String etId,
    required String semName,
    required String etName,
  }) async {
    return await _examService.exportExamTable(
      semId: semId,
      etId: etId,
      semName: semName,
      etName: etName,
    );
  }

  Future<void> loadDefaultExamsForWidget({bool forceRefresh = false}) async {
    if (_username.isEmpty) return;

    await loadExamSemesters(forceRefresh: forceRefresh);
    if (_examSemesters.isEmpty) {
      await _updateScheduleWidget();
      return;
    }

    final campus = _campus;
    final semId = _examSemesters.first.id;
    await loadExamRounds(semId, forceRefresh: forceRefresh);

    final selection = ExamSelectionCoordinator.resolve(
      semesters: _examSemesters,
      rounds: _examRounds,
      campus: campus,
    );
    if (selection != null) {
      await loadExams(
        selection.semId,
        selection.roundId,
        forceRefresh: forceRefresh,
      );
    }
    await _updateScheduleWidget();
  }
}
