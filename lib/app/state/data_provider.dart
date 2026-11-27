library data_provider;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/features/grades/data/grades_service.dart';
import 'package:JWHelper/features/schedule/data/schedule_service.dart';
import 'package:JWHelper/features/progress/data/progress_service.dart';
import 'package:JWHelper/features/exam/data/exam_service.dart';
import 'package:JWHelper/features/grades/domain/grade.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';
import 'package:JWHelper/features/schedule/domain/schedule_editor.dart';
import 'package:JWHelper/core/errors/exceptions.dart';
import 'package:JWHelper/features/progress/domain/progress_item.dart';
import 'package:JWHelper/features/exam/domain/exam.dart';
import 'package:JWHelper/infrastructure/platform/widget_service.dart';
import 'package:JWHelper/app/usecases/grades_loader_usecase.dart';
import 'package:JWHelper/app/usecases/schedule_loader_usecase.dart';
import 'package:JWHelper/app/usecases/progress_loader_usecase.dart';
import 'package:JWHelper/app/usecases/exam_loader_usecase.dart';
import 'package:JWHelper/app/cache/offline_cache_keys.dart';
import 'package:JWHelper/app/coordinators/login_data_coordinator.dart';
import 'package:JWHelper/app/coordinators/exam_selection_coordinator.dart';
import 'package:JWHelper/app/domain/schedule_week_context.dart';
import 'package:JWHelper/app/domain/schedule_term_state.dart';
import 'package:JWHelper/app/domain/upcoming_exam_selector.dart';
import 'package:JWHelper/infrastructure/notifications/notification_service.dart';

part 'mixins/grades_data_mixin.dart';
part 'mixins/schedule_data_mixin.dart';
part 'mixins/schedule_edit_mixin.dart';
part 'mixins/progress_data_mixin.dart';
part 'mixins/exam_data_mixin.dart';
part 'mixins/widget_sync_mixin.dart';

class DataProvider with ChangeNotifier {
  final GradesService _gradesService = GradesService();
  final ScheduleService _scheduleService = ScheduleService();
  final ProgressService _progressService = ProgressService();
  final ExamService _examService = ExamService();

  List<Grade> _grades = [];
  bool _gradesLoading = false;
  bool _gradesLoaded = false;
  List<String>? _cachedSemesterList;

  List<ScheduleItem> _schedule = [];
  bool _scheduleLoading = false;
  bool _scheduleLoaded = false;
  int _currentWeek = 1;
  int _daysUntilStart = 0;
  String? _scheduleStartDay;
  bool _scheduleKeptStaleCache = false;
  bool _scheduleLocalMode = false;
  Map<int, List<ScheduleItem>>? _cachedScheduleGroupedByDay;

  List<ProgressGroup> _progressGroups = [];
  List<ProgressInfo> _progressInfo = [];
  bool _progressLoading = false;
  bool _progressLoaded = false;
  int _progressRevision = 0;
  final Map<String, Future<bool>> _inFlightGroupLoads = {};
  int _dataSessionToken = 0;

  void _setSchedule(List<ScheduleItem> next) {
    _schedule = next;
    _cachedScheduleGroupedByDay = null;
  }

  void _setGrades(List<Grade> next) {
    _grades = next;
    _cachedSemesterList = null;
  }

  List<Semester> _examSemesters = [];
  List<ExamRound> _examRounds = [];
  List<Exam> _exams = [];
  bool _examsLoading = false;
  bool _examsLoaded = false;
  String? _loadedExamSemId;
  String? _loadedExamRoundId;

  bool _evaluationRequired = false;
  bool get evaluationRequired => _evaluationRequired;
  void resetEvaluationState() {
    _evaluationRequired = false;
    notifyListeners();
  }

  String _username = '';
  String _campus = '济南';
  String get campus => _campus;

  /// Set username directly from SharedPreferences (no AuthProvider dependency).
  /// Used for fast cache loading before AuthProvider initializes.
  void setUsernameDirectly(String username) {
    if (_username != username) {
      _username = username;
    }
  }

  void notifyStateChanged() {
    notifyListeners();
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _campus = prefs.getString('campus_$_username') ?? prefs.getString('campus') ?? '济南';
    notifyListeners();
  }

  Future<void> setCampus(String campusName) async {
    if (_campus == campusName) return;
    _campus = campusName;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString('campus_$_username', campusName),
      prefs.setString('campus', campusName),
    ]);

    // 课表本身与校区无关，仅按新校区作息重排本地通知与刷新桌面小组件，避免触发全量网络重拉。
    if (_scheduleLoaded) {
      await rescheduleScheduleOutputs();
    }
  }

  void updateUsername(String username) {
    if (_username != username) {
      _username = username;
      // Clear memory data when switching users
      clearAll();
      loadPreferences();
    }
  }

  Future<void> prepareOnlineLoginData() async {
    await LoginDataCoordinator.prepareOnline(
      loadGrades: loadGrades,
      loadSchedule: loadSchedule,
      loadProgress: loadProgress,
      loadExamSemesters: loadDefaultExamsForWidget,
    );
  }

  void prepareOfflineLoginData() {
    LoginDataCoordinator.prepareOffline(
      loadGrades: loadGrades,
      loadSchedule: loadSchedule,
      loadProgress: loadProgress,
      loadExamSemesters: loadDefaultExamsForWidget,
    );
  }

  Future<void> clearCache() async {
    if (_username.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final removeKeys = <String>[
      _gradesCacheKey,
      _gradesCacheTimeKey,
      _scheduleCacheKey,
      _scheduleCacheTimeKey,
      OfflineCacheKeys.scheduleStartDay(_username),
      OfflineCacheKeys.scheduleLocalMode(_username),
      _progressCacheKey,
      _progressCacheTimeKey,
      for (final key in prefs.getKeys())
        if (OfflineCacheKeys.isExamCacheKey(key) &&
            OfflineCacheKeys.belongsToUser(key, _username))
          key,
    ];
    await Future.wait(removeKeys.map(prefs.remove));
  }

  void clearAll() {
    _dataSessionToken++;
    _inFlightGroupLoads.clear();
    _setGrades([]);
    _gradesLoaded = false;
    _setSchedule([]);
    _scheduleLoaded = false;
    _scheduleStartDay = null;
    _scheduleKeptStaleCache = false;
    _scheduleLocalMode = false;
    _currentWeek = 1;
    _daysUntilStart = 0;
    _progressGroups = [];
    _progressInfo = [];
    _progressLoaded = false;
    _progressRevision = 0;
    _examSemesters = [];
    _examRounds = [];
    _exams = [];
    _examsLoaded = false;
    _loadedExamSemId = null;
    _loadedExamRoundId = null;
    notifyListeners();
  }
}
