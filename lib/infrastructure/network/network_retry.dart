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

  /// 为下一次尝试准备请求体，使其可以重新发送。
  ///
  /// Dio 的 [FormData] 是一次性的：首次发送时内容流被消费并置为 finalized，
  /// 之后复用同一个 [RequestOptions] 再发会抛
  /// 「Bad state: The FormData has already been finalized」。
  /// 登录等 POST 用的正是 FormData，所以缺了这一步，重试在这些请求上必然再次
  /// 失败——重试机制形同虚设。[FormData.clone] 会复刻 boundary 与全部字段/文件，
  /// 得到一份可重新发送的副本，官方注释即为此场景而加。
  static void prepareForRetry(RequestOptions options) {
    final data = options.data;
    if (data is FormData && data.isFinalized) {
      options.data = data.clone();
    }
  }
}
