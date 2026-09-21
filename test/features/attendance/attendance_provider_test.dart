import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/features/attendance/data/sso_token_service.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_provider.dart';

const _captchaPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8AAAwAB/AL+2wAAAABJRU5ErkJggg==';

class _FakeSsoTokenService extends SsoTokenService {
  _FakeSsoTokenService({this.requireCaptcha = false});

  /// 登录失败时是否声称需要图形验证码。
  bool requireCaptcha;

  /// 提交的验证码是否正确（决定 verifyCaptcha 的结果）。
  bool acceptCaptcha = false;

  int loginCalls = 0;
  int fetchCaptchaCalls = 0;
  int verifyCaptchaCalls = 0;
  String? lastSubmittedCode;
  String _error = '';

  @override
  String get lastError => _error;

  @override
  bool get captchaRequired => requireCaptcha;

  @override
  Future<SsoCaptchaChallenge?> fetchCaptcha() async {
    fetchCaptchaCalls++;
    return SsoCaptchaChallenge(
      captchaId: 'captcha-$fetchCaptchaCalls',
      imageBytes: Uint8List.fromList(base64Decode(_captchaPngBase64)),
    );
  }

  @override
  Future<String?> verifyCaptcha({
    required String captchaId,
    required String code,
  }) async {
    verifyCaptchaCalls++;
    lastSubmittedCode = code;
    if (acceptCaptcha) {
      return null;
    }
    return '图形验证码验证失败';
  }

