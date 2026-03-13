import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static String cacheKey(String username) => 'progress_cache_$username';
  static String cacheTimeKey(String username) => 'progress_cache_time_$username';

  static Future<ProgressLoadResult> execute({
    required ProgressService service,
    required String username,
    required bool forceRefresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final int? lastTime = prefs.getInt(cacheTimeKey(username));
      final String? cachedData = prefs.getString(cacheKey(username));

      if (lastTime != null && cachedData != null) {
        final DateTime lastFetchTime = DateTime.fromMillisecondsSinceEpoch(lastTime);
        final DateTime now = DateTime.now();

        if (now.difference(lastFetchTime).inDays < 30) {
          final Map<String, dynamic> decoded = jsonDecode(cachedData);
          final groups = (decoded['groups'] as List).map((e) => ProgressGroup.fromJson(e)).toList();
          final info = (decoded['info'] as List).map((e) => ProgressInfo.fromJson(e)).toList();
          return ProgressLoadResult(groups: groups, info: info, loaded: true);
        }
      }
    }

    try {
      final data = await service.getProgressData();
      final groups = data['groups'] ?? <ProgressGroup>[];
      final info = data['info'] ?? <ProgressInfo>[];

      if (groups.isEmpty && info.isEmpty) {
        final cached = _loadCachedProgress(prefs, username);
        if (cached != null) {
          return ProgressLoadResult(groups: cached.$1, info: cached.$2, loaded: true);
        }
      }

      await saveToCache(username: username, groups: groups, info: info);
      return ProgressLoadResult(groups: groups, info: info, loaded: true);
    } catch (e) {
      debugPrint('Error loading progress: $e');
      try {
        final cached = _loadCachedProgress(prefs, username);
        if (cached != null) {
          return ProgressLoadResult(groups: cached.$1, info: cached.$2, loaded: true);
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
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> data = {
        'groups': groups.map((g) => g.toJson()).toList(),
        'info': info.map((i) => i.toJson()).toList(),
      };
      final String encoded = jsonEncode(data);
      await prefs.setString(cacheKey(username), encoded);
      await prefs.setInt(cacheTimeKey(username), DateTime.now().millisecondsSinceEpoch);
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
    final Map<String, dynamic> decoded = jsonDecode(cachedData);
    final groups = (decoded['groups'] as List).map((e) => ProgressGroup.fromJson(e)).toList();
    final info = (decoded['info'] as List).map((e) => ProgressInfo.fromJson(e)).toList();
    return (groups, info);
  }
}
