import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/core/constants/config.dart';

void main() {
  test('app config is available for startup', () {
    expect(Config.baseUrl, isNotEmpty);
    expect(Config.userAgent, isNotEmpty);
  });
}
