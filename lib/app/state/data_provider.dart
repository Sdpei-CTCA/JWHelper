library data_provider;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/features/grades/data/grades_service.dart';
import 'package:JWHelper/features/schedule/data/schedule_service.dart';
import 'package:JWHelper/features/progress/data/progress_service.dart';
import 'package:JWHelper/features/exam/data/exam_service.dart';
import 'package:JWHelper/features/grades/domain/grade.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';
import 'package:JWHelper/features/progress/domain/progress_item.dart';
import 'package:JWHelper/features/exam/domain/exam.dart';
import 'package:JWHelper/infrastructure/platform/widget_service.dart';
import 'package:JWHelper/app/usecases/grades_loader_usecase.dart';
import 'package:JWHelper/app/usecases/schedule_loader_usecase.dart';
import 'package:JWHelper/app/usecases/progress_loader_usecase.dart';
import 'package:JWHelper/app/usecases/exam_loader_usecase.dart';
import 'package:JWHelper/app/coordinators/login_data_coordinator.dart';

part 'mixins/grades_data_mixin.dart';
part 'mixins/schedule_data_mixin.dart';
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

  List<ScheduleItem> _schedule = [];
  bool _scheduleLoading = false;
  bool _scheduleLoaded = false;
  int _currentWeek = 1;
  int _daysUntilStart = 0;

  List<ProgressGroup> _progressGroups = [];
  List<ProgressInfo> _progressInfo = [];
  bool _progressLoading = false;
  bool _progressLoaded = false;

  List<Semester> _examSemesters = [];
  List<ExamRound> _examRounds = [];
  List<Exam> _exams = [];
  bool _examsLoading = false;
  bool _examsLoaded = false;

  bool _evaluationRequired = false;
  bool get evaluationRequired => _evaluationRequired;
  void resetEvaluationState() {
    _evaluationRequired = false;
    notifyListeners();
  }

  String _username = '';

  void notifyStateChanged() {
    notifyListeners();
  }

  void updateUsername(String username) {
    if (_username != username) {
      _username = username;
      // Clear memory data when switching users
      clearAll();
    }
  }

  Future<void> prepareOnlineLoginData() async {
    await LoginDataCoordinator.prepareOnline(
      clearCache: clearCache,
      loadGrades: loadGrades,
      loadSchedule: loadSchedule,
      loadProgress: loadProgress,
      loadExamSemesters: loadExamSemesters,
    );
  }

  void prepareOfflineLoginData() {
    LoginDataCoordinator.prepareOffline(
      loadGrades: loadGrades,
      loadSchedule: loadSchedule,
      loadProgress: loadProgress,
      loadExamSemesters: loadExamSemesters,
    );
  }
  
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_gradesCacheKey);
    await prefs.remove(_gradesCacheTimeKey);
    await prefs.remove(_scheduleCacheKey);
    await prefs.remove(_scheduleCacheTimeKey);
    await prefs.remove(_progressCacheKey);
    await prefs.remove(_progressCacheTimeKey);
    
    // Clear exam caches - this is harder because keys are dynamic
    // We can iterate all keys and remove those starting with exam_
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('exam_') || key.startsWith('exams_')) {
        if (key.contains(_username)) {
          await prefs.remove(key);
        }
      }
    }
  }
  
  void clearAll() {
    _grades = [];
    _gradesLoaded = false;
    _schedule = [];
    _scheduleLoaded = false;
    _progressGroups = [];
    _progressInfo = [];
    _progressLoaded = false;
    _examSemesters = [];
    _examRounds = [];
    _exams = [];
    _examsLoaded = false;
    notifyListeners();
  }
}
