import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/asymmetric/api.dart';

/// 智慧山体统一认证（SSO）会话：考勤接口所需的三个凭据。
class SsoSession {
  final String userToken;
  final String ctTicket;
  final String appCtTicket;

  const SsoSession({
    required this.userToken,
    this.ctTicket = '',
    this.appCtTicket = '',
  });
}

/// 一次图形验证码挑战：图片字节 + 服务端下发的 captchaId。
class SsoCaptchaChallenge {
  final String captchaId;
  final Uint8List imageBytes;

  const SsoCaptchaChallenge({
    required this.captchaId,
    required this.imageBytes,
  });
}

/// 用「智慧山体」学号 + 密码换取校园 SSO 令牌。
///
/// 流程：
/// 1. 请求 oauth2 authorize，沿着 302 跳转链寻找 `userToken`；
/// 2. 若被引导到登录页，则取 RSA 公钥加密账号密码调用 `verifyWebUser` 登录；
/// 3. 登录成功后重新走一遍 authorize，并从 Cookie 中读取 CTTICKET/APPCTTICKET。
///
/// 密码连续输错后服务端会要求图形验证码（`data.isCaptcha`）：此时先用
/// [fetchCaptcha] 取图、[verifyCaptcha] 校验，再重新登录。校验结果记在服务端
/// 会话（Cookie）里，验证码本身不随登录请求提交，所以三步必须共用同一个实例。
class SsoTokenService {
  static const String _authorizeUrl =
      'https://sso.sdpei.edu.cn/oauth2/authorize?response_type=redirect&state=1&client_id=e72d418ef4a0442c8750ecc5fef3da9b&redirect_uri=https://jxzlbz.sdpei.edu.cn/api/manage/cas/toUrl?type=mobile';

  static const String _ssoApiBase = 'https://sso.sdpei.edu.cn/ssoApi';

  /// 验证码尺寸，与官方网页端取值一致。
  static const int captchaWidth = 90;
  static const int captchaHeight = 38;

  /// 验证码位数（网页端按 4 位自动校验）。
  static const int captchaLength = 4;

  /// 登录失败原因，供调用方提示用户（凭据错误 / 网络异常）。
  String _lastError = '';

  String get lastError => _lastError;

  /// 上一次登录失败是否因为需要图形验证码。
  bool _captchaRequired = false;

  bool get captchaRequired => _captchaRequired;

  final CookieJar _cookieJar = CookieJar();
  late final Dio _dio;

