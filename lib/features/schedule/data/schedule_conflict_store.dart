import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ScheduleConflictStore {
  static const _prefsKey = 'grid_schedule_conflict_primary';

  static Future<Map<String, String>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> savePrimary({
    required String groupKey,
    required String itemKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadAll();
    current[groupKey] = itemKey;
    await prefs.setString(_prefsKey, jsonEncode(current));
  }
}
