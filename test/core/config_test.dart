import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/core/constants/config.dart';

void main() {
  group('Config', () {
    test('baseUrl is configured', () {
      expect(Config.baseUrl, isNotEmpty);
      expect(Config.baseUrl, startsWith('https://'));
    });

    test('module URLs are derived from baseUrl', () {
      expect(Config.gradesUrl, contains(Config.baseUrl));
      expect(Config.progressUrl, contains(Config.baseUrl));
      expect(Config.loginUrl, contains(Config.baseUrl));
    });
  });
}
