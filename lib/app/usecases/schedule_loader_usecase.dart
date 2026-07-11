import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/app/domain/schedule_term_state.dart';
import 'package:JWHelper/app/usecases/cache_refresh_policy.dart';
import 'package:JWHelper/core/errors/exceptions.dart';
import 'package:JWHelper/features/schedule/data/schedule_service.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

class ScheduleLoadResult {
  final List<ScheduleItem> schedule;
  final String? startDay;
  final bool loaded;
  final bool evaluationRequired;
  final bool keptLocalCacheOnEmpty;

  const ScheduleLoadResult({
    required this.schedule,
    required this.startDay,
    required this.loaded,
    required this.evaluationRequired,
    this.keptLocalCacheOnEmpty = false,
  });
}

class ScheduleLoaderUsecase {
  static String _cacheKey(String username) => 'schedule_cache_$username';
  static String _cacheTimeKey(String username) =>
      'schedule_cache_time_$username';
  static String _startDayKey(String username) => 'schedule_start_day_$username';

  static Future<ScheduleLoadResult> execute({
    required ScheduleService service,
    required String username,
    required bool forceRefresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (CacheRefreshPolicy.shouldReadDiskCache(forceRefresh)) {
      final int? lastTime = prefs.getInt(_cacheTimeKey(username));
      final String? cachedData = prefs.getString(_cacheKey(username));
      final String? startDayStr = prefs.getString(_startDayKey(username));

      if (lastTime != null && cachedData != null) {
        final DateTime lastFetchTime =
            DateTime.fromMillisecondsSinceEpoch(lastTime);
        final DateTime now = DateTime.now();

        if (now.difference(lastFetchTime).inDays < 30) {
          final List<dynamic> decoded = jsonDecode(cachedData);
          final schedule =
              decoded.map((e) => ScheduleItem.fromJson(e)).toList();
          if (schedule.isEmpty) {
            await prefs.remove(_startDayKey(username));
            return const ScheduleLoadResult(
              schedule: [],
              startDay: null,
              loaded: true,
              evaluationRequired: false,
            );
          }
          return ScheduleLoadResult(
            schedule: schedule,
            startDay: startDayStr,
            loaded: true,
            evaluationRequired: false,
          );
        }
      }
    }

    try {
      final result = await service.getSchedule();
      final List<ScheduleItem> schedule = result['items'] as List<ScheduleItem>;
      final String? startDayStr = result['startDay'] as String?;

      if (schedule.isEmpty) {
        final cached = _loadCachedSchedule(prefs, username);
        final shouldKeepCache = forceRefresh
            ? cached != null && cached.$1.isNotEmpty
            : CacheRefreshPolicy.shouldFallbackOnEmpty(forceRefresh) &&
                cached != null;

        if (shouldKeepCache) {
          return ScheduleLoadResult(
            schedule: cached.$1,
            startDay: cached.$2,
            loaded: true,
            evaluationRequired: false,
            keptLocalCacheOnEmpty: forceRefresh,
          );
        }
      }

      await _saveToCache(
          username: username, schedule: schedule, startDay: startDayStr);
      return ScheduleLoadResult(
        schedule: schedule,
        startDay: startDayStr,
        loaded: true,
        evaluationRequired: false,
      );
    } catch (e) {
      if (e is EvaluationRequiredException ||
          (e is DioException && e.error is EvaluationRequiredException)) {
        final cached = _loadCachedSchedule(prefs, username);
        if (cached != null) {
          return ScheduleLoadResult(
            schedule: cached.$1,
            startDay: cached.$2,
            loaded: true,
            evaluationRequired: true,
          );
        }
        return const ScheduleLoadResult(
          schedule: [],
          startDay: null,
          loaded: false,
          evaluationRequired: true,
        );
      }

      debugPrint('Error loading schedule: $e');
      try {
        final cached = _loadCachedSchedule(prefs, username);
        if (cached != null) {
          return ScheduleLoadResult(
            schedule: cached.$1,
            startDay: cached.$2,
            loaded: true,
            evaluationRequired: false,
          );
        }
      } catch (cacheError) {
        debugPrint('Error loading stale schedule cache: $cacheError');
      }

      rethrow;
    }
  }

  static Future<void> _saveToCache({
    required String username,
    required List<ScheduleItem> schedule,
    required String? startDay,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded =
          jsonEncode(schedule.map((s) => s.toJson()).toList());
      await prefs.setString(_cacheKey(username), encoded);
      await prefs.setInt(
          _cacheTimeKey(username), DateTime.now().millisecondsSinceEpoch);
      if (schedule.isEmpty ||
          ScheduleTermState.isTermUnavailable(
            schedule: schedule,
            startDay: startDay,
          )) {
        await prefs.remove(_startDayKey(username));
      } else if (startDay != null) {
        await prefs.setString(_startDayKey(username), startDay);
      }
    } catch (e) {
      debugPrint('Error saving schedule cache: $e');
    }
  }

  static (List<ScheduleItem>, String?)? _loadCachedSchedule(
    SharedPreferences prefs,
    String username,
  ) {
    final String? cachedData = prefs.getString(_cacheKey(username));
    final String? startDayStr = prefs.getString(_startDayKey(username));
    if (cachedData == null || cachedData.isEmpty) {
      return null;
    }
    final List<dynamic> decoded = jsonDecode(cachedData);
    final schedule = decoded.map((e) => ScheduleItem.fromJson(e)).toList();
    if (schedule.isEmpty) {
      return null;
    }
    return (schedule, startDayStr);
  }
}
