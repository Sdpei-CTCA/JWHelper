import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/app/update/update_service.dart';

/// 按主机名分发的假传输层：GitHub 与 Gitee 各返回一份预设响应。
class _RoutedAdapter implements HttpClientAdapter {
  _RoutedAdapter({required this.githubBody, required this.giteeBody});

  final String githubBody;
  final String giteeBody;
  final List<String> requestedUris = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedUris.add(options.uri.toString());
    final body = options.uri.host.contains('github') ? githubBody : giteeBody;
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  UpdateService serviceWith({required String github, required String gitee}) {
    final dio = Dio(BaseOptions(validateStatus: (s) => s != null && s < 500));
    dio.httpClientAdapter = _RoutedAdapter(githubBody: github, giteeBody: gitee);
    return UpdateService(dio: dio);
  }

  // GitHub 的 assets 不是数组，会让 _parseReleaseData 内部抛 TypeError。
  // 关键是这个异常发生在 await 之后：若 _fetchGithubRelease 不 await 它，
  // 异常会绕过自己的 catch，让 checkUpdate 里的 Future.wait 整体失败，
  // Gitee 那份完好的数据也被一起丢掉。
  const brokenGithub = '{"tag_name":"v9.9.9","name":"9.9.9","assets":"boom"}';
  const goodGitee = '{"tag_name":"v1.4.6","name":"1.4.6","body":"gitee notes",'
      '"assets":[{"name":"app-arm64-v8a-release.apk",'
      '"browser_download_url":"https://gitee.com/dl/app-arm64-v8a-release.apk"}]}';

  test('单个平台解析失败时仍能完成检查，并采用另一平台的结果', () async {
    final service = serviceWith(github: brokenGithub, gitee: goodGitee);

    // 缺少 await 时这里会抛出 _parseReleaseData 内部的 TypeError。
    final result = await service.checkUpdate();

    expect(result.latestVersion, '1.4.6', reason: '应采信 Gitee 的结果');
    expect(result.releaseNotes, 'gitee notes');
    expect(result.downloadUrl, contains('gitee.com'));
  });

  test('两个平台都拿不到结果时才抛错', () async {
    const deadGithub = '{"assets":"boom"}';
    const deadGitee = '{"assets":"boom"}';
    final service = serviceWith(github: deadGithub, gitee: deadGitee);

    expect(service.checkUpdate(), throwsA(isA<Exception>()));
  });

  test('两个平台都正常时取版本更高的那个', () async {
    const goodGithub = '{"tag_name":"v1.4.5","name":"1.4.5","body":"github notes",'
        '"assets":[{"name":"app-arm64-v8a-release.apk",'
        '"browser_download_url":"https://github.com/dl/app-arm64-v8a-release.apk"}]}';
    final service = serviceWith(github: goodGithub, gitee: goodGitee);

    final result = await service.checkUpdate();

    expect(result.latestVersion, '1.4.6');
    expect(result.releaseNotes, 'gitee notes');
  });
}
