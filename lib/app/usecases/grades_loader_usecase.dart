import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static String _cacheKey(String username) => 'grades_cache_$username';
  static String _cacheTimeKey(String username) => 'grades_cache_time_$username';

  static Future<GradesLoadResult> execute({
    required GradesService service,
    required String username,
    required bool forceRefresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final int? lastTime = prefs.getInt(_cacheTimeKey(username));
      final String? cachedData = prefs.getString(_cacheKey(username));

      if (lastTime != null && cachedData != null) {
        final DateTime lastFetchTime = DateTime.fromMillisecondsSinceEpoch(lastTime);
        final DateTime now = DateTime.now();

        if (now.difference(lastFetchTime).inDays < 30) {
          final List<dynamic> decoded = jsonDecode(cachedData);
          final grades = decoded.map((e) => Grade.fromJson(e)).toList();
          return GradesLoadResult(grades: grades, loaded: true, evaluationRequired: false);
        }
      }
    }

    try {
      final grades = await service.getAllGrades();
      if (grades.isEmpty) {
        final cached = _loadCachedGrades(prefs, username);
        if (cached != null) {
          return GradesLoadResult(grades: cached, loaded: true, evaluationRequired: false);
        }
      }
      await _saveToCache(username: username, grades: grades);
      return GradesLoadResult(grades: grades, loaded: true, evaluationRequired: false);
    } catch (e) {
      if (e is EvaluationRequiredException ||
          (e is DioException && e.error is EvaluationRequiredException)) {
        final cached = _loadCachedGrades(prefs, username);
        if (cached != null) {
          return GradesLoadResult(grades: cached, loaded: true, evaluationRequired: false);
        }
        return const GradesLoadResult(grades: [], loaded: false, evaluationRequired: true);
      }

      debugPrint('Error loading grades: $e');
      try {
        final cached = _loadCachedGrades(prefs, username);
        if (cached != null) {
          return GradesLoadResult(grades: cached, loaded: true, evaluationRequired: false);
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
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(grades.map((g) => g.toJson()).toList());
      await prefs.setString(_cacheKey(username), encoded);
      await prefs.setInt(_cacheTimeKey(username), DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving grades cache: $e');
    }
  }

  static List<Grade>? _loadCachedGrades(SharedPreferences prefs, String username) {
    final String? cachedData = prefs.getString(_cacheKey(username));
    if (cachedData == null || cachedData.isEmpty) {
      return null;
    }
    final List<dynamic> decoded = jsonDecode(cachedData);
    return decoded.map((e) => Grade.fromJson(e)).toList();
  }
}