  SsoTokenService() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Mobile Safari/537.36',
        },
      ),
    );
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  Future<SsoSession?> loginAndFetchToken({
    required String username,
    required String password,
  }) async {
    _lastError = '';
    try {
      var currentUrl = _authorizeUrl;
      var authorizeResp = await _dio.get<String>(currentUrl);
      var token = await _extractTokenFromAuthorizeStep(authorizeResp);

      // 未登录时会一路跳到登录页，此时 Location 不再携带 token。
      while (token == null || token.isEmpty) {
        final location = authorizeResp.headers.value('location') ?? '';
        if (location.isEmpty) {
          break;
        }
        currentUrl = _resolveUrl(currentUrl, location).toString();
        authorizeResp = await _dio.get<String>(currentUrl);
        token = await _extractTokenFromAuthorizeStep(authorizeResp);
      }

      if (token == null || token.isEmpty) {
        final html = authorizeResp.data ?? '';
        if (!_looksLikeLoginPage(html)) {
          _lastError = '未能进入智慧山体统一认证登录页，请检查网络后重试';
          return null;
        }

        final loginOk = await _submitSsoLogin(
          username: username,
          password: password,
        );
        if (!loginOk) {
          return null;
        }

        // 登录成功后重新走一遍授权流程。
        var secondAuthorize = await _dio.get<String>(_authorizeUrl);
        token = await _extractTokenFromAuthorizeStep(secondAuthorize);

        while (token == null || token.isEmpty) {
          final location = secondAuthorize.headers.value('location') ?? '';
          if (location.isEmpty) {
            break;
          }
          final nextUrl = _resolveUrl(_authorizeUrl, location).toString();
          secondAuthorize = await _dio.get<String>(nextUrl);
          token = await _extractTokenFromAuthorizeStep(secondAuthorize);
        }
      }

      if (token == null || token.isEmpty) {
        if (_lastError.isEmpty) {
          _lastError = '统一认证已通过，但未获取到考勤令牌，请稍后重试';
        }
        return null;
      }

      final tickets = await _extractTickets();
      return SsoSession(
        userToken: token,
        ctTicket: tickets.$1,
        appCtTicket: tickets.$2,
      );
    } catch (e) {
      debugPrint('SSO loginAndFetchToken error: $e');
      _lastError = '统一认证请求失败：$e';
      return null;
    }
  }

  Future<String?> _extractTokenFromAuthorizeStep(Response<String> response) async {
    final location = response.headers.value('location') ?? '';
    if (location.isEmpty) {
      return null;
    }

    final directToken = _extractUserToken(location);
    if (directToken.isNotEmpty) {
      return directToken;
    }

    if (location.contains('/api/manage/cas/toUrl') && location.contains('code=')) {
      return _fetchTokenByCallback(location);
    }

    return null;
  }

  Future<String?> _fetchTokenByCallback(String callbackLocation) async {
    final callbackUri = _resolveUrl(_authorizeUrl, callbackLocation);
    final callbackResp = await _dio.get<String>(callbackUri.toString());
    final location = callbackResp.headers.value('location') ?? '';
    final token = _extractUserToken(location);
    if (token.isEmpty) {
      return null;
    }
    return token;
  }

  /// 取 RSA 公钥加密账号密码后登录统一认证。
  Future<bool> _submitSsoLogin({
    required String username,
    required String password,
  }) async {
    final basicInfoResp = await _dio.post<String>(
      '$_ssoApiBase/getLoginBasicInfo',
      data: _buildLoginParams(),
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final basicInfoData = jsonDecode(basicInfoResp.data ?? '{}');
    if (basicInfoData['code'] != '0x000000') {
      debugPrint('Failed to get login basic info: ${basicInfoResp.data}');
      _lastError = '无法获取统一认证公钥，请稍后重试';
      return false;
    }

    String publicKeyPem = basicInfoData['data']['publicEn'] as String;
    publicKeyPem = publicKeyPem
        .replaceAll('BEGIN RSA Public Key', 'BEGIN PUBLIC KEY')
        .replaceAll('END RSA Public Key', 'END PUBLIC KEY');

    final parser = RSAKeyParser();
    final rsaPublicKey = parser.parse(publicKeyPem) as RSAPublicKey;
    final encrypter = Encrypter(RSA(publicKey: rsaPublicKey));

    final verifyResp = await _dio.post<String>(
      '$_ssoApiBase/verifyWebUser',
      data: {
        ..._buildLoginParams(),
        'account': encrypter.encrypt(username).base64,
        'password': encrypter.encrypt(password).base64,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final verifyData = jsonDecode(verifyResp.data ?? '{}');
    if (verifyData['code'] == '0x000000') {
      _captchaRequired = false;
      return true;
    }

    debugPrint('verifyWebUser failed: ${verifyResp.data}');
    final serverMessage = verifyData['msg']?.toString() ??
        verifyData['message']?.toString() ??
        '';

    // 服务端要求验证码：网页端判据是 data.isCaptcha，这里再兜一层文案判断，
    // 避免字段名有出入时功能完全不可用。
    _captchaRequired = isCaptchaRequired(verifyData) ||
        serverMessage.contains('验证码');

    _lastError = serverMessage.isNotEmpty
        ? serverMessage
        : '智慧山体学号或密码错误，请在设置中核对后重试';
    return false;
  }

  /// 登录响应是否要求图形验证码。
  static bool isCaptchaRequired(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map) {
      return data['isCaptcha'] == true || data['isCaptcha']?.toString() == 'true';
    }
    return false;
  }

  /// 解析 `getPictureVerifyCode` 的响应；失败返回 null。
  ///
  /// 返回体形如：
  /// `{"code":"0x000000","msg":"成功","data":{"base64":"data:image/png;base64,…","captchaId":"…"}}`
  static SsoCaptchaChallenge? parseCaptchaResponse(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) {
      return null;
    }

    if (decoded['code'] != '0x000000') {
      return null;
    }

    final data = decoded['data'];
    if (data is! Map) {
      return null;
    }

    final captchaId = data['captchaId']?.toString().trim() ?? '';
    final rawBase64 = data['base64']?.toString().trim() ?? '';
    if (captchaId.isEmpty || rawBase64.isEmpty) {
      return null;
    }

    // 服务端返回的是完整 data URI，只取逗号后面的 base64 部分。
    final commaIndex = rawBase64.indexOf(',');
    final base64Part =
        rawBase64.startsWith('data:') && commaIndex != -1
            ? rawBase64.substring(commaIndex + 1)
            : rawBase64;

    try {
      final bytes = base64Decode(base64Part);
      if (bytes.isEmpty) {
        return null;
      }
      return SsoCaptchaChallenge(captchaId: captchaId, imageBytes: bytes);
    } catch (_) {
      return null;
    }
  }

  /// 取一张图形验证码。失败时 [lastError] 给出原因。
  Future<SsoCaptchaChallenge?> fetchCaptcha() async {
    try {
      final response = await _dio.post<String>(
        '$_ssoApiBase/getPictureVerifyCode',
        data: const {
          'chkHeight': captchaHeight,
          'chkWidth': captchaWidth,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final body = response.data ?? '';
      final challenge = parseCaptchaResponse(body);
      if (challenge == null) {
        final dynamic decoded = _tryDecode(body);
        _lastError = (decoded is Map ? decoded['msg']?.toString() : null) ??
            '获取图形验证码失败，请稍后重试';
        debugPrint('fetchCaptcha failed: $body');
      }
      return challenge;
    } catch (e) {
      debugPrint('fetchCaptcha error: $e');
      _lastError = '获取图形验证码失败：$e';
      return null;
    }
  }

  /// 校验图形验证码；成功返回 null，失败返回可直接展示的原因。
  ///
  /// 校验通过后服务端会在会话里记住，因此紧接着调用 [loginAndFetchToken] 即可。
  Future<String?> verifyCaptcha({
    required String captchaId,
    required String code,
  }) async {
    try {
      final response = await _dio.post<String>(
        '$_ssoApiBase/verifyCaptcha',
        data: {
          'captchaId': captchaId,
          'verifyValue': code,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final dynamic decoded = _tryDecode(response.data ?? '');
      if (decoded is Map && decoded['code'] == '0x000000') {
        return null;
      }

      final msg = decoded is Map
          ? (decoded['msg']?.toString() ?? decoded['message']?.toString() ?? '')
          : '';
      debugPrint('verifyCaptcha failed: ${response.data}');
      return msg.isNotEmpty ? msg : '图形验证码验证失败，请重新输入';
    } catch (e) {
      debugPrint('verifyCaptcha error: $e');
      return '验证码校验失败：$e';
    }
  }

  dynamic _tryDecode(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// 统一认证客户端信息，与官方移动端 H5 保持一致。
  Map<String, String> _buildLoginParams() {
    return const {
      'appname': 'zhjd',
      'clientIp': '192.168.1.101',
      'clientType': '0',
      'clientVerNum': '2.0.7',
      'device': '543f82e47c4c436e2d2e23cd40a75509',
      'deviceModel': 'iPhone18,3',
      'md5': '',
      'osType': 'ios',
      'source': '158',
    };
  }

  String _extractUserToken(String location) {
    final match = RegExp(r'userToken=([^&]+)').firstMatch(location);
    if (match != null) {
      return Uri.decodeComponent(match.group(1) ?? '');
    }

    final uri = Uri.tryParse(location);
    if (uri == null) {
      return '';
    }

    final fragmentMatch = RegExp(r'userToken=([^&]+)').firstMatch(uri.fragment);
    if (fragmentMatch == null) {
      return '';
    }

    return Uri.decodeComponent(fragmentMatch.group(1) ?? '');
  }

  bool _looksLikeLoginPage(String html) {
    if (html.isEmpty) {
      return false;
    }
    // 统一认证前端是 Vue SPA，页面本身没有表单，只能靠容器标识判断。
    return html.contains('<div id="app"') ||
        html.contains('ssoApi') ||
        (html.contains('<form') &&
            (html.toLowerCase().contains('password') ||
                html.toLowerCase().contains('username')));
  }

  Uri _resolveUrl(String base, String maybeRelative) {
    final baseUri = Uri.parse(base);
    return baseUri.resolve(maybeRelative);
  }

  Future<(String, String)> _extractTickets() async {
    final jxzCookies = await _cookieJar.loadForRequest(
      Uri.parse('https://jxzlbz.sdpei.edu.cn/'),
    );
    final ssoCookies = await _cookieJar.loadForRequest(
      Uri.parse('https://sso.sdpei.edu.cn/'),
    );

    final all = [...jxzCookies, ...ssoCookies];
    final ctTicket = _findCookieValue(all, 'CTTICKET');
    final appCtTicket = _findCookieValue(all, 'APPCTTICKET');
    return (ctTicket, appCtTicket);
  }

  String _findCookieValue(List<Cookie> cookies, String name) {
    for (final cookie in cookies) {
      if (cookie.name == name) {
        return cookie.value;
      }
    }
    return '';
  }
}
