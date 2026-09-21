import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 智慧考勤的 SSO 令牌缓存。
class AttendanceSsoTokens {
  final String userToken;
  final String ctTicket;
  final String appCtTicket;

  const AttendanceSsoTokens({
    this.userToken = '',
    this.ctTicket = '',
    this.appCtTicket = '',
  });

  bool get isEmpty => userToken.isEmpty;
}

/// 智慧考勤账号（智慧山体统一认证学号/密码）与令牌的本地持久化。
///
/// 密码与三个登录令牌都属于凭据：密码、`userToken` 存加密存储
/// （Android 走 Keystore 支撑的 EncryptedSharedPreferences，iOS 走 Keychain），
/// 只有学号这类非敏感信息留在 SharedPreferences。
/// 账号与教务系统登录相互独立，因此退出登录不会清除这里的凭据。
class AttendanceCredentialStore {
  static const String usernameKey = 'attendance_sso_username';
  static const String _securePasswordKey = 'attendance_sso_password';
  static const String _userTokenKey = 'attendance_sso_user_token';
  static const String _ctTicketKey = 'attendance_sso_ctticket';
  static const String _appCtTicketKey = 'attendance_sso_appctticket';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<String> readUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(usernameKey) ?? '';
  }

  static Future<String> readPassword() async {
    final value = await _secureStorage.read(key: _securePasswordKey);
    return value ?? '';
  }

  static Future<bool> hasCredentials() async {
    final username = await readUsername();
    if (username.isEmpty) {
      return false;
    }
    return (await readPassword()).isNotEmpty;
  }

  static Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(usernameKey, username);
    await _secureStorage.write(key: _securePasswordKey, value: password);
  }

  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(usernameKey);
    await _secureStorage.delete(key: _securePasswordKey);
    await clearTokens();
  }

  static Future<AttendanceSsoTokens> readTokens() async {
    // 早期版本把令牌明文存在 SharedPreferences 里，这里顺带迁移到加密存储。
    await _migrateLegacyTokens();

    return AttendanceSsoTokens(
      userToken: await _readSecure(_userTokenKey),
      ctTicket: await _readSecure(_ctTicketKey),
      appCtTicket: await _readSecure(_appCtTicketKey),
    );
  }

  static Future<void> saveTokens(AttendanceSsoTokens tokens) async {
    await _secureStorage.write(key: _userTokenKey, value: tokens.userToken);
    await _secureStorage.write(key: _ctTicketKey, value: tokens.ctTicket);
    await _secureStorage.write(key: _appCtTicketKey, value: tokens.appCtTicket);
  }

  static Future<void> clearTokens() async {
    await _secureStorage.delete(key: _userTokenKey);
    await _secureStorage.delete(key: _ctTicketKey);
    await _secureStorage.delete(key: _appCtTicketKey);
  }

  static Future<String> _readSecure(String key) async {
    final value = await _secureStorage.read(key: key);
    return value ?? '';
  }

  /// 把历史版本留在 SharedPreferences 中的明文令牌搬进加密存储并删除明文。
  static Future<void> _migrateLegacyTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyKeys = <String>[_userTokenKey, _ctTicketKey, _appCtTicketKey];
    final legacyValues = <String, String>{};

    for (final key in legacyKeys) {
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) {
        legacyValues[key] = value;
      }
    }

    if (legacyValues.isEmpty) {
      return;
    }

    for (final entry in legacyValues.entries) {
      // 已有加密值时不覆盖（加密存储才是权威来源）。
      final existing = await _readSecure(entry.key);
      if (existing.isEmpty) {
        await _secureStorage.write(key: entry.key, value: entry.value);
      }
      await prefs.remove(entry.key);
    }
  }
}
