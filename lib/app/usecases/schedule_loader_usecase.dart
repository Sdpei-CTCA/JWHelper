import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/app/cache/offline_cache_keys.dart';
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

  /// 课表处于本地自定义模式（未联网，直接读取本地课表）。
  final bool localMode;

  const ScheduleLoadResult({
    required this.schedule,
    required this.startDay,
    required this.loaded,
    required this.evaluationRequired,
    this.keptLocalCacheOnEmpty = false,
    this.localMode = false,
  });
}

/// 从教务恢复课表失败（本地自定义课表保持不变）。
class ScheduleRestoreException implements Exception {
  final String message;
  const ScheduleRestoreException(this.message);

  @override
  String toString() => message;
}

class ScheduleLoaderUsecase {
  static String _cacheKey(String username) =>
      OfflineCacheKeys.schedule(username);
  static String _cacheTimeKey(String username) =>
      OfflineCacheKeys.scheduleTime(username);
  static String _startDayKey(String username) =>
      OfflineCacheKeys.scheduleStartDay(username);
  static String _localModeKey(String username) =>
      OfflineCacheKeys.scheduleLocalMode(username);

  static Future<bool> isLocalMode(String username) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_localModeKey(username)) ?? false;
  }

  /// 仅读取本地磁盘缓存（不触网），供首帧冷启动快速展示。
  static Future<ScheduleLoadResult?> readCacheOnly(String username) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_localModeKey(username)) ?? false) {
      final schedule = _decodeScheduleList(prefs.getString(_cacheKey(username)));
      return ScheduleLoadResult(
        schedule: schedule ?? const [],
        startDay: prefs.getString(_startDayKey(username)),
        loaded: true,
        evaluationRequired: false,
        localMode: true,
      );
    }

    final int? lastTime = prefs.getInt(_cacheTimeKey(username));
    final String? cachedData = prefs.getString(_cacheKey(username));
    final String? startDayStr = prefs.getString(_startDayKey(username));
    if (lastTime == null || cachedData == null) return null;

    final lastFetchTime = DateTime.fromMillisecondsSinceEpoch(lastTime);
    if (DateTime.now().difference(lastFetchTime).inDays >= 30) return null;

    final schedule = _decodeScheduleList(cachedData);
    if (schedule == null) return null;
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

  /// 保存用户编辑后的课表，并进入本地模式（不再自动与教务同步）。
  static Future<void> saveLocalSchedule({
    required String username,
    required List<ScheduleItem> schedule,
    required String? startDay,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(
        _cacheKey(username),
        jsonEncode(schedule.map((s) => s.toJson()).toList()),
      ),
      prefs.setInt(
          _cacheTimeKey(username), DateTime.now().millisecondsSinceEpoch),
      if (startDay != null && startDay.trim().isNotEmpty)
        prefs.setString(_startDayKey(username), startDay),
      prefs.setBool(_localModeKey(username), true),
    ]);
  }

  /// 从教务重新拉取课表并覆盖本地自定义课表。
  ///
  /// 失败时抛出 [ScheduleRestoreException] / [EvaluationRequiredException]，
  /// 且不会改动本地数据。
  static Future<ScheduleLoadResult> restoreFromServer({
    required ScheduleService service,
    required String username,
  }) async {
    final Map<String, dynamic> result;
    try {
      result = await service.getSchedule();
    } catch (e) {
      if (e is EvaluationRequiredException ||
          (e is DioException && e.error is EvaluationRequiredException)) {
        throw EvaluationRequiredException();
      }
      debugPrint('Restore schedule failed: $e');
      throw const ScheduleRestoreException('网络异常，恢复失败，已保留当前课表');
    }
    final List<ScheduleItem> schedule = result['items'] as List<ScheduleItem>;
    final String? startDayStr = result['startDay'] as String?;
    if (schedule.isEmpty) {
      throw const ScheduleRestoreException('教务未返回课表数据，已保留当前课表');
    }
    await _saveToCache(
        username: username, schedule: schedule, startDay: startDayStr);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localModeKey(username));
    return ScheduleLoadResult(
      schedule: schedule,
      startDay: startDayStr,
      loaded: true,
      evaluationRequired: false,
    );
  }

  static Future<ScheduleLoadResult> execute({
    required ScheduleService service,
    required String username,
    required bool forceRefresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 本地自定义模式：只读本地课表，不联网，也不受 30 天缓存过期限制。
    if (prefs.getBool(_localModeKey(username)) ?? false) {
      final schedule =
          _decodeScheduleList(prefs.getString(_cacheKey(username))) ?? const [];
      return ScheduleLoadResult(
        schedule: schedule,
        startDay: prefs.getString(_startDayKey(username)),
        loaded: true,
        evaluationRequired: false,
        localMode: true,
      );
    }
    if (CacheRefreshPolicy.shouldReadDiskCache(forceRefresh)) {
      final int? lastTime = prefs.getInt(_cacheTimeKey(username));
      final String? cachedData = prefs.getString(_cacheKey(username));
      final String? startDayStr = prefs.getString(_startDayKey(username));

      if (lastTime != null && cachedData != null) {
        final DateTime lastFetchTime =
            DateTime.fromMillisecondsSinceEpoch(lastTime);
        final DateTime now = DateTime.now();

        if (now.difference(lastFetchTime).inDays < 30) {
          final schedule = _decodeScheduleList(cachedData);
          if (schedule != null) {
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

  static List<ScheduleItem>? _decodeScheduleList(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((e) => ScheduleItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Error decoding schedule cache: $e');
      return null;
    }
  }

  static (List<ScheduleItem>, String?)? _loadCachedSchedule(
    SharedPreferences prefs,
    String username,
  ) {
    final schedule = _decodeScheduleList(prefs.getString(_cacheKey(username)));
    if (schedule == null || schedule.isEmpty) {
      return null;
    }
    return (schedule, prefs.getString(_startDayKey(username)));
  }
}
