import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/app/cache/offline_cache_keys.dart';
import 'package:JWHelper/app/usecases/cache_refresh_policy.dart';
import 'package:JWHelper/core/errors/exceptions.dart';
import 'package:JWHelper/features/grades/data/grades_service.dart';
import 'package:JWHelper/features/grades/domain/grade.dart';

class GradesLoadResult {
  final List<Grade> grades;
  final bool loaded;
  final bool evaluationRequired;

  const GradesLoadResult({
    required this.grades,
    required this.loaded,
    required this.evaluationRequired,
  });
}

class GradesLoaderUsecase {
  static String _cacheKey(String username) => OfflineCacheKeys.grades(username);
  static String _cacheTimeKey(String username) =>
      OfflineCacheKeys.gradesTime(username);

  /// 仅读取有效期内磁盘缓存（不触网），供启动首帧预热使用。
  static Future<List<Grade>?> readCacheOnly(String username) async {
    final prefs = await SharedPreferences.getInstance();
    return _readFreshCache(prefs, username);
  }

  static List<Grade>? _readFreshCache(SharedPreferences prefs, String username) {
    final int? lastTime = prefs.getInt(_cacheTimeKey(username));
    if (lastTime == null) return null;
    final lastFetchTime = DateTime.fromMillisecondsSinceEpoch(lastTime);
    if (DateTime.now().difference(lastFetchTime).inDays >= 30) return null;
    return _loadCachedGrades(prefs, username);
  }

  static Future<GradesLoadResult> execute({
    required GradesService service,
    required String username,
    required bool forceRefresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (CacheRefreshPolicy.shouldReadDiskCache(forceRefresh)) {
      final cached = _readFreshCache(prefs, username);
      if (cached != null) {
        return GradesLoadResult(
            grades: cached, loaded: true, evaluationRequired: false);
      }
    }

    try {
      final grades = await service.getAllGrades();
      if (grades.isEmpty &&
          CacheRefreshPolicy.shouldFallbackOnEmpty(forceRefresh)) {
        final cached = _loadCachedGrades(prefs, username);
        if (cached != null) {
          return GradesLoadResult(
              grades: cached, loaded: true, evaluationRequired: false);
        }
      }
      await _saveToCache(username: username, grades: grades, prefs: prefs);
      return GradesLoadResult(
          grades: grades, loaded: true, evaluationRequired: false);
    } catch (e) {
      if (e is EvaluationRequiredException ||
          (e is DioException && e.error is EvaluationRequiredException)) {
        final cached = _loadCachedGrades(prefs, username);
        if (cached != null) {
          return GradesLoadResult(
              grades: cached, loaded: true, evaluationRequired: true);
        }
        return const GradesLoadResult(
            grades: [], loaded: false, evaluationRequired: true);
      }

      debugPrint('Error loading grades: $e');
      try {
        final cached = _loadCachedGrades(prefs, username);
        if (cached != null) {
          return GradesLoadResult(
              grades: cached, loaded: true, evaluationRequired: false);
        }
      } catch (cacheError) {
        debugPrint('Error loading stale grades cache: $cacheError');
      }

      rethrow;
    }
  }

  static Future<void> _saveToCache({
    required String username,
    required List<Grade> grades,
    SharedPreferences? prefs,
  }) async {
    try {
      final store = prefs ?? await SharedPreferences.getInstance();
      final String encoded = jsonEncode(grades.map((g) => g.toJson()).toList());
      await Future.wait([
        store.setString(_cacheKey(username), encoded),
        store.setInt(
            _cacheTimeKey(username), DateTime.now().millisecondsSinceEpoch),
      ]);
    } catch (e) {
      debugPrint('Error saving grades cache: $e');
    }
  }

  static List<Grade>? _loadCachedGrades(
      SharedPreferences prefs, String username) {
    final String? cachedData = prefs.getString(_cacheKey(username));
    if (cachedData == null || cachedData.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(cachedData);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((e) => Grade.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Error decoding grades cache: $e');
      return null;
    }
  }
}
