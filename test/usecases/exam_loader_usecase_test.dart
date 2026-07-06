import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/app/usecases/exam_loader_usecase.dart';
import 'package:JWHelper/features/exam/data/exam_service.dart';
import 'package:JWHelper/features/exam/domain/exam.dart';

class FakeExamService extends ExamService {
  FakeExamService({
    List<Semester>? semesters,
    List<ExamRound>? rounds,
    List<Exam>? exams,
  })  : _semesters = semesters ?? const [],
        _rounds = rounds ?? const [],
        _exams = exams ?? const [];

  final List<Semester> _semesters;
  final List<ExamRound> _rounds;
  final List<Exam> _exams;

  int semestersCallCount = 0;
  int roundsCallCount = 0;
  int examsCallCount = 0;

  @override
  Future<List<Semester>> getSemesters() async {
    semestersCallCount++;
    return _semesters;
  }

  @override
  Future<List<ExamRound>> getExamRounds(String semId) async {
    roundsCallCount++;
    return _rounds;
  }

  @override
  Future<List<Exam>> getExamList(String semId, String etId) async {
    examsCallCount++;
    return _exams;
  }
}

void main() {
  const username = 'test_user';
  const semId = 'sem1';
  const roundId = 'round1';

  final cachedSemester = Semester(id: '1', name: 'Cached Semester');
  final networkSemester = Semester(id: '2', name: 'Network Semester');

  final cachedRound = ExamRound(id: 'r1', name: 'Cached Round');
  final networkRound = ExamRound(id: 'r2', name: 'Network Round');

  final cachedExam = Exam(
    courseName: 'Cached Exam',
    courseNo: 'C001',
    time: '09:00',
    location: 'A101',
    classNo: '1',
    type: 'Final',
    applyStatus: 'Applied',
  );

  final networkExam = Exam(
    courseName: 'Network Exam',
    courseNo: 'C002',
    time: '14:00',
    location: 'B202',
    classNo: '2',
    type: 'Final',
    applyStatus: 'Applied',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('loadSemesters', () {
    test('forceRefresh=true skips disk cache', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        ExamLoaderUsecase.semestersKey(username),
        jsonEncode([cachedSemester.toJson()]),
      );

      final service = FakeExamService(semesters: [networkSemester]);
      final result = await ExamLoaderUsecase.loadSemesters(
        service: service,
        username: username,
        forceRefresh: true,
      );

      expect(service.semestersCallCount, 1);
      expect(result.semesters.first.name, 'Network Semester');
    });

    test('forceRefresh=false reads disk cache', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        ExamLoaderUsecase.semestersKey(username),
        jsonEncode([cachedSemester.toJson()]),
      );

      final service = FakeExamService(semesters: [networkSemester]);
      final result = await ExamLoaderUsecase.loadSemesters(
        service: service,
        username: username,
        forceRefresh: false,
      );

      expect(service.semestersCallCount, 0);
      expect(result.semesters.first.name, 'Cached Semester');
    });
  });

  group('loadRounds', () {
    test('forceRefresh=true skips disk cache', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        ExamLoaderUsecase.roundsKey(semId, username),
        jsonEncode([cachedRound.toJson()]),
      );

      final service = FakeExamService(rounds: [networkRound]);
      final result = await ExamLoaderUsecase.loadRounds(
        service: service,
        username: username,
        semId: semId,
        forceRefresh: true,
      );

      expect(service.roundsCallCount, 1);
      expect(result.rounds.first.name, 'Network Round');
    });
  });

  group('loadExams', () {
    test('forceRefresh=true skips disk cache', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        ExamLoaderUsecase.examsKey(semId, roundId, username),
        jsonEncode([cachedExam.toJson()]),
      );

      final service = FakeExamService(exams: [networkExam]);
      final result = await ExamLoaderUsecase.loadExams(
        service: service,
        username: username,
        semId: semId,
        roundId: roundId,
        forceRefresh: true,
      );

      expect(service.examsCallCount, 1);
      expect(result.exams.first.courseName, 'Network Exam');
    });
  });
}
