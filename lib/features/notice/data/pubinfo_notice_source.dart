import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:JWHelper/core/constants/config.dart';
import 'package:JWHelper/features/notice/data/notice_parser.dart';
import 'package:JWHelper/features/notice/data/notice_source.dart';
import 'package:JWHelper/features/notice/domain/notice_detail.dart';
import 'package:JWHelper/features/notice/domain/notice_item.dart';

/// 学校信息发布平台（`pubinfo.sdpei.edu.cn`）的抓取实现。
///
/// 该站点整站被统一认证网关挡住：任何路径（连 `/css/`、`/favicon.ico`）都会
/// 302 到 `sso.sdpei.edu.cn/?code=0x010040001&locationurl=...`。所以这里做的事
/// 就是「带上统一认证的票据再去请求」：
///
/// 1. 由 `AttendanceProvider` 用智慧山体账号换取 `CTTICKET` / `APPCTTICKET`；
/// 2. 把票据写进请求头里的 `Cookie`，直接请求列表页；
/// 3. 若仍被踢回 SSO，说明票据不被该站点接受，抛 [NoticeErrorKind.authFailed]。
///
/// 这里刻意不用 CookieJar：站点只有单域名 + 几个会话 Cookie，自己维护一个
/// 字典比依赖 CookieJar 的域名匹配更可预测，也不会和教务系统的会话互相污染。
class PubinfoNoticeSource implements NoticeSource {
  PubinfoNoticeSource({Dio? dio}) : _dio = dio ?? _buildDio();

  static const String origin = 'https://pubinfo.sdpei.edu.cn';
  static const String listPath = '/index.jsp';

  final Dio _dio;
  final Map<String, String> _cookies = {};

  /// 最近一次请求的诊断信息，解析失败时展示给用户，便于反馈问题。
  String lastDiagnostics = '';

  static Dio _buildDio() {
    return Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 12),
      followRedirects: false,
      responseType: ResponseType.plain,
      validateStatus: (status) => status != null && status < 500,
      headers: {
        'User-Agent': Config.userAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.6',
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
    }

    if (userToken.isNotEmpty) _cookies['userToken'] = userToken;
    if (ctTicket.isNotEmpty) _cookies['CTTICKET'] = ctTicket;
    if (appCtTicket.isNotEmpty) _cookies['APPCTTICKET'] = appCtTicket;
  }

  @override
  Future<List<NoticeItem>> fetchList() async {
    final response = await _request(listPath, referer: '$origin/');
    final html = response.data?.toString() ?? '';

    if (html.isEmpty) {
      throw const NoticeException(
        NoticeErrorKind.parse,
        '通知页返回了空内容',
      );
    }

    final uri = Uri.parse('$origin$listPath');
    final result = NoticeParser.parseList(html, uri);
    lastDiagnostics =
        'HTTP ${response.statusCode} · ${html.length} 字节 · 链接 ${result.anchorCount} · 命中 ${result.items.length} 条（带日期 ${result.datedCount}）';

    if (result.items.isEmpty) {
      await _dumpDebugHtml(html, 'index');
      throw NoticeException(
        NoticeErrorKind.parse,
        '页面已打开，但没能从里面认出通知条目（$lastDiagnostics）',
      );
    }

    return result.items;
  }

  @override
  Future<NoticeDetail> fetchDetail(NoticeItem item) async {
    final uri = Uri.tryParse(item.url);
    if (uri == null || uri.host.isEmpty) {
      throw const NoticeException(NoticeErrorKind.http, '通知链接不合法');
    }

    final response = await _request(
      uri.path.isEmpty ? '/' : '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}',
      referer: '$origin$listPath',
    );
    final html = response.data?.toString() ?? '';

    if (html.isEmpty) {
      throw const NoticeException(NoticeErrorKind.parse, '通知正文为空');
    }

    final detail = NoticeParser.parseDetail(html, uri, fallbackTitle: item.title);
    if (detail.isEmpty) {
      await _dumpDebugHtml(html, 'detail');
      throw const NoticeException(
        NoticeErrorKind.parse,
        '正文没认出来，可以改用网页打开',
      );
    }
    return detail;
  }

  Future<Response<String>> _request(
    String path, {
    required String referer,
  }) async {
    final uri = path.startsWith('http') ? Uri.parse(path) : Uri.parse('$origin$path');

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
      if (status == 301 || status == 302 || status == 303 || status == 307) {
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
        throw NoticeException(
          NoticeErrorKind.http,
          '通知平台返回 HTTP $status',
        );
      }

      final body = response.data ?? '';
      if (_looksLikeSsoPage(body)) {
        throw const NoticeException(
          NoticeErrorKind.authFailed,
          '当前登录态已失效，请重新登录统一认证',
        );
      }

      return response;
    } on NoticeException {
      rethrow;
    } on DioException catch (e) {
      throw NoticeException(
        NoticeErrorKind.network,
        _describeDioError(e),
      );
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

  /// 有的网关会返回 200 但内容其实是统一认证的登录页。
  bool _looksLikeSsoPage(String body) {
    if (body.length > 4000) return false;
    return body.contains('sso.sdpei.edu.cn') ||
        (body.contains('<div id="app"') && body.contains('sso'));
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
      default:
        return '请求通知平台失败：${error.message ?? error.type.name}';
    }
  }

  /// 解析不出内容时把原始页面落盘，方便排查改版。
  ///
  /// 只在失败路径执行，不影响正常使用；路径会打进日志。
  Future<void> _dumpDebugHtml(String html, String tag) async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/.notice_debug/${tag}_last.html');
      await file.parent.create(recursive: true);
      await file.writeAsString(html);
      debugPrint('Notice raw html dumped to ${file.path}');
    } catch (e) {
      debugPrint('Notice raw html dump failed: $e');
    }
  }
}
