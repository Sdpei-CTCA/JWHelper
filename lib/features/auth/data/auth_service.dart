import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:JWHelper/core/constants/config.dart';
import 'package:JWHelper/infrastructure/network/client.dart';

class AuthService {
  final ApiClient _client = ApiClient();

  /// Parses raw [LoginHandler.ashx] DoLogin response body.
  @visibleForTesting
  static Map<String, dynamic> parseLoginResponse(String raw) {
    final result = raw.trim();

    if (result == "true") {
      return {"success": true, "message": "登录成功"};
    }
    if (result.contains("wrongVerifyCode")) {
      return {"success": false, "needCaptcha": true, "message": "验证码错误"};
    }
    if (result.contains("verifyCodeTimeOut")) {
      return {"success": false, "needCaptcha": true, "message": "验证码已过期"};
    }
    // First wrong password: "BS_LOGIN_STATE_InputError,showVC".
    // The trailing showVC is server state, not a request to display captcha yet.
    if (result.contains("BS_LOGIN_STATE_InputError")) {
      return {"success": false, "message": "密码错误"};
    }
    return {"success": false, "message": "登录失败: $result"};
  }

  Future<Uint8List?> getCaptchaImage() async {
    await _client.init();
    try {
      String url =
          "${Config.baseUrl}/LoginHandler.ashx?createvc=true&random=${DateTime.now().millisecondsSinceEpoch}";
      Response response = await _client.dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data);
    } catch (e) {
      debugPrint("Get captcha failed: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>> login(String username, String password,
      {String verifyCode = ""}) async {
    await _client.init();

    // 教务系统会把输错密码次数记在 Cookie 里；带旧 Cookie 登录会立刻要求验证码。
    // 首次尝试（未填验证码）时清空 Cookie，模拟浏览器无痕会话。
    if (verifyCode.isEmpty) {
      await _client.clearCookies();
    }

    String userIdEncoded = base64.encode(utf8.encode(username));
    String userPwdEncoded = base64.encode(utf8.encode(password));

    FormData formData = FormData.fromMap({
      "method": "DoLogin",
      "userId": userIdEncoded,
      "userPwd": userPwdEncoded,
      "verifyCode": verifyCode,
    });

    try {
      Response response =
          await _client.dio.post(Config.loginUrl, data: formData);
      return parseLoginResponse(response.data.toString());
    } catch (e) {
      return {"success": false, "message": "网络错误: $e"};
    }
  }
}
