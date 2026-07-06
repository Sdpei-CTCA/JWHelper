import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'test_env.dart';

void main() {
  group('TestEnv', () {
    setUp(() {
      TestEnv.reset();
    });

    test('loads values from env file', () async {
      final tempDir = await Directory.systemTemp.createTemp('jwhelper_env_test');
      final envFile = File('${tempDir.path}/env');
      await envFile.writeAsString('''
# comment
TEST_USERNAME=student001
TEST_PASSWORD=secret123
''');

      await TestEnv.load(path: envFile.path);

      expect(TestEnv.username, 'student001');
      expect(TestEnv.password, 'secret123');
      expect(TestEnv.isConfigured, isTrue);

      await tempDir.delete(recursive: true);
    });

    test('isConfigured is false for placeholder values', () async {
      final tempDir = await Directory.systemTemp.createTemp('jwhelper_env_test');
      final envFile = File('${tempDir.path}/env');
      await envFile.writeAsString('''
TEST_USERNAME=your_student_id
TEST_PASSWORD=your_password
''');

      await TestEnv.load(path: envFile.path);

      expect(TestEnv.isConfigured, isFalse);

      await tempDir.delete(recursive: true);
    });
  });
}
