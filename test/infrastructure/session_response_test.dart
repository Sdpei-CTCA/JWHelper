import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/infrastructure/network/session_response.dart';

void main() {
  group('session_response', () {
    test('isLoginTimeoutBody detects logintimeout text', () {
      expect(isLoginTimeoutBody('logintimeout'), isTrue);
      expect(isLoginTimeoutBody('  logintimeout  '), isTrue);
      expect(isLoginTimeoutBody('LoginTimeout'), isTrue);
    });

    test('isLoginTimeoutBody rejects json and empty', () {
      expect(isLoginTimeoutBody('{"menu":[]}'), isFalse);
      expect(isLoginTimeoutBody(''), isFalse);
      expect(isLoginTimeoutBody(null), isFalse);
    });

    test('shouldCheckLoginTimeout skips login handler', () {
      expect(
        shouldCheckLoginTimeout(
          Uri.parse('https://jw.sdpei.edu.cn/LoginHandler.ashx'),
        ),
        isFalse,
      );
      expect(
        shouldCheckLoginTimeout(
          Uri.parse('https://jw.sdpei.edu.cn/Teacher/TimeTableHandler.ashx'),
        ),
        isTrue,
      );
    });
  });
}
