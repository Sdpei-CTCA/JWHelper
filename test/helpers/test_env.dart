import 'dart:io';

import 'package:flutter/foundation.dart';

/// Loads credentials from project-root `env` for integration tests.
class TestEnv {
  static final Map<String, String> _vars = {};
  static bool _loaded = false;

  static const _placeholderValues = {
    'your_student_id',
    'your_password',
    '',
  };

  @visibleForTesting
  static void reset() {
    _vars.clear();
    _loaded = false;
  }

  static Future<void> load({String path = 'env'}) async {
    if (_loaded) return;

    final file = File(path);
    if (!await file.exists()) {
      _loaded = true;
      return;
    }

    final lines = await file.readAsLines();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final separatorIndex = trimmed.indexOf('=');
      if (separatorIndex <= 0) continue;

      final key = trimmed.substring(0, separatorIndex).trim();
      final value = trimmed.substring(separatorIndex + 1).trim();
      _vars[key] = value;
    }

    _loaded = true;
  }

  static String? get(String key) => _vars[key];

  static String get username => _vars['TEST_USERNAME'] ?? '';

  static String get password => _vars['TEST_PASSWORD'] ?? '';

  static bool get isConfigured {
    return !_placeholderValues.contains(username) &&
        !_placeholderValues.contains(password);
  }
}
