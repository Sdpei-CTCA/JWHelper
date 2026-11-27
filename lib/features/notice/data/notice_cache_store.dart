import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/features/notice/domain/notice_item.dart';

/// 通知模块的本地存储：列表缓存、已读/已见集合、提醒开关与节流时间。
///
/// 全部按账号（智慧山体学号）分键：换账号后不会看到上一个人的已读状态。
class NoticeCacheStore {
  static const String _listPrefix = 'notice_list_v1';
  static const String _readPrefix = 'notice_read_v1';
  static const String _knownPrefix = 'notice_known_v1';
  static const String _reminderEnabledKey = 'notice_reminder_enabled';
  static const String _lastNotifyDayKey = 'notice_last_notify_day';
  static const String _lastCheckAtKey = 'notice_last_check_at';

  String _suffix(String username) =>
      username.trim().isEmpty ? 'anonymous' : username.trim();

  String listKey(String username) => '${_listPrefix}_${_suffix(username)}';
  String readKey(String username) => '${_readPrefix}_${_suffix(username)}';
  String knownKey(String username) => '${_knownPrefix}_${_suffix(username)}';

  Future<void> saveList(String username, List<NoticeItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(listKey(username), payload);
  }

  Future<List<NoticeItem>> readList(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(listKey(username));
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final items = <NoticeItem>[];
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          final item = NoticeItem.fromJson(entry);
          if (item != null) items.add(item);
        } else if (entry is Map) {
          final item = NoticeItem.fromJson(Map<String, dynamic>.from(entry));
          if (item != null) items.add(item);
        }
      }
      return items;
    } catch (_) {
      return const [];
    }
  }

  Future<Set<String>> readReadIds(String username) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(readKey(username)) ?? const []).toSet();
  }

  Future<void> saveReadIds(String username, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(readKey(username), ids.toList());
  }

  Future<Set<String>> readKnownIds(String username) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(knownKey(username)) ?? const []).toSet();
  }

  Future<void> saveKnownIds(String username, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(knownKey(username), ids.toList());
  }

  Future<bool> readReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_reminderEnabledKey) ?? true;
  }

  Future<void> saveReminderEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reminderEnabledKey, value);
  }

  Future<DateTime?> readLastCheckAt() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_lastCheckAtKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> saveLastCheckAt(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCheckAtKey, time.millisecondsSinceEpoch);
  }

  /// 上次弹出新通知提醒的日期（`yyyy-MM-dd`），用于「一天最多提醒一次」。
  Future<String?> readLastNotifyDay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastNotifyDayKey);
  }

  Future<void> saveLastNotifyDay(String day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastNotifyDayKey, day);
  }

  Future<void> clearReadState(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(readKey(username));
  }
}
