import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/infrastructure/network/network_retry.dart';

void main() {
  group('NetworkRetry.isRetriable', () {
    test('detects NO_RENEGOTIATION ssl errors', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/'),
        error: 'HttpException: NO_RENEGOTIATION(ssl_lib.cc:1641)',
      );

      expect(NetworkRetry.isRetriable(error), isTrue);
    });

    test('detects connection timeouts', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionTimeout,
      );

      expect(NetworkRetry.isRetriable(error), isTrue);
    });

    test('ignores non-transient application errors', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 404,
        ),
      );

      expect(NetworkRetry.isRetriable(error), isFalse);
    });
  });

  group('NetworkRetry.prepareForRetry', () {
    test('replaces a finalized FormData with a reusable clone', () async {
      final form = FormData.fromMap({
        'method': 'DoLogin',
        'userId': 'MjAyMzQ2MDkwMDMz',
        'userPwd': 'dGVzdA==',
      });
      // 读一次内容流即完成 finalize，等价于「请求已经发出过一次」。
      await form.readAsBytes();
      expect(form.isFinalized, isTrue);
      // 前提确认：这正是线上重试失败的原因，未做准备时第二次发送会抛 StateError。
      expect(form.readAsBytes, throwsA(isA<StateError>()));

      final options = RequestOptions(path: '/LoginHandler.ashx', data: form);
      NetworkRetry.prepareForRetry(options);

      final prepared = options.data;
      expect(prepared, isA<FormData>());
      expect(identical(prepared, form), isFalse, reason: '必须是新对象');
      final clone = prepared as FormData;
      expect(clone.isFinalized, isFalse, reason: '克隆体应可再次发送');
      expect(clone.boundary, form.boundary,
          reason: 'boundary 必须与 Content-Type 头里的保持一致');

      final body = utf8.decode(await clone.readAsBytes());
      expect(body, contains('DoLogin'));
      expect(body, contains('MjAyMzQ2MDkwMDMz'));
      expect(body, contains('dGVzdA=='));
    });

    test('leaves a non-finalized FormData untouched', () {
      final form = FormData.fromMap({'a': '1'});
      final options = RequestOptions(path: '/', data: form);

      NetworkRetry.prepareForRetry(options);

      expect(identical(options.data, form), isTrue);
    });

    test('leaves non-FormData bodies untouched', () {
      final map = {'a': '1'};
      final options = RequestOptions(path: '/', data: map);

      NetworkRetry.prepareForRetry(options);

      expect(identical(options.data, map), isTrue);
    });

    test('tolerates a null body', () {
      final options = RequestOptions(path: '/');

      expect(() => NetworkRetry.prepareForRetry(options), returnsNormally);
    });
  });
}
