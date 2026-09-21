import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_account_form.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_provider.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_web_actions.dart';

/// 智慧考勤网页版（底部导航「考勤」tab 主体）。
///
/// 打开时会先把当前账号的 SSO 令牌写入 Cookie 与 Web Storage，尽量免登录进入；
/// 未配置账号或令牌失效时，页面自身的登录入口仍然可用，不会阻塞访问。
/// 操作按钮位于首页标题栏，通过 [AttendanceWebActions] 调用这里的动作。
///
/// **注意**：本页**不能**触发软件键盘 —— 外层 `HomeScreen` 没有
/// `resizeToAvoidBottomInset`，键盘弹出会盖住输入框且无法上滚。仓库内的
/// `ssoLogin` 页面内部是弹窗式输入，弹窗自己会跟随键盘，所以同样安全。若以后
/// 要在考勤页里直接放普通输入框，必须先给外层补上键盘避让
/// （例如改用 `Padding` + `MediaQuery.viewInsets`）。
class CampusWebViewScreen extends StatefulWidget {
  /// 智慧考勤网页版地址。
  static const String attendanceWebUrl = 'https://qdxt.sdpei.edu.cn:7083/pages/sdpei/sso';

  const CampusWebViewScreen({super.key});

  @override
  State<CampusWebViewScreen> createState() => _CampusWebViewScreenState();
}

