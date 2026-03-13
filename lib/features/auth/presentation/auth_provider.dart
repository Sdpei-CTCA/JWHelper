import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/features/auth/data/auth_service.dart';
import 'package:JWHelper/infrastructure/network/client.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  static const String _securePasswordKey = 'auth_saved_password';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  bool _isLoggedIn = false;
  bool _isLoading = false;
  Uint8List? _captchaImage;
  bool _needCaptcha = false;
  
  bool _rememberPassword = false;
  bool _autoLogin = false;
  String _savedUsername = "";
  String _currentUsername = "";
  bool _isOfflineMode = false;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  Uint8List? get captchaImage => _captchaImage;
  bool get needCaptcha => _needCaptcha;
  bool get rememberPassword => _rememberPassword;
  bool get autoLogin => _autoLogin;
  String get savedUsername => _savedUsername;
  String get currentUsername => _currentUsername;
  bool get isOfflineMode => _isOfflineMode;

  Future<String?> init() async {
    await ApiClient().init();
    await _loadPreferences();
    if (_autoLogin && _savedUsername.isNotEmpty) {
      var autoLoginPassword = await getSavedPasswordForPrefill();
      if (autoLoginPassword.isNotEmpty) {
        final loginError = await login(_savedUsername, autoLoginPassword);
        autoLoginPassword = "";
        return loginError;
      }
    }
    return null;
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _rememberPassword = prefs.getBool('remember_password') ?? false;
    _autoLogin = prefs.getBool('auto_login') ?? false;
    if (_rememberPassword) {
      _savedUsername = prefs.getString('username') ?? "";
    }
    notifyListeners();
  }

  void setRememberPassword(bool value) {
    _rememberPassword = value;
    if (!value) {
      _autoLogin = false;
    }
    notifyListeners();
  }

  void setAutoLogin(bool value) {
    _autoLogin = value;
    if (value) {
      _rememberPassword = true;
    }
    notifyListeners();
  }

  Future<void> checkLoginStatus() async {
    // Kept for compatibility, but logic moved to init()
  }

  Future<void> loadCaptcha() async {
    _captchaImage = await _authService.getCaptchaImage();
    notifyListeners();
  }

  Future<String?> login(String username, String password, {String verifyCode = ""}) async {
    _isLoading = true;
    notifyListeners();

    // Ensure client is initialized
    await ApiClient().init();

    // Check for maintenance time (00:00 - 06:00)
    final now = DateTime.now();
    if (now.hour >= 0 && now.hour < 6) {
      if (await _matchesRememberedCredentials(username, password)) {
        final hasCache = await _hasOfflineCache(username);
        if (!hasCache) {
          _isLoading = false;
          notifyListeners();
          return "当前为维护时段，且未检测到本地离线缓存，请联网成功登录一次后再使用离线模式";
        }
        _isLoggedIn = true;
        _needCaptcha = false;
        _currentUsername = username;
        _isOfflineMode = true;
        _isLoading = false;
        notifyListeners();
        return null; // Automatically enter offline mode
      }
    }

    var result = await _authService.login(username, password, verifyCode: verifyCode);
    
    _isLoading = false;
    if (result['success']) {
      _isLoggedIn = true;
      _needCaptcha = false;
      _currentUsername = username;
      _isOfflineMode = false;
      
      // Save preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_password', _rememberPassword);
      await prefs.setBool('auto_login', _autoLogin);
      if (_rememberPassword) {
        await prefs.setString('username', username);
        await _secureStorage.write(key: _securePasswordKey, value: password);
        await prefs.remove('password');
        _savedUsername = username;
      } else {
        await prefs.remove('username');
        await prefs.remove('password');
        await _secureStorage.delete(key: _securePasswordKey);
        _savedUsername = "";
      }

      notifyListeners();
      return null; // No error
    } else {
      // Check for offline login possibility
      String msg = result['message'].toString();
      if (_canUseOfflineFallback(msg, result)) {
        if (await _matchesRememberedCredentials(username, password)) {
          final hasCache = await _hasOfflineCache(username);
          if (!hasCache) {
            notifyListeners();
            return "当前无法从教务系统获取有效数据，且未检测到本地离线缓存，请联网成功登录一次后再试";
          }
          _isLoggedIn = true;
          _needCaptcha = false;
          _currentUsername = username;
          _isOfflineMode = true;
          notifyListeners();
          return null; // Treat as success
        }
      }

      if (result['needCaptcha'] == true) {
        _needCaptcha = true;
        await loadCaptcha();
      }
      notifyListeners();
      return result['message'];
    }
  }

  Future<void> logout() async {
    await ApiClient().clearCookies();
    _isLoggedIn = false;
    _needCaptcha = false;
    _isOfflineMode = false;
    
    // Cancel auto login and clear saved password
    _autoLogin = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_login', false);
    await prefs.remove('password');
    await _secureStorage.delete(key: _securePasswordKey);
    
    notifyListeners();
  }

  Future<String> getSavedPasswordForPrefill() async {
    if (!_rememberPassword) {
      return "";
    }
    final prefs = await SharedPreferences.getInstance();
    return _loadSavedPassword(prefs);
  }

  Future<String> _loadSavedPassword(SharedPreferences prefs) async {
    final secureValue = await _secureStorage.read(key: _securePasswordKey);
    if (secureValue != null && secureValue.isNotEmpty) {
      return secureValue;
    }

    final legacyPassword = prefs.getString('password') ?? "";
    if (legacyPassword.isNotEmpty) {
      await _secureStorage.write(key: _securePasswordKey, value: legacyPassword);
      await prefs.remove('password');
      return legacyPassword;
    }

    return "";
  }

  Future<bool> _hasOfflineCache(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final fixedKeys = <String>[
      'grades_cache_$username',
      'schedule_cache_$username',
      'progress_cache_$username',
      'exam_semesters_$username',
    ];

    for (final key in fixedKeys) {
      final value = prefs.getString(key);
      if (value != null && value.isNotEmpty) {
        return true;
      }
    }

    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      if ((key.startsWith('exams_') || key.startsWith('exam_rounds_')) && key.endsWith('_$username')) {
        final value = prefs.getString(key);
        if (value != null && value.isNotEmpty) {
          return true;
        }
      }
    }

    return false;
  }

  Future<bool> _matchesRememberedCredentials(String username, String password) async {
    if (!_rememberPassword || _savedUsername != username) {
      return false;
    }
    var savedPassword = await getSavedPasswordForPrefill();
    final matched = savedPassword.isNotEmpty && savedPassword == password;
    savedPassword = "";
    return matched;
  }

  bool _canUseOfflineFallback(String message, Map<String, dynamic> result) {
    if (result['needCaptcha'] == true) {
      return false;
    }

    const knownUnavailableKeywords = <String>[
      '网络错误',
      'SocketException',
      'DioException',
      '超时',
      'timeout',
      '教学评价',
      '缴费',
      '维护',
      '系统繁忙',
      '服务不可用',
      '暂不可用',
    ];

    for (final keyword in knownUnavailableKeywords) {
      if (message.contains(keyword)) {
        return true;
      }
    }

    return false;
  }
}