  @override
  Future<SsoSession?> loginAndFetchToken({
    required String username,
    required String password,
  }) async {
    loginCalls++;
    // 需要验证码时，除非已经通过验证，否则一直失败。
    if (requireCaptcha && !acceptCaptcha) {
      _error = '密码错误,请重新输入';
      return null;
    }
    if (password != 'correct-password' && !requireCaptcha) {
      _error = '智慧山体学号或密码错误，请在设置中核对后重试';
      return null;
    }
    requireCaptcha = false;
    return SsoSession(
      userToken: 'fake-user-token-$loginCalls',
      ctTicket: 'fake-ct-ticket',
      appCtTicket: 'fake-app-ct-ticket',
    );
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('保存账号后立即校验并缓存令牌', () async {
    final sso = _FakeSsoTokenService();
    final provider = AttendanceProvider(ssoTokenService: sso);

    expect(provider.isConfigured, isFalse);

    final error = await provider.saveCredentials(
      username: '20230000000',
      password: 'correct-password',
    );

    expect(error, isNull);
    expect(provider.isConfigured, isTrue);
    expect(provider.savedUsername, '20230000000');
    expect(provider.userToken, isNotEmpty);
    expect(provider.ctTicket, 'fake-ct-ticket');
    expect(sso.loginCalls, 1);
  });

  test('密码错误时回传统一认证的错误文案且不进入已配置状态', () async {
    final provider = AttendanceProvider(ssoTokenService: _FakeSsoTokenService());

    final error = await provider.saveCredentials(
      username: '20230000000',
      password: 'wrong-password',
    );

    expect(error, contains('智慧山体学号或密码错误'));
    // 账号被记下来便于用户改密码，但因为没校验通过，不会切进网页版。
    expect(provider.savedUsername, '20230000000');
    expect(provider.isConfigured, isFalse);
    expect(provider.userToken, isEmpty);
  });

  test('清除账号会同时清空令牌', () async {
    final provider = AttendanceProvider(ssoTokenService: _FakeSsoTokenService());
    await provider.saveCredentials(
      username: '20230000000',
      password: 'correct-password',
    );
    expect(provider.userToken, isNotEmpty);

    await provider.clearCredentials();

    expect(provider.isConfigured, isFalse);
    expect(provider.savedUsername, isEmpty);
    expect(provider.userToken, isEmpty);
    expect(provider.ctTicket, isEmpty);
  });

  test('已有缓存令牌时不会重复登录', () async {
    final sso = _FakeSsoTokenService();
    final provider = AttendanceProvider(ssoTokenService: sso);
    await provider.saveCredentials(
      username: '20230000000',
      password: 'correct-password',
    );
    expect(sso.loginCalls, 1);

    // 模拟再次进入考勤页（同一实例）：应当直接复用缓存令牌。
    expect(await provider.ensureAuthorized(), isNull);
    expect(await provider.ensureAuthorizedWithRecovery(), isNull);
    expect(sso.loginCalls, 1);
  });

  test('冷启动时用已保存密码换取令牌', () async {
    SharedPreferences.setMockInitialValues({
      'attendance_sso_username': '20230000000',
    });
    FlutterSecureStorage.setMockInitialValues({
      'attendance_sso_password': 'correct-password',
    });

    final sso = _FakeSsoTokenService();
    final provider = AttendanceProvider(ssoTokenService: sso);

    final error = await provider.ensureAuthorized();

    expect(error, isNull);
    expect(sso.loginCalls, 1);
    expect(provider.isConfigured, isTrue);
    expect(provider.userToken, isNotEmpty);
  });

  test('未配置账号时提示先配置', () async {
    final provider = AttendanceProvider(ssoTokenService: _FakeSsoTokenService());

    expect(await provider.ensureAuthorized(), '尚未配置智慧考勤账号');
  });

  test('刷新令牌时丢弃旧令牌且失败会回报原因', () async {
    final sso = _FakeSsoTokenService();
    final provider = AttendanceProvider(ssoTokenService: sso);
    await provider.saveCredentials(
      username: '20230000000',
      password: 'correct-password',
    );
    final firstToken = provider.userToken;

    // 把密码改错，模拟令牌失效后重新登录失败。
    await provider.saveCredentials(
      username: '20230000000',
      password: 'wrong-password',
    );

    expect(provider.userToken, isEmpty);
    expect(provider.lastError, contains('智慧山体学号或密码错误'));

    // 改回正确密码后可以恢复。
    await provider.saveCredentials(
      username: '20230000000',
      password: 'correct-password',
    );
    expect(provider.userToken, isNotEmpty);
    expect(provider.userToken, isNot(firstToken));
  });

  group('冷启动', () {
    test('已有凭据时直接进入已配置状态，无需重新填写', () async {
      SharedPreferences.setMockInitialValues({
        'attendance_sso_username': '20230000000',
      });
      FlutterSecureStorage.setMockInitialValues({
        'attendance_sso_password': 'correct-password',
      });

      final provider = AttendanceProvider(ssoTokenService: _FakeSsoTokenService());
      // 构造即开始读取本地凭据，等待它完成。
      await provider.ensureLoaded();

      expect(provider.isLoaded, isTrue);
      expect(provider.isConfigured, isTrue);
      expect(provider.savedUsername, '20230000000');
    });

    test('未保存过凭据时才要求配置', () async {
      final provider = AttendanceProvider(ssoTokenService: _FakeSsoTokenService());
      await provider.ensureLoaded();

      expect(provider.isLoaded, isTrue);
      expect(provider.isConfigured, isFalse);
    });
  });

  group('图形验证码', () {
    test('服务端要求验证码时取图并等待输入', () async {
      final sso = _FakeSsoTokenService(requireCaptcha: true);
      final provider = AttendanceProvider(ssoTokenService: sso);

      final error = await provider.saveCredentials(
        username: '20230000000',
        password: 'correct-password',
      );

      expect(error, contains('验证码'));
      expect(provider.needsCaptcha, isTrue);
      expect(provider.captchaImage, isNotEmpty);
      expect(sso.fetchCaptchaCalls, 1);
      // 验证码没过之前不算配置完成，页面停在表单。
      expect(provider.isConfigured, isFalse);
    });

    test('验证码输错时换一张并回传服务端原因', () async {
      final sso = _FakeSsoTokenService(requireCaptcha: true);
      final provider = AttendanceProvider(ssoTokenService: sso);
      await provider.saveCredentials(
        username: '20230000000',
        password: 'correct-password',
      );
      final firstImageCall = sso.fetchCaptchaCalls;

      final error = await provider.submitCaptcha('0000');

      expect(error, '图形验证码验证失败');
      expect(sso.lastSubmittedCode, '0000');
      // 与网页端一致：失败自动换图。
      expect(sso.fetchCaptchaCalls, firstImageCall + 1);
      expect(provider.needsCaptcha, isTrue);
      expect(provider.isConfigured, isFalse);
    });

    test('验证码正确后完成登录并清掉验证码状态', () async {
      final sso = _FakeSsoTokenService(requireCaptcha: true);
      final provider = AttendanceProvider(ssoTokenService: sso);
      await provider.saveCredentials(
        username: '20230000000',
        password: 'correct-password',
      );
      expect(provider.needsCaptcha, isTrue);

      sso.acceptCaptcha = true;
      final error = await provider.submitCaptcha('1a2b');

      expect(error, isNull);
      expect(provider.needsCaptcha, isFalse);
      expect(provider.captchaImage, isNull);
      expect(provider.isConfigured, isTrue);
      expect(provider.userToken, isNotEmpty);
    });

    test('没有验证码挑战时提交会提示失效', () async {
      final provider = AttendanceProvider(ssoTokenService: _FakeSsoTokenService());

      expect(await provider.submitCaptcha('1a2b'), '验证码已失效，请重新获取');
    });

    test('清除账号会一并清掉验证码状态', () async {
      final sso = _FakeSsoTokenService(requireCaptcha: true);
      final provider = AttendanceProvider(ssoTokenService: sso);
      await provider.saveCredentials(
        username: '20230000000',
        password: 'correct-password',
      );
      expect(provider.needsCaptcha, isTrue);

      await provider.clearCredentials();

      expect(provider.needsCaptcha, isFalse);
      expect(provider.isConfigured, isFalse);
    });
  });
}
