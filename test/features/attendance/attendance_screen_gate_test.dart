import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:JWHelper/features/attendance/data/sso_token_service.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_provider.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_screen.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_web_actions.dart';
import 'package:JWHelper/features/attendance/presentation/campus_webview_screen.dart';

const _captchaPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8AAAwAB/AL+2wAAAABJRU5ErkJggg==';

class _FakeSsoTokenService extends SsoTokenService {
  _FakeSsoTokenService({this.requireCaptcha = false});

  /// 登录失败时是否声称需要图形验证码。
  bool requireCaptcha;

  /// 提交的验证码是否正确。
  bool acceptCaptcha = false;

  int fetchCaptchaCalls = 0;
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
    if (requireCaptcha && !acceptCaptcha) {
      _error = '密码错误,请重新输入';
      return null;
    }
    if (password != 'correct-password' && !requireCaptcha) {
      _error = '智慧山体学号或密码错误，请在设置中核对后重试';
      return null;
    }
    requireCaptcha = false;
    return const SsoSession(userToken: 'fake-user-token');
  }
}

void main() {
  setUp(() {
    // 网页版容器需要 WebView 平台实现；这里注册 Android 平台以便在测试里实例化。
    AndroidWebViewPlatform.registerWith();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<AttendanceWebActions> pumpAttendanceScreen(
    WidgetTester tester, {
    SsoTokenService? sso,
    bool settle = true,
  }) async {
    final actions = AttendanceWebActions();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) =>
                AttendanceProvider(ssoTokenService: sso ?? _FakeSsoTokenService()),
          ),
          ChangeNotifierProvider<AttendanceWebActions>.value(value: actions),
        ],
        child: const MaterialApp(home: Scaffold(body: AttendanceScreen())),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // 已配置时会挂载 WebView，其加载指示器永远不会停，不能用 pumpAndSettle。
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }
    return actions;
  }

  Future<void> submitCredentials(
    WidgetTester tester, {
    required String password,
  }) async {
    await tester.enterText(
      find.widgetWithText(TextField, '智慧山体学号'),
      '20230000000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '智慧山体密码'),
      password,
    );
    await tester.tap(find.text('保存并登录'));
    // WebView 需要平台视图，测试环境下会停在「准备中」，这里只等状态切换。
    await tester.pump();
    await tester.pump();
  }

  testWidgets('未配置账号时展示首用引导与账号表单', (tester) async {
    await pumpAttendanceScreen(tester);

    expect(find.text('首次使用请配置智慧考勤账号'), findsOneWidget);
    expect(find.widgetWithText(TextField, '智慧山体学号'), findsOneWidget);
    expect(find.widgetWithText(TextField, '智慧山体密码'), findsOneWidget);
    expect(find.text('保存并登录'), findsOneWidget);

    expect(find.byType(CampusWebViewScreen), findsNothing);
  });

  testWidgets('学号为空时本地校验拦截', (tester) async {
    await pumpAttendanceScreen(tester);

    await tester.tap(find.text('保存并登录'));
    await tester.pump();

    expect(find.text('请输入智慧山体学号'), findsOneWidget);
  });

  testWidgets('密码为空时本地校验拦截', (tester) async {
    await pumpAttendanceScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextField, '智慧山体学号'),
      '20230000000',
    );
    await tester.tap(find.text('保存并登录'));
    await tester.pump();

    expect(find.text('请输入智慧山体密码'), findsOneWidget);
  });

  testWidgets('密码可以切换明文显示', (tester) async {
    await pumpAttendanceScreen(tester);

    final passwordField = find.widgetWithText(TextField, '智慧山体密码');
    expect(tester.widget<TextField>(passwordField).obscureText, isTrue);

    await tester.tap(find.byTooltip('显示密码'));
    await tester.pump();

    expect(tester.widget<TextField>(passwordField).obscureText, isFalse);
  });

  testWidgets('校验失败时表单保留，账号被记录但未获得令牌', (tester) async {
    await pumpAttendanceScreen(tester);

    await submitCredentials(tester, password: 'wrong-password');

    // 校验没过就不该切到网页版，用户应停在表单上继续改密码。
    expect(find.text('首次使用请配置智慧考勤账号'), findsOneWidget);
    expect(find.byType(CampusWebViewScreen), findsNothing);

    final provider = Provider.of<AttendanceProvider>(
      tester.element(find.byType(AttendanceScreen)),
      listen: false,
    );
    expect(provider.savedUsername, '20230000000');
    expect(provider.isConfigured, isFalse);
    expect(provider.userToken, isEmpty);
  });

  testWidgets('校验通过后渲染网页版并开放标题栏动作', (tester) async {
    final actions = await pumpAttendanceScreen(tester);
    expect(actions.isReady, isFalse);

    await submitCredentials(tester, password: 'correct-password');

    expect(find.text('首次使用请配置智慧考勤账号'), findsNothing);
    expect(find.byType(CampusWebViewScreen), findsOneWidget);

    // 网页版挂载后把动作注册给标题栏（首页 AppBar 的按钮依赖这个）。
    expect(actions.isReady, isTrue);
    // 触发动作不应抛异常。
    actions.reload();
    await tester.pump();
  });

  testWidgets('账号被清除后收回标题栏动作', (tester) async {
    final actions = await pumpAttendanceScreen(tester);
    await submitCredentials(tester, password: 'correct-password');
    expect(actions.isReady, isTrue);

    final provider = Provider.of<AttendanceProvider>(
      tester.element(find.byType(AttendanceScreen)),
      listen: false,
    );
    await provider.clearCredentials();
    await tester.pump();
    await tester.pump();

    expect(find.byType(CampusWebViewScreen), findsNothing);
    // 注销延后到帧末执行，避免在 build/dispose 阶段触发重建。
    expect(actions.isReady, isFalse);
  });

  testWidgets('冷启动已有凭据时直接进入网页版，不再要求重新填写', (tester) async {
    // 模拟上次已保存好账号密码、且校验通过、App 重启后的磁盘状态。
    SharedPreferences.setMockInitialValues({
      'attendance_sso_username': '20230000000',
      'attendance_sso_verified': true,
    });
    FlutterSecureStorage.setMockInitialValues({
      'attendance_sso_password': 'correct-password',
    });

    await pumpAttendanceScreen(tester, settle: false);

    expect(find.text('首次使用请配置智慧考勤账号'), findsNothing);
    expect(find.widgetWithText(TextField, '智慧山体学号'), findsNothing);
    expect(find.byType(CampusWebViewScreen), findsOneWidget);

    final provider = Provider.of<AttendanceProvider>(
      tester.element(find.byType(AttendanceScreen)),
      listen: false,
    );
    expect(provider.isLoaded, isTrue);
    expect(provider.isConfigured, isTrue);
  });

  testWidgets('校验失败的凭据在重启后仍要求重新校验', (tester) async {
    // 密码存着但从未校验通过（例如上次输错后直接退出了 App）。
    SharedPreferences.setMockInitialValues({
      'attendance_sso_username': '20230000000',
    });
    FlutterSecureStorage.setMockInitialValues({
      'attendance_sso_password': 'wrong-password',
    });

    await pumpAttendanceScreen(tester);

    // 不能带着未验证的凭据进网页版，应停在绑定表单。
    expect(find.byType(CampusWebViewScreen), findsNothing);
    expect(find.text('首次使用请配置智慧考勤账号'), findsOneWidget);

    final provider = Provider.of<AttendanceProvider>(
      tester.element(find.byType(AttendanceScreen)),
      listen: false,
    );
    expect(provider.isConfigured, isFalse);
    expect(provider.hasUnverifiedCredentials, isTrue);
  });

  testWidgets('服务端要求验证码时表单出现验证码输入与图片', (tester) async {
    final sso = _FakeSsoTokenService(requireCaptcha: true);
    await pumpAttendanceScreen(tester, sso: sso);

    await tester.enterText(
      find.widgetWithText(TextField, '智慧山体学号'),
      '20230000000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '智慧山体密码'),
      'correct-password',
    );
    await tester.tap(find.text('保存并登录'));
    await tester.pumpAndSettle();

    // 多出验证码输入框与图片，提交按钮切换为「提交验证码」。
    expect(find.widgetWithText(TextField, '图形验证码'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('提交验证码'), findsOneWidget);
    expect(find.textContaining('请输入图形验证码'), findsOneWidget);
    expect(sso.fetchCaptchaCalls, 1);

    // 点图片换一张。点击目标用 Tooltip 而不是 Image：测试环境里图片字节是异步解码的，
    // 未解码完成时 RenderImage 尺寸为 0，tap 会打空并打印 hit-test 警告——真正接收
    // 点击的是外层承担 onTap 的 InkWell，用 Tooltip 定位才能准确命中可点区域。
    await tester.tap(find.byTooltip('点击换一张'));
    await tester.pumpAndSettle();
    expect(sso.fetchCaptchaCalls, 2);
    expect(find.widgetWithText(TextField, '图形验证码'), findsOneWidget);
  });

  testWidgets('验证码位数不足时本地拦截', (tester) async {
    final sso = _FakeSsoTokenService(requireCaptcha: true);
    await pumpAttendanceScreen(tester, sso: sso);

    await tester.enterText(
      find.widgetWithText(TextField, '智慧山体学号'),
      '20230000000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '智慧山体密码'),
      'correct-password',
    );
    await tester.tap(find.text('保存并登录'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '图形验证码'), '12');
    await tester.tap(find.text('提交验证码'));
    await tester.pumpAndSettle();

    expect(find.text('请输入 4 位图形验证码'), findsOneWidget);
    // 没有发起校验请求。
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('验证码通过后完成绑定并进入网页版', (tester) async {
    final sso = _FakeSsoTokenService(requireCaptcha: true);
    await pumpAttendanceScreen(tester, sso: sso);

    await tester.enterText(
      find.widgetWithText(TextField, '智慧山体学号'),
      '20230000000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '智慧山体密码'),
      'correct-password',
    );
    await tester.tap(find.text('保存并登录'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '图形验证码'), findsOneWidget);

    sso.acceptCaptcha = true;
    await tester.enterText(find.widgetWithText(TextField, '图形验证码'), '1a2b');
    await tester.tap(find.text('提交验证码'));
    // 通过后会挂载 WebView，其加载指示器不会停，用定量 pump。
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(CampusWebViewScreen), findsOneWidget);
    expect(find.text('首次使用请配置智慧考勤账号'), findsNothing);
  });
}
