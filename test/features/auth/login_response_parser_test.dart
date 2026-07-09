import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/features/auth/data/auth_service.dart';

void main() {
  group('AuthService.parseLoginResponse', () {
    test('true means success', () {
      final result = AuthService.parseLoginResponse('true');
      expect(result['success'], isTrue);
    });

    test('first wrong password does not require captcha', () {
      final result =
          AuthService.parseLoginResponse('BS_LOGIN_STATE_InputError,showVC');
      expect(result['success'], isFalse);
      expect(result['needCaptcha'], isNull);
      expect(result['message'], '密码错误');
    });

    test('wrong verify code requires captcha', () {
      final result = AuthService.parseLoginResponse('wrongVerifyCode');
      expect(result['success'], isFalse);
      expect(result['needCaptcha'], isTrue);
    });

    test('expired verify code requires captcha', () {
      final result = AuthService.parseLoginResponse('verifyCodeTimeOut');
      expect(result['success'], isFalse);
      expect(result['needCaptcha'], isTrue);
    });
  });
}
