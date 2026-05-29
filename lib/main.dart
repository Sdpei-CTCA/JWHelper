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
          final hasWallpaper = wallpaperProvider.wallpaperPath != null;

          return MaterialApp(
            title: '教务小助手',
            themeMode: themeProvider.themeMode,

            // ── Light theme ─────────────────────────────────────
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: hasWallpaper ? wallpaperProvider.lightPrimary : const Color(0xFF409EFF),
                primary: hasWallpaper ? wallpaperProvider.lightPrimary : const Color(0xFF409EFF),
                secondary: hasWallpaper ? wallpaperProvider.secondaryColor : const Color(0xFF67C23A),
                tertiary: hasWallpaper ? wallpaperProvider.accentColor : const Color(0xFFE6A23C),
                surface: hasWallpaper ? wallpaperProvider.lightSurface : const Color(0xFFF5F7FA),
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: hasWallpaper ? wallpaperProvider.lightSurface : const Color(0xFFF5F7FA),
              appBarTheme: AppBarTheme(
                backgroundColor: hasWallpaper ? wallpaperProvider.lightAppBar : Colors.white,
                surfaceTintColor: Colors.transparent,
                foregroundColor: hasWallpaper ? wallpaperProvider.lightPrimary : const Color(0xFF409EFF),
                iconTheme: IconThemeData(color: hasWallpaper ? wallpaperProvider.lightPrimary : const Color(0xFF409EFF)),
                actionsIconTheme: IconThemeData(color: hasWallpaper ? wallpaperProvider.lightPrimary : const Color(0xFF409EFF)),
                titleTextStyle: TextStyle(
                  color: hasWallpaper ? wallpaperProvider.lightPrimary : const Color(0xFF409EFF),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: hasWallpaper ? wallpaperProvider.lightAppBar : Colors.white,
                surfaceTintColor: Colors.transparent,
                indicatorColor: (hasWallpaper ? wallpaperProvider.lightPrimary : const Color(0xFF409EFF)).withValues(alpha: 0.15),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return IconThemeData(color: hasWallpaper ? wallpaperProvider.lightPrimary : const Color(0xFF409EFF));
                  }
                  return const IconThemeData(color: Colors.grey);
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return TextStyle(
                      color: hasWallpaper ? wallpaperProvider.lightPrimary : const Color(0xFF409EFF),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    );
                  }
                  return const TextStyle(color: Colors.grey, fontSize: 12);
                }),
              ),
              cardTheme: CardThemeData(
                color: hasWallpaper ? wallpaperProvider.lightCard : Colors.white,
                surfaceTintColor: Colors.transparent,
              ),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: hasWallpaper ? wallpaperProvider.lightPrimary : const Color(0xFF409EFF),
                foregroundColor: Colors.white,
              ),
              dividerColor: Colors.grey.withValues(alpha: 0.15),
              useMaterial3: true,
              textTheme: GoogleFonts.notoSansTextTheme(),
            ),

            // ── Dark theme ──────────────────────────────────────
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: hasWallpaper ? wallpaperProvider.darkPrimary : const Color(0xFF409EFF),
                primary: hasWallpaper ? wallpaperProvider.darkPrimary : const Color(0xFF409EFF),
                secondary: hasWallpaper ? wallpaperProvider.secondaryColor : const Color(0xFF67C23A),
                tertiary: hasWallpaper ? wallpaperProvider.accentColor : const Color(0xFFE6A23C),
                surface: hasWallpaper ? wallpaperProvider.darkSurface : const Color(0xFF121212),
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: hasWallpaper ? wallpaperProvider.darkSurface : const Color(0xFF121212),
              appBarTheme: AppBarTheme(
                backgroundColor: hasWallpaper ? wallpaperProvider.darkAppBar : const Color(0xFF1E1E1E),
                surfaceTintColor: Colors.transparent,
                foregroundColor: hasWallpaper ? wallpaperProvider.darkPrimary : const Color(0xFF409EFF),
                iconTheme: IconThemeData(color: hasWallpaper ? wallpaperProvider.darkPrimary : const Color(0xFF409EFF)),
                actionsIconTheme: IconThemeData(color: hasWallpaper ? wallpaperProvider.darkPrimary : const Color(0xFF409EFF)),
                titleTextStyle: TextStyle(
                  color: hasWallpaper ? wallpaperProvider.darkPrimary : const Color(0xFF409EFF),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: hasWallpaper ? wallpaperProvider.darkAppBar : const Color(0xFF1E1E1E),
                surfaceTintColor: Colors.transparent,
                indicatorColor: (hasWallpaper ? wallpaperProvider.darkPrimary : const Color(0xFF409EFF)).withValues(alpha: 0.2),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return IconThemeData(color: hasWallpaper ? wallpaperProvider.darkPrimary : const Color(0xFF409EFF));
                  }
                  return const IconThemeData(color: Colors.grey);
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return TextStyle(
                      color: hasWallpaper ? wallpaperProvider.darkPrimary : const Color(0xFF409EFF),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    );
                  }
                  return const TextStyle(color: Colors.grey, fontSize: 12);
                }),
              ),
              cardTheme: CardThemeData(
                color: hasWallpaper ? wallpaperProvider.darkCard : const Color(0xFF1E1E1E),
                surfaceTintColor: Colors.transparent,
              ),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: hasWallpaper ? wallpaperProvider.darkPrimary : const Color(0xFF409EFF),
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
