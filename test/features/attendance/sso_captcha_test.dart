import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/features/attendance/data/sso_token_service.dart';

/// 验证码协议按真实抓到的响应体固定下来（见 2026-09 实测）：
/// `{"code":"0x000000","msg":"成功","data":{"base64":"data:image/png;base64,…","captchaId":"…"}}`
void main() {
  group('SsoTokenService.parseCaptchaResponse', () {
    // 1x1 透明 PNG，够用来验证解码。
    const pngBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8AAAwAB/AL+2wAAAABJRU5ErkJggg==';

    test('解析带 data URI 前缀的响应', () {
      final body = jsonEncode({
        'code': '0x000000',
        'msg': '成功',
        'data': {'base64': 'data:image/png;base64,$pngBase64', 'captchaId': 'abc123'},
      });

      final challenge = SsoTokenService.parseCaptchaResponse(body);

      expect(challenge, isNotNull);
      expect(challenge!.captchaId, 'abc123');
      expect(challenge.imageBytes, isNotEmpty);
      // 前缀必须被剥掉，否则 base64 解不出来。
      expect(challenge.imageBytes, base64Decode(pngBase64));
    });

    test('兼容没有 data URI 前缀的纯 base64', () {
      final body = jsonEncode({
        'code': '0x000000',
        'data': {'base64': pngBase64, 'captchaId': 'no-prefix'},
      });

      final challenge = SsoTokenService.parseCaptchaResponse(body);

      expect(challenge?.captchaId, 'no-prefix');
      expect(challenge?.imageBytes, base64Decode(pngBase64));
    });

    test('服务端返回失败码时视为没有验证码', () {
      final body = jsonEncode({
        'code': '0x100105002',
        'msg': '图形验证码验证失败',
        'data': null,
      });

      expect(SsoTokenService.parseCaptchaResponse(body), isNull);
    });

    test('缺少 captchaId 或图片时返回 null', () {
      expect(
        SsoTokenService.parseCaptchaResponse(
          jsonEncode({
            'code': '0x000000',
            'data': {'base64': 'data:image/png;base64,$pngBase64'},
          }),
        ),
        isNull,
      );
      expect(
        SsoTokenService.parseCaptchaResponse(
          jsonEncode({
            'code': '0x000000',
            'data': {'captchaId': 'only-id'},
          }),
        ),
        isNull,
      );
    });

    test('非法输入不抛异常', () {
      expect(SsoTokenService.parseCaptchaResponse(''), isNull);
      expect(SsoTokenService.parseCaptchaResponse('<html>500</html>'), isNull);
      expect(
        SsoTokenService.parseCaptchaResponse(
          jsonEncode({
            'code': '0x000000',
            'data': {'base64': 'data:image/png;base64,!!!not-base64!!!', 'captchaId': 'x'},
          }),
        ),
        isNull,
      );
    });
  });

  group('SsoTokenService.isCaptchaRequired', () {
    test('data.isCaptcha 为 true 时要求验证码', () {
      expect(
        SsoTokenService.isCaptchaRequired({
          'code': '0x100105001',
          'msg': '密码错误',
          'data': {'isCaptcha': true},
        }),
        isTrue,
      );
    });

    test('字符串 true 也认', () {
      expect(
        SsoTokenService.isCaptchaRequired({
          'code': '0x100105001',
          'data': {'isCaptcha': 'true'},
        }),
        isTrue,
      );
    });

    test('没有该标记时不要求验证码', () {
      expect(
        SsoTokenService.isCaptchaRequired({'code': '0x100105001', 'data': {}}),
        isFalse,
      );
      expect(SsoTokenService.isCaptchaRequired({'code': '0x100105001'}), isFalse);
      expect(SsoTokenService.isCaptchaRequired({'code': '0x000000'}), isFalse);
    });
  });
}
