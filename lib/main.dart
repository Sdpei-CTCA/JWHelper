import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/features/auth/presentation/auth_provider.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_provider.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_web_actions.dart';
import 'package:JWHelper/features/notice/presentation/notice_entry_style.dart';
import 'package:JWHelper/features/notice/presentation/notice_provider.dart';
import 'package:JWHelper/app/state/data_provider.dart';
import 'package:JWHelper/shared/theme/theme_provider.dart';
import 'package:JWHelper/shared/theme/wallpaper_provider.dart';
import 'package:JWHelper/app/coordinators/session_expired_coordinator.dart';
import 'package:JWHelper/app/navigation/app_navigator.dart';
import 'package:JWHelper/app/presentation/home_screen.dart';
import 'package:JWHelper/infrastructure/network/client.dart';
import 'package:JWHelper/infrastructure/platform/widget_service.dart';
import 'package:JWHelper/app/background/background_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient.onSessionExpired = SessionExpiredCoordinator.handle;
  // Pre-warm SharedPreferences so it's ready when HomeScreen reads cache
  SharedPreferences.getInstance();
  // WidgetService.init() runs in background, doesn't block app launch
  WidgetService.init();
  // 后台轮询：注册回调并按开关状态安排/取消周期任务，失败不影响启动
  unawaited(BackgroundSync.initialize());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        // 考勤网页版与首页标题栏之间的操作桥（按钮在标题栏，动作在 tab 页里）
        ChangeNotifierProvider(create: (_) => AttendanceWebActions()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => WallpaperProvider()),
        ChangeNotifierProxyProvider<AuthProvider, DataProvider>(
          create: (_) => DataProvider(),
          update: (_, auth, data) =>
              data!..updateUsername(auth.currentUsername),
        ),
        // 通知公告复用考勤模块的统一认证登录态，因此挂在 AttendanceProvider 之后。
        ChangeNotifierProxyProvider<AttendanceProvider, NoticeProvider>(
          create: (_) => NoticeProvider(),
          update: (_, attendance, notice) => notice!..attachAuth(attendance),
        ),
        ChangeNotifierProvider(create: (_) => NoticeEntryStyleProvider()),
      ],
      child: Selector2<
          ThemeProvider,
          WallpaperProvider,
          ({
            ThemeMode themeMode,
            Color lp,
            Color dp,
            Color sc,
            Color tc,
            Color lightSurface,
            Color lightAppBar,
            Color lightCard,
            Color darkSurface,
            Color darkAppBar,
            Color darkCard,
          })>(
        selector: (_, themeProvider, wp) => (
          themeMode: themeProvider.themeMode,
          lp: wp.lightPrimary,
          dp: wp.darkPrimary,
          sc: wp.secondaryColor,
          tc: wp.accentColor,
          lightSurface: wp.lightSurface,
          lightAppBar: wp.lightAppBar,
          lightCard: wp.lightCard,
          darkSurface: wp.darkSurface,
          darkAppBar: wp.darkAppBar,
          darkCard: wp.darkCard,
        ),
        child: const HomeScreen(),
        builder: (context, s, home) {
          return MaterialApp(
            navigatorKey: rootNavigatorKey,
            title: '教务小助手',
            themeMode: s.themeMode,
            theme: _buildThemeData(
              brightness: Brightness.light,
              primary: s.lp,
              secondary: s.sc,
              tertiary: s.tc,
              surface: s.lightSurface,
              appBar: s.lightAppBar,
              card: s.lightCard,
              navIndicatorAlpha: 0.15,
              dividerColor: Colors.grey.withValues(alpha: 0.15),
            ),
            darkTheme: _buildThemeData(
              brightness: Brightness.dark,
              primary: s.dp,
              secondary: s.sc,
              tertiary: s.tc,
              surface: s.darkSurface,
              appBar: s.darkAppBar,
              card: s.darkCard,
              navIndicatorAlpha: 0.2,
              dividerColor: Colors.white.withValues(alpha: 0.08),
            ),
            home: home,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }

  static ThemeData _buildThemeData({
    required Brightness brightness,
    required Color primary,
    required Color secondary,
    required Color tertiary,
    required Color surface,
    required Color appBar,
    required Color card,
    required double navIndicatorAlpha,
    required Color dividerColor,
  }) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        surface: surface,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: appBar,
        surfaceTintColor: Colors.transparent,
        foregroundColor: primary,
        iconTheme: IconThemeData(color: primary),
        actionsIconTheme: IconThemeData(color: primary),
        titleTextStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: appBar.withValues(alpha: 0.6),
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: navIndicatorAlpha),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary);
          }
          return const IconThemeData(color: Colors.grey);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            );
          }
          return const TextStyle(color: Colors.grey, fontSize: 12);
        }),
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      dividerColor: dividerColor,
      useMaterial3: true,
    );
  }
}
