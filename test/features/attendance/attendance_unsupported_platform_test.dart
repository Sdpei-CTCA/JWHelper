import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_provider.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_screen.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_web_actions.dart';
import 'package:JWHelper/features/attendance/presentation/campus_webview_screen.dart';

/// Windows / Linux 上 `webview_flutter` 没有实现，`WebViewPlatform.instance` 为空，
/// 直接构造 `WebViewController()` 会抛异常。考勤页在这类平台必须给出浏览器入口。
///
/// 这里**故意不注册任何平台实现**：每个测试文件跑在独立 isolate 里，
/// 未注册就等价于桌面端。注意平台实例只能设为非空值，因此无法在同一个文件里
/// 先注册再"取消注册"，这个用例只能单独成文件。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'attendance_sso_username': '20230000000',
      'attendance_sso_verified': true,
    });
    FlutterSecureStorage.setMockInitialValues({
      'attendance_sso_password': 'correct-password',
    });
  });

  testWidgets('没有 WebView 实现时显示浏览器入口而不是崩溃', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AttendanceProvider()),
          // 网页版挂载后会把操作注册给它（首页标题栏按钮用）。
          ChangeNotifierProvider(create: (_) => AttendanceWebActions()),
        ],
        child: const MaterialApp(home: Scaffold(body: AttendanceScreen())),
      ),
    );
    // 构造 WebView 会抛异常，因此这里不能等到"稳定"，用定量 pump 即可。
    await tester.pump();
    await tester.pump();

    expect(find.text('当前平台不支持应用内考勤网页'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '用浏览器打开'), findsOneWidget);
    // 确认没有退化成"绑定表单"（凭据是已配置状态）。
    expect(find.text('首次使用请配置智慧考勤账号'), findsNothing);
  });

  testWidgets('网页版组件在不支持的平台上直接渲染兜底视图', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AttendanceProvider()),
          // 网页版挂载后会把操作注册给它（首页标题栏按钮用）。
          ChangeNotifierProvider(create: (_) => AttendanceWebActions()),
        ],
        child: const MaterialApp(home: Scaffold(body: CampusWebViewScreen())),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('当前平台不支持应用内考勤网页'), findsOneWidget);
  });
}
