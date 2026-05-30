import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:JWHelper/features/auth/presentation/auth_provider.dart';
import 'package:JWHelper/app/state/data_provider.dart';
import 'package:JWHelper/shared/theme/theme_provider.dart';
import 'package:JWHelper/shared/theme/wallpaper_provider.dart';
import 'package:JWHelper/features/auth/presentation/login_screen.dart';
import 'package:JWHelper/infrastructure/platform/widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => WallpaperProvider()),
        ChangeNotifierProxyProvider<AuthProvider, DataProvider>(
          create: (_) => DataProvider(),
          update: (_, auth, data) =>
              data!..updateUsername(auth.currentUsername),
        ),
      ],
      child: Consumer2<ThemeProvider, WallpaperProvider>(
        builder: (context, themeProvider, wallpaperProvider, child) {
          final lp = wallpaperProvider.lightPrimary;
          final dp = wallpaperProvider.darkPrimary;
          final sc = wallpaperProvider.secondaryColor;
          final tc = wallpaperProvider.accentColor;

          return MaterialApp(
            title: '教务小助手',
            themeMode: themeProvider.themeMode,

            // ── Light theme ─────────────────────────────────────
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: lp,
                primary: lp,
                secondary: sc,
                tertiary: tc,
                surface: wallpaperProvider.lightSurface,
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: wallpaperProvider.lightSurface,
              appBarTheme: AppBarTheme(
                backgroundColor: wallpaperProvider.lightAppBar,
                surfaceTintColor: Colors.transparent,
                foregroundColor: lp,
                iconTheme: IconThemeData(color: lp),
                actionsIconTheme: IconThemeData(color: lp),
                titleTextStyle: TextStyle(
                  color: lp,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: wallpaperProvider.lightAppBar.withValues(alpha: 0.6),
                surfaceTintColor: Colors.transparent,
                indicatorColor: lp.withValues(alpha: 0.15),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return IconThemeData(color: lp);
                  }
                  return const IconThemeData(color: Colors.grey);
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return TextStyle(
                      color: lp,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    );
                  }
                  return const TextStyle(color: Colors.grey, fontSize: 12);
                }),
              ),
              cardTheme: CardThemeData(
                color: wallpaperProvider.lightCard,
                surfaceTintColor: Colors.transparent,
              ),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: lp,
                foregroundColor: Colors.white,
              ),
              dividerColor: Colors.grey.withValues(alpha: 0.15),
              useMaterial3: true,
              textTheme: GoogleFonts.notoSansTextTheme(),
            ),

            // ── Dark theme ──────────────────────────────────────
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: dp,
                primary: dp,
                secondary: sc,
                tertiary: tc,
                surface: wallpaperProvider.darkSurface,
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: wallpaperProvider.darkSurface,
              appBarTheme: AppBarTheme(
                backgroundColor: wallpaperProvider.darkAppBar,
                surfaceTintColor: Colors.transparent,
                foregroundColor: dp,
                iconTheme: IconThemeData(color: dp),
                actionsIconTheme: IconThemeData(color: dp),
                titleTextStyle: TextStyle(
                  color: dp,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: wallpaperProvider.darkAppBar.withValues(alpha: 0.6),
                surfaceTintColor: Colors.transparent,
                indicatorColor: dp.withValues(alpha: 0.2),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return IconThemeData(color: dp);
                  }
                  return const IconThemeData(color: Colors.grey);
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return TextStyle(
                      color: dp,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    );
                  }
                  return const TextStyle(color: Colors.grey, fontSize: 12);
                }),
              ),
              cardTheme: CardThemeData(
                color: wallpaperProvider.darkCard,
                surfaceTintColor: Colors.transparent,
              ),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: dp,
                foregroundColor: Colors.white,
              ),
              dividerColor: Colors.white.withValues(alpha: 0.08),
              useMaterial3: true,
              textTheme: GoogleFonts.notoSansTextTheme(ThemeData.dark().textTheme),
            ),
            home: const LoginScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
