import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:JWHelper/core/constants/config.dart';
import 'package:JWHelper/features/notice/data/notice_parser.dart';
import 'package:JWHelper/features/notice/data/notice_source.dart';
import 'package:JWHelper/features/notice/domain/notice_detail.dart';
import 'package:JWHelper/features/notice/domain/notice_item.dart';

/// 学校信息发布平台（`pubinfo.sdpei.edu.cn`）的数据源。
///
/// 该站点整站被统一认证网关挡住（连 `/css/`、`/favicon.ico` 都 302 到 SSO），
/// 但通过抓包确认，页面本身也是走 JSON 接口取数的：
///
/// - `GET /info/getInfoAllIndex?...`：列表（含主键、标题、部门、时间、附件标记）
/// - `GET /info/getInfoById?id=<ms_id>`：详情（正文 HTML 片段 + 附件列表）
/// - `GET /info/downfile?id=<mia_id>&infoid=<ms_id>`：附件下载
///
/// 所以这里不解析 HTML，只带 Cookie 调接口。Cookie 来自考勤模块换来的统一
/// 认证票据（`CTTICKET` / `APPCTTICKET`），加上服务端下发的 `JSESSIONID`。
///
/// 自己维护 Cookie 字典而不用 CookieJar：站点只有单域名 + 几个会话 Cookie，
/// 手写更可预测，也不会和教务系统的会话互相污染。
class PubinfoNoticeSource implements NoticeSource {
  PubinfoNoticeSource({Dio? dio}) : _dio = dio ?? _buildDio();

  static const String origin = 'https://pubinfo.sdpei.edu.cn';
  static final Uri _originUri = Uri.parse(origin);

  /// 一次取多少条。站点总数约百条量级，50 条足够覆盖最近几个月。
  static const int pageSize = 50;

  final Dio _dio;
  final Map<String, String> _cookies = {};

  /// 是否已经完成会话引导（先访问 index.jsp 换到 JSESSIONID）。
  bool _sessionReady = false;
  Future<void>? _sessionFuture;

  /// 最近一次请求的诊断信息，解析失败时展示给用户。
  String lastDiagnostics = '';

  /// 失败时的响应摘要（可一键复制反馈）。
  String lastStructureSummary = '';