class _CampusWebViewScreenState extends State<CampusWebViewScreen> {
  final WebViewCookieManager _cookieManager = WebViewCookieManager();
  late final WebViewController _controller;
  String _activeToken = '';
  bool _isLoading = true;
  bool _isPreparing = true;
  bool _registeredActions = false;
  AttendanceWebActions? _actions;
  String? _prepareError;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) async {
            await _injectTokenToWebStorage();
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      );

    _configureAndroidWebViewPermissions();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _actions = context.read<AttendanceWebActions>();
      _actions!.register(
        reload: _prepareAndLoad,
        relogin: _refreshAuth,
        editAccount: _editAccount,
        openInBrowser: _openInBrowser,
      );
      _registeredActions = true;
      _prepareAndLoad();
    });
  }

  @override
  void dispose() {
    // 页面被销毁（例如账号被清除）后标题栏不应再留着按钮。
    // 注销会通知监听者，而 dispose 可能发生在 build/dispose 阶段，
    // 因此推迟到当前帧结束再执行。
    if (_registeredActions) {
      final actions = _actions;
      _registeredActions = false;
      _actions = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => actions?.unregister());
    }
    super.dispose();
  }

  /// Android 的 WebView 默认拒绝网页的摄像头与定位请求，这里改为按系统权限放行；
  /// iOS 这两项都交给系统弹窗处理，无需干预。
  ///
  /// 定位是签到/签退的必要条件：网页里的 `navigator.geolocation` 只有在宿主 App
  /// 拿到定位授权后才会返回坐标，所以这里申请系统权限后再决定是否放行。
  void _configureAndroidWebViewPermissions() {
    final platformController = _controller.platform;
    if (platformController is! AndroidWebViewController) {
      return;
    }

    platformController
      ..setGeolocationEnabled(true)
      ..setOnPlatformPermissionRequest((request) async {
        if (request.types.contains(WebViewPermissionResourceType.camera)) {
          final status = await Permission.camera.request();
          if (!status.isGranted) {
            request.deny();
            return;
          }
        }
        request.grant();
      })
      ..setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async {
          final status = await Permission.locationWhenInUse.request();
          if (!status.isGranted) {
            _notifyLocationDenied(
              permanentlyDenied: status.isPermanentlyDenied,
            );
          }
          return GeolocationPermissionsResponse(
            allow: status.isGranted,
            // 只在已授权时记住，否则用户去系统设置打开定位后回来还能再次询问。
            retain: status.isGranted,
          );
        },
      );
  }

  void _notifyLocationDenied({required bool permanentlyDenied}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('签到需要定位权限，请允许「教务小助手」使用定位后重试'),
        action: permanentlyDenied
            ? const SnackBarAction(label: '去设置', onPressed: openAppSettings)
            : null,
      ),
    );
  }

  Future<void> _prepareAndLoad() async {
    if (mounted) {
      setState(() {
        _isPreparing = true;
        _prepareError = null;
      });
    }

    try {
      final provider = context.read<AttendanceProvider>();
      // 已配置账号时先确保令牌可用（失败也继续，网页版自己还有登录入口）。
      if (provider.isConfigured) {
        await provider.ensureAuthorizedWithRecovery();
      }

      _activeToken = provider.userToken;
      final targetUri = _buildTargetUri(
        CampusWebViewScreen.attendanceWebUrl,
        _activeToken,
      );

      await _setAuthCookies(
        uri: targetUri,
        userToken: _activeToken,
        ctTicket: provider.ctTicket,
        appCtTicket: provider.appCtTicket,
      );

      final headers = <String, String>{
        if (_activeToken.isNotEmpty) 'Authorization': 'Bearer $_activeToken',
        if (_activeToken.isNotEmpty) 'X-User-Token': _activeToken,
      };

      await _controller.loadRequest(targetUri, headers: headers);
      if (mounted) {
        setState(() {
          _isPreparing = false;
        });
      }
    } catch (e) {
      // 鉴权准备失败不影响浏览网页版，只在页面上给一条提示。
      if (mounted) {
        setState(() {
          _isPreparing = false;
          _prepareError = '免登录准备失败: $e';
        });
      }
    }
  }

  /// 重新登录并重载页面（网页版里登录态失效时使用）。
  Future<void> _refreshAuth() async {
    final provider = context.read<AttendanceProvider>();
    if (!provider.isConfigured) {
      _showSnack('未配置智慧考勤账号，请在设置中填写学号与密码');
      return;
    }

    final error = await provider.refreshSession();
    if (!mounted) return;

    if (error != null) {
      _showSnack(error);
      return;
    }

    await _prepareAndLoad();
    if (!mounted) return;
    _showSnack('已重新登录');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _editAccount() async {
    final saved = await AttendanceAccountDialog.show(context);
    if (!saved || !mounted) return;
    await _prepareAndLoad();
  }

  Uri _buildTargetUri(String rawUrl, String userToken) {
    var uri = Uri.parse(rawUrl);
    if (userToken.isEmpty) {
      return uri;
    }

    if (uri.host == 'jxzlbz.sdpei.edu.cn') {
      return Uri.parse(
        'https://jxzlbz.sdpei.edu.cn/h5/#/pages/login/caslogin?userToken=${Uri.encodeComponent(userToken)}',
      );
    }

    if (uri.host.contains('sdpei.edu.cn')) {
      final query = Map<String, String>.from(uri.queryParameters);
      query.putIfAbsent('userToken', () => userToken);

      var fragment = uri.fragment;
      if (fragment.isNotEmpty && !fragment.contains('userToken=')) {
        fragment = '$fragment${fragment.contains('?') ? '&' : '?'}userToken=${Uri.encodeQueryComponent(userToken)}';
      }

      uri = uri.replace(queryParameters: query, fragment: fragment);
    }

    return uri;
  }

  Future<void> _setAuthCookies({
    required Uri uri,
    required String userToken,
    required String ctTicket,
    required String appCtTicket,
  }) async {
    final domains = <String>{uri.host};
    if (uri.host.endsWith('sdpei.edu.cn')) {
      domains.addAll(<String>[
        'jxzlbz.sdpei.edu.cn',
        'sso.sdpei.edu.cn',
        'static.sdpei.edu.cn',
        'pubfilestor.sdpei.edu.cn',
      ]);
    }

    for (final domain in domains) {
      if (userToken.isNotEmpty) {
        await _cookieManager.setCookie(
          WebViewCookie(name: 'userToken', value: userToken, domain: domain, path: '/'),
        );
      }
      if (ctTicket.isNotEmpty) {
        await _cookieManager.setCookie(
          WebViewCookie(name: 'CTTICKET', value: ctTicket, domain: domain, path: '/'),
        );
      }
      if (appCtTicket.isNotEmpty) {
        await _cookieManager.setCookie(
          WebViewCookie(name: 'APPCTTICKET', value: appCtTicket, domain: domain, path: '/'),
        );
      }
    }
  }

  Future<void> _injectTokenToWebStorage() async {
    if (_activeToken.isEmpty) {
      return;
    }
    final escaped = _activeToken
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'");
    try {
      await _controller.runJavaScript(
        "window.localStorage.setItem('userToken', '$escaped');"
        "window.sessionStorage.setItem('userToken', '$escaped');",
      );
    } catch (_) {
      // 非 H5 页面上执行脚本会失败，忽略即可。
    }
  }

  Future<void> _openInBrowser() async {
    final uri = _buildTargetUri(
      CampusWebViewScreen.attendanceWebUrl,
      _activeToken,
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开浏览器')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_prepareError != null) _buildPrepareBanner(_prepareError!),
        Expanded(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isPreparing || _isLoading)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ],
    );
  }

  /// 免登录准备失败时的提示条：只在网页版上方做提示，不遮挡网页。
  Widget _buildPrepareBanner(String message) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$message，可在网页内直接登录',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: _refreshAuth,
              child: const Text('重新登录'),
            ),
          ],
        ),
      ),
    );
  }
}
