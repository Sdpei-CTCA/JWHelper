import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Enables legacy TLS renegotiation for older servers such as jw.sdpei.edu.cn.
void configurePlatformHttpClient(Dio dio) {
  final context = SecurityContext.defaultContext;
  context.allowLegacyUnsafeRenegotiation = true;

  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient(context: context);
      client.idleTimeout = const Duration(seconds: 15);
      return client;
    },
  );
}
