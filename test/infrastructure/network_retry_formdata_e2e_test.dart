import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/features/auth/data/auth_service.dart';
import 'package:JWHelper/infrastructure/network/client.dart';

/// 假传输层：前 [failuresBeforeSuccess] 次抛连接异常（模拟网络抖动），之后返回成功。
/// 用来真实地走一遍「首次失败 → 拦截器重试」这条路径，而不触碰真实网络。
class _FlakyAdapter implements HttpClientAdapter {
  /// 前一次调用失败，第二次起成功。
  static const int failuresBeforeSuccess = 1;

  int calls = 0;
  final List<int> bodyLengths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    // 真实传输层会消费请求体流，这里照做，才能复现 FormData 被 finalize 的时序。
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      bodyLengths.add(chunks.fold<int>(0, (sum, chunk) => sum + chunk.length));
    }
    if (calls <= failuresBeforeSuccess) {
      throw const SocketException('simulated transient network failure');
    }
    // 教务系统 DoLogin 成功时返回字面量 true。
    return ResponseBody.fromString(
      'true',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.textPlainContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('登录请求遇到网络抖动后重试，不会因 FormData 已 finalize 而失败', () async {
    final client = ApiClient();
    await client.init();
    final adapter = _FlakyAdapter();
    client.dio.httpClientAdapter = adapter;

    final result = await AuthService().login('202346090033', 'test-password');

    expect(
      result['success'],
      isTrue,
      reason: '重试必须真正发出请求并成功。若重试前没有重建 FormData，dio 会在准备'
          '请求体时就抛「The FormData has already been finalized」，'
          '请求根本到不了传输层（adapter 只会被调用 1 次）。',
    );
    expect(adapter.calls, 2, reason: '首次失败后应恰好重试一次');
    expect(adapter.bodyLengths, hasLength(2), reason: '两次尝试都应带上请求体');
    expect(
      adapter.bodyLengths[1],
      greaterThan(0),
      reason: '重试必须带上完整请求体（登录参数在 FormData 里）',
    );
  });
}
