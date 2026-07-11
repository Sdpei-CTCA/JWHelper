import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/app/usecases/grades_loader_usecase.dart';
import 'package:JWHelper/core/errors/exceptions.dart';
import 'package:JWHelper/features/grades/data/grades_service.dart';
import 'package:JWHelper/features/grades/domain/grade.dart';

class FakeGradesService extends GradesService {
  FakeGradesService(this._grades, {this.throwEvaluation = false});

  final List<Grade> _grades;
  final bool throwEvaluation;
  int callCount = 0;

  @override
  Future<List<Grade>> getAllGrades() async {
    callCount++;
    if (throwEvaluation) {
      throw DioException(
        requestOptions: RequestOptions(path: '/grades'),
        error: EvaluationRequiredException(),
      );
    }
    return _grades;
  }
}

void main() {
  const username = 'test_user';

  final cachedGrade = Grade(
    semester: '2024-2025-1',
    courseName: 'Cached Course',
    credit: '2',
    score: '80',
    gpa: '3.0',
  );

  final networkGrade = Grade(
    semester: '2024-2025-2',
    courseName: 'Network Course',
    credit: '3',
    score: '90',
    gpa: '4.0',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> seedCache(Grade grade) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'grades_cache_$username',
      jsonEncode([grade.toJson()]),
    );
    await prefs.setInt(
      'grades_cache_time_$username',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  test('forceRefresh=true skips disk cache and fetches from network', () async {
    await seedCache(cachedGrade);
    final service = FakeGradesService([networkGrade]);

    final result = await GradesLoaderUsecase.execute(
      service: service,
      username: username,
      forceRefresh: true,
    );

    expect(service.callCount, 1);
    expect(result.grades, hasLength(1));
    expect(result.grades.first.courseName, 'Network Course');
  });

  test('forceRefresh=true with empty network does not fallback to disk cache',
      () async {
    await seedCache(cachedGrade);
    final service = FakeGradesService([]);

    final result = await GradesLoaderUsecase.execute(
      service: service,
      username: username,
      forceRefresh: true,
    );

    expect(service.callCount, 1);
    expect(result.grades, isEmpty);
  });

  test('forceRefresh=false reads disk cache within 30 days', () async {
    await seedCache(cachedGrade);
    final service = FakeGradesService([networkGrade]);

    final result = await GradesLoaderUsecase.execute(
      service: service,
      username: username,
      forceRefresh: false,
    );

    expect(service.callCount, 0);
    expect(result.grades, hasLength(1));
    expect(result.grades.first.courseName, 'Cached Course');
  });

  test('evaluation required with disk cache still flags evaluationRequired',
      () async {
    await seedCache(cachedGrade);
    final service = FakeGradesService([], throwEvaluation: true);

    final result = await GradesLoaderUsecase.execute(
      service: service,
      username: username,
      forceRefresh: true,
    );

    expect(service.callCount, 1);
    expect(result.evaluationRequired, isTrue);
    expect(result.grades.first.courseName, 'Cached Course');
    expect(result.loaded, isTrue);
  });
}
