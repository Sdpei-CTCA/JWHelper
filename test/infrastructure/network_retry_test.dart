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
}
