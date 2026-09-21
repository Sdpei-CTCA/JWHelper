import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:JWHelper/features/attendance/data/attendance_credential_store.dart';
import 'package:JWHelper/features/attendance/data/sso_token_service.dart';
/// 智慧考勤的账号与统一认证令牌状态。
///
/// 账号是「智慧山体」统一认证账号，与教务系统登录解耦：教务会话过期或用户
/// 重新登录都不影响这里，密码单独存在加密存储中，可随时静默重新登录。
///
/// 它只负责换取并缓存考勤网页版所需的 SSO 令牌，考勤签到本身在网页里完成。
class AttendanceProvider with ChangeNotifier {
  final SsoTokenService _ssoTokenService;

  AttendanceProvider({SsoTokenService? ssoTokenService})
      : _ssoTokenService = ssoTokenService ?? SsoTokenService() {
    // 构造即读取本地凭据：考勤页只根据 isConfigured 决定显示绑定表单还是网页版，
    // 若等到页面自己去触发加载，冷启动时会先判成「未配置」而卡在绑定表单上。
    ensureLoaded();
  }

  bool _loaded = false;
  bool _isAuthorizing = false;
  Future<String?>? _authorizingFuture;
  Future<void>? _loadingFuture;
  String _savedUsername = '';
  bool _hasPassword = false;
  AttendanceSsoTokens _tokens = const AttendanceSsoTokens();
  String _lastError = '';
  SsoCaptchaChallenge? _captcha;

  /// 本地凭据是否已读取完成。未完成时不应据此判断「未配置」。
  bool get isLoaded => _loaded;

  /// 是否已保存完整的账号密码。
  bool get isConfigured => _savedUsername.isNotEmpty && _hasPassword;

  /// 服务端要求图形验证码，等待用户填写。
  bool get needsCaptcha => _captcha != null;

  /// 当前验证码图片；[needsCaptcha] 为 false 时是 null。
  Uint8List? get captchaImage => _captcha?.imageBytes;

  String get savedUsername => _savedUsername;

  bool get isAuthorizing => _isAuthorizing;

  String get lastError => _lastError;

  String get userToken => _tokens.userToken;
  String get ctTicket => _tokens.ctTicket;
  String get appCtTicket => _tokens.appCtTicket;

