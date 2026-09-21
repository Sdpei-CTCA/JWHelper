import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/infrastructure/network/client.dart';
import 'package:JWHelper/features/auth/data/auth_service.dart';
import 'package:JWHelper/features/grades/data/grades_service.dart';
import 'package:JWHelper/features/schedule/data/schedule_service.dart';
import 'package:JWHelper/features/progress/data/progress_service.dart';
import 'package:JWHelper/features/exam/data/exam_service.dart';
import 'package:JWHelper/app/domain/schedule_term_state.dart';

import '../helpers/test_env.dart';

void main() {
  // 没有它时 ApiClient.init 会打印「Cookie persistence initialization failed:
  // Binding has not yet been initialized」并退化；更要紧的是 client.dart 的
  // _notifySessionExpired 依赖 SchedulerBinding.instance，登录过期回调在这里
  // 同样跑不到。
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // path_provider 在测试环境没有实现，若不接管，ApiClient.init 会退化成内存 Cookie，
    // 生产实际使用的 PersistCookieJar 路径就永远得不到验证。这里让它返回一个临时目录。
    final Directory cookieDir =
        await Directory.systemTemp.createTemp('jwhelper_it_cookies');
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return cookieDir.path;
      }
      return null;
    });

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
      final items = result['items'] as List;
      final startDay = result['startDay'] as String?;
      if (ScheduleTermState.isTermUnavailable(
        schedule: items,
        startDay: startDay,
      )) {
        // ignore: avoid_print
        print('提醒: ${ScheduleTermState.unavailableMessage}');
      }
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
