import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:JWHelper/core/constants/config.dart';
import 'package:JWHelper/core/errors/exceptions.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late Dio dio;
  late CookieJar cookieJar;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: Config.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        "User-Agent": Config.userAgent,
        if (!kIsWeb) "Referer": "${Config.baseUrl}/Login.aspx",
      },
      responseType: ResponseType.plain, // We handle HTML parsing manually
      validateStatus: (status) => status != null && status < 500,
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint("--> [${options.method}] ${options.uri}");
        return handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint("<-- [${response.statusCode}] ${response.requestOptions.uri}");
        // Detect evaluation requirement
        // If the request was NOT for evaluation, but we ended up there or got its content
        final isEvalRequest =
            response.requestOptions.path.contains("TeachingEvaluation");

        if (!isEvalRequest) {
          bool redirected = response.realUri
              .toString()
              .contains("TeachingEvaluation/TeachingEvaluation.aspx");
          // Check content for specific markers if not redirected via headers but returned 200 with HTML
          // Usually look for unique form ID or title
          bool contentMatch = response.data is String &&
              (response.data as String).contains(
                  "/Student/TeachingEvaluation/EvaluationAnswerHandler.ashx");

          if (redirected || contentMatch) {
            return handler.reject(DioException(
                requestOptions: response.requestOptions,
                error: EvaluationRequiredException(),
                type: DioExceptionType.unknown,
                response: response));
          }
        }
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        debugPrint("<-- Error: ${e.message} at ${e.requestOptions.uri}");
        // Here we could handle global error states (e.g., token expiration, connectivity)
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          debugPrint("Network timeout: ${e.message}");
        }
        return handler.next(e);
      }
    ));
  }

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Default to in-memory cookies
    cookieJar = CookieJar();

    if (!kIsWeb) {
      try {
        // Try to use persistent cookies on mobile/desktop
        Directory appDocDir = await getApplicationDocumentsDirectory();
        String appDocPath = appDocDir.path;
        cookieJar =
            PersistCookieJar(storage: FileStorage("$appDocPath/.cookies/"));
      } catch (e) {
        // Ignore errors (like MissingPluginException) and keep using in-memory cookies
        debugPrint("Cookie persistence initialization failed: $e");
      }

      // Only add CookieManager on non-web platforms
      // On Web, browsers handle cookies automatically (and CookieManager can cause issues)
      dio.interceptors.add(CookieManager(cookieJar));
    } else {
      // On Web, we might need to enable withCredentials for CORS if needed
      // But we can't easily access BrowserHttpClientAdapter here without conditional imports.
      // Assuming the browser/proxy handles it or the user is running in a same-origin environment.
    }

    _initialized = true;
  }

  Future<void> clearCookies() async {
    await cookieJar.deleteAll();
  }
}