  static Dio _buildDio() {
    return Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 12),
      followRedirects: false,
      responseType: ResponseType.plain,
      validateStatus: (status) => status != null && status < 500,
      headers: {
        'User-Agent': Config.userAgent,
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.6',
        // 接口靠这个头判断是 AJAX 请求，缺了会返回登录页或 500。
        'X-Requested-With': 'XMLHttpRequest',
      },
    ));
  }

  @override
  void updateCredentials({
    required String userToken,
    required String ctTicket,
    required String appCtTicket,
  }) {
    // 换了登录态就丢掉上一次会话的 JSESSIONID，避免沿用别人的会话 ID。
    final previous = _cookies['CTTICKET'] ?? '';
    if (ctTicket.isNotEmpty && previous.isNotEmpty && ctTicket != previous) {
      _cookies.clear();
      _sessionReady = false;
      _sessionFuture = null;
    }

    if (userToken.isNotEmpty) _cookies['userToken'] = userToken;
    if (ctTicket.isNotEmpty) _cookies['CTTICKET'] = ctTicket;
    if (appCtTicket.isNotEmpty) _cookies['APPCTTICKET'] = appCtTicket;
  }

  @override
  Future<List<NoticeItem>> fetchList() async {
    lastDiagnostics = '';
    lastStructureSummary = '';

    final uri = Uri.parse('$origin${NoticeParser.listPath}').replace(
      queryParameters: {
        'begin_num': '0',
        'num': '$pageSize',
        'scode': NoticeParser.scode,
        'sate': '2',
        'd_state': '2',
        'dxtx': '-1',
        'in_ms_title': '',
      },
    );

    final body = await _get(uri, referer: '$origin/index.jsp');
    final json = _decode(body);
    final items = NoticeParser.parseListJson(json, _originUri);

    final total = json['iTotalRecords']?.toString() ?? '?';
    lastDiagnostics =
        '接口正常 · 返回 ${items.length} 条 / 共 $total 条';

    return items;
  }

  @override
  Future<NoticeDetail> fetchDetail(NoticeItem item) async {
    final uri = Uri.parse('$origin${NoticeParser.detailPath}')
        .replace(queryParameters: {'id': item.id});

    final body = await _get(
      uri,
      referer: item.url,
    );
    final json = _decode(body);
    final detail = NoticeParser.parseDetailJson(
      json,
      _originUri,
      fallbackTitle: item.title,
    );

    if (detail.isEmpty) {
      throw const NoticeException(
        NoticeErrorKind.parse,
        '这条通知没有正文（可能只有附件），可以看原文',
      );
    }
    return detail;
  }

  @override
  Future<Uint8List?> fetchBytes(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;

    // 只有平台自己域名下的资源才需要先引导会话；static 静态资源直接取。
    if (uri.host == _originUri.host) {
      await _ensureSession();
    }

    try {
      final response = await _dio.getUri<List<int>>(
        uri,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) => status != null && status < 400,
          headers: {
            if (_cookies.isNotEmpty) 'Cookie': _cookieHeader,
            'Referer': '$origin/',
            'Accept': 'image/avif,image/webp,image/*,*/*;q=0.8',
          },
        ),
      );
      final data = response.data;
      if (data == null || data.isEmpty) return null;
      return Uint8List.fromList(data);
    } on DioException catch (e) {
      debugPrint('Notice image fetch failed (${e.type.name}): ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Notice image fetch failed: $e');
      return null;
    }
  }

  Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) {
      throw const NoticeException(NoticeErrorKind.parse, '接口返回了空内容');
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      throw const FormatException('不是对象');
    } catch (e) {
      // 常见情况：登录态失效后接口返回了登录页 HTML。
      lastStructureSummary = NoticeParser.summarizeBody(body);
      if (_looksLikeLoginPage(body)) {
        throw const NoticeException(
          NoticeErrorKind.authFailed,
          '登录态已失效，接口返回了登录页',
        );
      }
      throw NoticeException(
        NoticeErrorKind.parse,
        '接口返回的不是 JSON（${NoticeParser.summarizeBody(body).split('\n').first}）',
      );
    }
  }

  /// 建立会话：先请求一次 `index.jsp`。
  ///
  /// 抓包确认：只带 `CTTICKET` 直接请求 JSON 接口会被网关 302 回 `index.jsp`；
  /// 而先访问 `index.jsp`（它会 302 到自己一次并下发 `JSESSIONID`）之后，
  /// 同样的票据就能正常取数。这一步就是浏览器的「打开首页」动作。
  Future<void> _ensureSession() {
    if (_sessionReady) return Future<void>.value();
    return _sessionFuture ??=
        _ensureSessionInternal().catchError((Object e, StackTrace s) {
      _sessionFuture = null;
      Error.throwWithStackTrace(e, s);
    });
  }

  Future<void> _ensureSessionInternal() async {
    var url = Uri.parse('$origin/index.jsp');
    for (var hop = 0; hop < 3; hop++) {
      final Response<String> response;
      try {
        response = await _dio.getUri<String>(
          url,
          options: Options(headers: {
            if (_cookies.isNotEmpty) 'Cookie': _cookieHeader,
            'Referer': '$origin/',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          }),
        );
      } on DioException catch (e) {
        throw NoticeException(NoticeErrorKind.network, _describeDioError(e));
      }

      _captureCookies(response);
      final status = response.statusCode ?? 0;

      if (status == 200) {
        if (_looksLikeLoginPage(response.data ?? '')) {
          throw const NoticeException(
            NoticeErrorKind.authFailed,
            '登录态已失效，请在通知页重新登录统一认证',
          );
        }
        _sessionReady = true;
        return;
      }

      if (status >= 300 && status < 400) {
        final location = response.headers.value('location') ?? '';
        if (_isSsoRedirect(location)) {
          throw const NoticeException(
            NoticeErrorKind.authFailed,
            '登录态未被通知平台接受，需要重新登录统一认证',
          );
        }
        final next = url.resolve(location);
        if (next.host != url.host) {
          throw NoticeException(
            NoticeErrorKind.http,
            '打开通知首页时跳转到了外部地址（$location）',
          );
        }
        url = next;
        continue;
      }

      throw NoticeException(
        NoticeErrorKind.http,
        '打开通知首页失败（HTTP $status）',
      );
    }

    throw const NoticeException(
      NoticeErrorKind.http,
      '打开通知首页时跳转次数过多',
    );
  }

  Future<String> _get(Uri uri, {required String referer}) async {
    await _ensureSession();

    try {
      final response = await _dio.getUri<String>(
        uri,
        options: Options(headers: {
          if (_cookies.isNotEmpty) 'Cookie': _cookieHeader,
          'Referer': referer,
        }),
      );
      _captureCookies(response);

      final status = response.statusCode ?? 0;
      if (status >= 300 && status < 400) {
        final location = response.headers.value('location') ?? '';
        if (_isSsoRedirect(location)) {
          throw const NoticeException(
            NoticeErrorKind.authFailed,
            '登录态未被通知平台接受，需要重新登录统一认证',
          );
        }
        throw NoticeException(
          NoticeErrorKind.http,
          '通知平台跳转到了未知地址（${location.isEmpty ? '无 Location' : location}）',
        );
      }

      if (status != 200) {
        final body = response.data ?? '';
        if (_looksLikeLoginPage(body)) {
          throw const NoticeException(
            NoticeErrorKind.authFailed,
            '登录态已失效，请重新登录统一认证',
          );
        }
        lastStructureSummary = NoticeParser.summarizeBody(body);
        throw NoticeException(
          NoticeErrorKind.http,
          '通知接口返回 HTTP $status',
        );
      }

      final body = response.data ?? '';
      if (_looksLikeLoginPage(body)) {
        throw const NoticeException(
          NoticeErrorKind.authFailed,
          '登录态已失效，请重新登录统一认证',
        );
      }
      return body;
    } on NoticeException {
      rethrow;
    } on DioException catch (e) {
      throw NoticeException(NoticeErrorKind.network, _describeDioError(e));
    } catch (e) {
      throw NoticeException(NoticeErrorKind.network, '请求通知平台失败：$e');
    }
  }

  String get _cookieHeader =>
      _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  void _captureCookies(Response response) {
    final raw = response.headers['set-cookie'];
    if (raw == null) return;
    for (final item in raw) {
      final first = item.split(';').first;
      final index = first.indexOf('=');
      if (index <= 0) continue;
      final name = first.substring(0, index).trim();
      final value = first.substring(index + 1).trim();
      if (name.isEmpty) continue;
      _cookies[name] = value;
    }
  }

  bool _isSsoRedirect(String location) {
    final lower = location.toLowerCase();
    return lower.contains('sso.sdpei.edu.cn') ||
        lower.contains('code=0x0100') ||
        lower.contains('locationurl=');
  }

  /// 统一认证的登录页是 Vue SPA，特征是 `<div id="app">` + `sso`。
  bool _looksLikeLoginPage(String body) {
    if (body.isEmpty || body.length > 20000) return false;
    final lower = body.toLowerCase();
    return lower.contains('sso.sdpei.edu.cn') ||
        (lower.contains('<div id="app"') && lower.contains('sso'));
  }

  String _describeDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接通知平台超时，请检查网络后重试';
      case DioExceptionType.connectionError:
        return '无法连接通知平台，请确认是否在校园网内';
      case DioExceptionType.badCertificate:
        return '通知平台的证书校验失败';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        if (status >= 500) {
          return '通知平台暂时不可用（HTTP $status），请稍后重试';
        }
        return '通知接口返回 HTTP $status';
      default:
        return '请求通知平台失败：${error.message ?? error.type.name}';
    }
  }
}
