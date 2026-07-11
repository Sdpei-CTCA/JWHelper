import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:JWHelper/app/navigation/app_navigator.dart';
import 'package:JWHelper/app/state/data_provider.dart';
import 'package:JWHelper/core/errors/exceptions.dart';
import 'package:JWHelper/features/auth/presentation/auth_provider.dart';
import 'package:JWHelper/features/auth/presentation/login_screen.dart';

class SessionExpiredCoordinator {
  SessionExpiredCoordinator._();

  static bool _isHandling = false;

  static Future<void> handle([
    LoginSessionExpiredException? exception,
  ]) async {
    if (_isHandling) return;
    _isHandling = true;
    try {
      final context = rootNavigatorKey.currentContext;
      if (context == null) return;

      final auth = context.read<AuthProvider>();
      await auth.expireSession();

      final reloginError = await auth.trySilentRelogin();
      if (!context.mounted) return;

      if (auth.isLoggedIn && reloginError == null) {
        final data = context.read<DataProvider>();
        if (auth.isOfflineMode) {
          data.prepareOfflineLoginData();
        } else {
          await data.prepareOnlineLoginData();
        }
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录已过期，已自动重新登录')),
        );
        return;
      }

      final baseMessage = exception?.message ?? '登录已过期，请重新登录';
      final message = reloginError == null
          ? baseMessage
          : '$baseMessage（$reloginError）';

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginScreen(sessionExpiredMessage: message),
        ),
        (_) => false,
      );
    } finally {
      _isHandling = false;
    }
  }
}
