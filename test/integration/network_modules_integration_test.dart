import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/infrastructure/network/client.dart';
import 'package:JWHelper/features/auth/data/auth_service.dart';
import 'package:JWHelper/features/grades/data/grades_service.dart';
import 'package:JWHelper/features/schedule/data/schedule_service.dart';
import 'package:JWHelper/features/progress/data/progress_service.dart';
import 'package:JWHelper/features/exam/data/exam_service.dart';

import '../helpers/test_env.dart';

void main() {
  setUpAll(() async {
    await TestEnv.load();
  });

  group('Auth integration', () {
    test('login with env credentials', () async {
      if (!TestEnv.isConfigured) {
        // ignore: avoid_print
        print('Skip: configure env with TEST_USERNAME and TEST_PASSWORD');
        return;
      }

      await ApiClient().init();
      final authService = AuthService();
      final result = await authService.login(
        TestEnv.username,
        TestEnv.password,
      );

      expect(
        result['success'],
        isTrue,
        reason: result['message']?.toString(),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('Data modules integration', () {
    Future<void> loginIfNeeded() async {
      if (!TestEnv.isConfigured) return;

      await ApiClient().init();
      final authService = AuthService();
      final result = await authService.login(
        TestEnv.username,
        TestEnv.password,
      );
      if (result['success'] != true) {
        fail('Login failed: ${result['message']}');
      }
    }

    test('grades module fetches data', () async {
      if (!TestEnv.isConfigured) return;
      await loginIfNeeded();

      final grades = await GradesService().getAllGrades();
      expect(grades, isA<List>());
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('schedule module fetches data', () async {
      if (!TestEnv.isConfigured) return;
      await loginIfNeeded();

      final result = await ScheduleService().getSchedule();
      expect(result['items'], isA<List>());
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('progress module fetches data', () async {
      if (!TestEnv.isConfigured) return;
      await loginIfNeeded();

      final result = await ProgressService().getProgressData();
      expect(result['groups'], isA<List>());
      expect(result['info'], isA<List>());
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('exam module fetches semesters', () async {
      if (!TestEnv.isConfigured) return;
      await loginIfNeeded();

      final semesters = await ExamService().getSemesters();
      expect(semesters, isA<List>());
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
