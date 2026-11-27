import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/app/cache/offline_cache_keys.dart';
import 'package:JWHelper/app/usecases/cache_refresh_policy.dart';
import 'package:JWHelper/features/progress/data/progress_service.dart';
import 'package:JWHelper/features/progress/domain/progress_item.dart';

class ProgressLoadResult {
  final List<ProgressGroup> groups;
  final List<ProgressInfo> info;
  final bool loaded;

  const ProgressLoadResult({
    required this.groups,
    required this.info,
    required this.loaded,
  });
}

class ProgressLoaderUsecase {
  static String cacheKey(String username) =>
      OfflineCacheKeys.progress(username);
  static String cacheTimeKey(String username) =>
      OfflineCacheKeys.progressTime(username);

  /// 仅读取有效期内磁盘缓存（不触网），供启动首帧预热使用。
  static Future<(List<ProgressGroup>, List<ProgressInfo>)?> readCacheOnly(
    String username,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    return _readFreshCache(prefs, username);
  }

  static (List<ProgressGroup>, List<ProgressInfo>)? _readFreshCache(
    SharedPreferences prefs,
    String username,
  ) {
    final int? lastTime = prefs.getInt(cacheTimeKey(username));
    if (lastTime == null) return null;
    final lastFetchTime = DateTime.fromMillisecondsSinceEpoch(lastTime);
    if (DateTime.now().difference(lastFetchTime).inDays >= 30) return null;
    return _loadCachedProgress(prefs, username);
  }

  static Future<ProgressLoadResult> execute({
    required ProgressService service,
    required String username,
    required bool forceRefresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (CacheRefreshPolicy.shouldReadDiskCache(forceRefresh)) {
      final cached = _readFreshCache(prefs, username);
      if (cached != null) {
        return ProgressLoadResult(
            groups: cached.$1, info: cached.$2, loaded: true);
      }
    }

    try {
      final data = await service.getProgressData();
      final groups = data['groups'] ?? <ProgressGroup>[];
      final info = data['info'] ?? <ProgressInfo>[];

      if (groups.isEmpty &&
          info.isEmpty &&
          CacheRefreshPolicy.shouldFallbackOnEmpty(forceRefresh)) {
        final cached = _loadCachedProgress(prefs, username);
        if (cached != null) {
          return ProgressLoadResult(
              groups: cached.$1, info: cached.$2, loaded: true);
        }
      }

      await saveToCache(
        username: username,
        groups: groups,
        info: info,
        prefs: prefs,
      );
      return ProgressLoadResult(groups: groups, info: info, loaded: true);
    } catch (e) {
      debugPrint('Error loading progress: $e');
      try {
        final cached = _loadCachedProgress(prefs, username);
        if (cached != null) {
          return ProgressLoadResult(
              groups: cached.$1, info: cached.$2, loaded: true);
        }
      } catch (cacheError) {
        debugPrint('Error loading stale progress cache: $cacheError');
      }

      rethrow;
    }
  }

  static Future<void> saveToCache({
    required String username,
    required List<ProgressGroup> groups,
    required List<ProgressInfo> info,
    SharedPreferences? prefs,
  }) async {
    try {
      final store = prefs ?? await SharedPreferences.getInstance();
      final Map<String, dynamic> data = {
        'groups': groups.map((g) => g.toJson()).toList(),
        'info': info.map((i) => i.toJson()).toList(),
      };
      final String encoded = jsonEncode(data);
      await Future.wait([
        store.setString(cacheKey(username), encoded),
        store.setInt(
            cacheTimeKey(username), DateTime.now().millisecondsSinceEpoch),
      ]);
    } catch (e) {
      debugPrint('Error saving progress cache: $e');
    }
  }

  static (List<ProgressGroup>, List<ProgressInfo>)? _loadCachedProgress(
    SharedPreferences prefs,
    String username,
  ) {
    final String? cachedData = prefs.getString(cacheKey(username));
    if (cachedData == null || cachedData.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(cachedData);
      if (decoded is! Map) return null;
      final groups = (decoded['groups'] as List)
          .whereType<Map>()
          .map((e) => ProgressGroup.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final info = (decoded['info'] as List)
          .whereType<Map>()
          .map((e) => ProgressInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return (groups, info);
    } catch (e) {
      debugPrint('Error decoding progress cache: $e');
      return null;
    }
  }
}
