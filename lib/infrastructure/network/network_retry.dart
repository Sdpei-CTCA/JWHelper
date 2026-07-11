import 'package:dio/dio.dart';

class NetworkRetry {
  static const int maxRetries = 2;

  static bool isRetriable(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }

    final message = '${error.message ?? ''} ${error.error ?? ''}'.toLowerCase();
    return message.contains('no_renegotiation') ||
        message.contains('connection reset') ||
        message.contains('connection closed') ||
        message.contains('handshake') ||
        message.contains('socketexception');
  }

  static int attemptFor(RequestOptions options) {
    return (options.extra['retry_attempt'] as int?) ?? 0;
  }

  static void markNextAttempt(RequestOptions options) {
    options.extra['retry_attempt'] = attemptFor(options) + 1;
  }
}