  /// 读取本地保存的账号与令牌；并发调用共享同一次读取。
  Future<void> ensureLoaded() {
    if (_loaded) {
      return Future<void>.value();
    }
    return _loadingFuture ??= _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      _savedUsername = await AttendanceCredentialStore.readUsername();
      _hasPassword = (await AttendanceCredentialStore.readPassword()).isNotEmpty;
      _tokens = await AttendanceCredentialStore.readTokens();
    } catch (e) {
      // 读失败时按「未配置」处理，用户可在设置里重新填写。
      debugPrint('Attendance credentials load failed: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// 保存账号密码并立即校验登录；返回错误文案，null 表示校验通过。
  ///
  /// 只有校验通过才会切到「已配置」，避免把错误账号直接带进考勤网页版；
  /// 校验失败时凭据仍然落盘，方便用户在设置里只改密码。
  /// 若服务端因为密码连续输错而要求图形验证码，会取好图并置 [needsCaptcha]，
  /// 由表单接着调用 [submitCaptcha]。
  Future<String?> saveCredentials({
    required String username,
    required String password,
  }) async {
    try {
      await AttendanceCredentialStore.saveCredentials(
        username: username,
        password: password,
      );
    } catch (e) {
      debugPrint('Attendance credentials save failed: $e');
      return '智慧考勤账号保存失败：$e';
    }

    // 先丢弃旧令牌，避免切换账号时沿用上一个账号的登录态。
    await AttendanceCredentialStore.clearTokens();
    _tokens = const AttendanceSsoTokens();
    _savedUsername = username;
    _hasPassword = true;
    _captcha = null;

    final error = await _refreshSsoTokens();
    if (error == null) {
      _lastError = '';
      notifyListeners();
      return null;
    }

    // 服务端要求验证码：取图并停在表单，等用户填写后再重试登录。
    if (_ssoTokenService.captchaRequired) {
      _lastError = error;
      _hasPassword = false;
      final challenge = await _ssoTokenService.fetchCaptcha();
      _captcha = challenge;
      notifyListeners();
      return challenge == null
          ? (_ssoTokenService.lastError.isNotEmpty
              ? _ssoTokenService.lastError
              : '需要图形验证码，但获取验证码图片失败，请稍后重试')
          : '请输入图形验证码';
    }

    // 校验失败：保留账号但标记为「未就绪」，页面继续停在绑定表单。
    _lastError = error;
    _hasPassword = false;
    notifyListeners();
    return error;
  }

  /// 提交图形验证码；成功则完成登录，返回 null。
  ///
  /// 校验通过后服务端记住本会话已过验证码，这里紧接着用已保存密码重新登录。
  Future<String?> submitCaptcha(String code) async {
    final challenge = _captcha;
    if (challenge == null) {
      return '验证码已失效，请重新获取';
    }

    final verifyError = await _ssoTokenService.verifyCaptcha(
      captchaId: challenge.captchaId,
      code: code.trim(),
    );
    if (verifyError != null) {
      // 与网页端一致：校验失败自动换一张。
      await refreshCaptcha();
      return verifyError;
    }

    _captcha = null;
    _hasPassword = true;
    final loginError = await _refreshSsoTokens();
    if (loginError == null) {
      _lastError = '';
      notifyListeners();
      return null;
    }

    // 仍然失败：可能验证码刚过期，重新取图让用户再试一次。
    if (_ssoTokenService.captchaRequired) {
      final refreshed = await _ssoTokenService.fetchCaptcha();
      _captcha = refreshed;
      _hasPassword = false;
      _lastError = loginError;
      notifyListeners();
      return loginError;
    }

    _hasPassword = false;
    _lastError = loginError;
    notifyListeners();
    return loginError;
  }

  /// 换一张验证码图片。
  Future<void> refreshCaptcha() async {
    final challenge = await _ssoTokenService.fetchCaptcha();
    _captcha = challenge;
    notifyListeners();
  }

  Future<void> clearCredentials() async {
    await AttendanceCredentialStore.clearCredentials();
    _savedUsername = '';
    _hasPassword = false;
    _tokens = const AttendanceSsoTokens();
    _lastError = '';
    _captcha = null;
    notifyListeners();
  }

  /// 确保 SSO 令牌与考勤会话可用；返回错误文案，null 表示就绪。
  Future<String?> ensureAuthorized({bool force = false}) {
    final inFlight = _authorizingFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final completer = Completer<String?>();
    _authorizingFuture = completer.future;
    _isAuthorizing = true;
    notifyListeners();

    Future<String?> run() async {
      try {
        final error = await _ensureAuthorizedInternal(force: force);
        completer.complete(error);
        return error;
      } catch (e) {
        final message = _describeError(e);
        completer.complete(message);
        return message;
      } finally {
        _isAuthorizing = false;
        _authorizingFuture = null;
        notifyListeners();
      }
    }

    return run();
  }

  /// 执行需要考勤令牌的操作；若判定是令牌失效，则重新登录后重试一次。
  Future<T> withAuthRetry<T>(
    Future<T> Function() action,
  ) async {
    final authError = await ensureAuthorized();
    if (authError != null) {
      throw Exception(authError);
    }

    try {
      return await action();
    } catch (e) {
      if (!_isSessionExpiredError(e)) {
        rethrow;
      }
      debugPrint('Attendance session expired, re-authorizing: $e');
      final retryError = await ensureAuthorized(force: true);
      if (retryError != null) {
        throw Exception(retryError);
      }
      return await action();
    }
  }

  /// 强制重新登录（令牌过期或用户点了「重新登录」）。
  Future<String?> refreshSession() => ensureAuthorized(force: true);

  /// 确保令牌可用；若失败原因是令牌过期/未授权，则丢弃旧令牌重新登录一次。
  ///
  /// 缓存令牌可能在几天后失效，这是进入考勤页时最常见的失败原因。
  Future<String?> ensureAuthorizedWithRecovery() async {
    final error = await ensureAuthorized();
    if (error == null || !_isSessionExpiredError(error)) {
      return error;
    }

    debugPrint('Attendance authorization failed, retrying with fresh login: $error');
    return ensureAuthorized(force: true);
  }

  Future<String?> _ensureAuthorizedInternal({required bool force}) async {
    await ensureLoaded();
    if (!isConfigured) {
      return '尚未配置智慧考勤账号';
    }

    if (!force && !_tokens.isEmpty) {
      _lastError = '';
      return null;
    }

    final tokenError = await _refreshSsoTokens();
    if (tokenError != null) {
      _lastError = tokenError;
      return tokenError;
    }

    _lastError = '';
    return null;
  }

  Future<String?> _refreshSsoTokens() async {
    final username = _savedUsername;
    if (username.isEmpty) {
      return '尚未配置智慧考勤账号';
    }

    String password;
    try {
      password = await AttendanceCredentialStore.readPassword();
    } catch (e) {
      // 加密存储解不开（例如换机恢复备份后密钥丢失）时给出可执行的提示。
      debugPrint('Attendance password read failed: $e');
      return '读取智慧考勤密码失败，请到「设置 → 智慧考勤账号」重新填写';
    }

    if (password.isEmpty) {
      return '未读取到智慧考勤密码，请到「设置 → 智慧考勤账号」重新填写';
    }

    // 重新登录前先丢弃旧令牌，避免切换账号时串号。
    await AttendanceCredentialStore.clearTokens();
    _tokens = const AttendanceSsoTokens();

    final session = await _ssoTokenService.loginAndFetchToken(
      username: username,
      password: password,
    );
    password = '';

    if (session == null || session.userToken.isEmpty) {
      final reason = _ssoTokenService.lastError;
      return reason.isNotEmpty ? reason : '智慧考勤登录失败，请检查账号密码后重试';
    }

    _tokens = AttendanceSsoTokens(
      userToken: session.userToken,
      ctTicket: session.ctTicket,
      appCtTicket: session.appCtTicket,
    );
    await AttendanceCredentialStore.saveTokens(_tokens);
    return null;
  }

  bool _isSessionExpiredError(Object error) {
    final message = _describeError(error);
    return message.contains('未授权') ||
        message.contains('未找到授权信息') ||
        message.contains('会话未初始化') ||
        message.contains('统一认证') ||
        message.contains('令牌');
  }

  String _describeError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .trim();
  }
}
