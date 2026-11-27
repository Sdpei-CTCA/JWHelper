import 'dart:io';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WallpaperProvider with ChangeNotifier {
  static const String defaultThemeKey = 'classic_light';

  String? _wallpaperPath;
  double _opacity = 0.3;
  double _listCardOpacity = 1.0;
  double _gridCardOpacity = 1.0;
  double _panX = 0.0; // -1.0 ~ 1.0, left/right
  double _panY = 0.0; // -1.0 ~ 1.0, up/down
  Color _primaryColor = const Color(0xFF409EFF);
  Color _secondaryColor = const Color(0xFF67C23A);
  Color _accentColor = const Color(0xFFE6A23C);
  bool _isLoaded = false;

  late Color _lightPrimary;
  late Color _lightSurface;
  late Color _darkPrimary;
  late Color _darkSurface;
  late Color _darkCard;
  late Color _darkAppBar;

  String? get wallpaperPath => _wallpaperPath;
  double get opacity => _opacity;
  double get listCardOpacity => _listCardOpacity;
  double get gridCardOpacity => _gridCardOpacity;
  double get panX => _panX;
  double get panY => _panY;
  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;
  Color get accentColor => _accentColor;
  bool get isLoaded => _isLoaded;

  WallpaperProvider() {
    _rebuildDerivedPalette();
    _loadSettings();
  }

  void _rebuildDerivedPalette() {
    final hsl = HSLColor.fromColor(_primaryColor);
    _lightPrimary = hsl
        .withLightness(0.45)
        .withSaturation((hsl.saturation * 1.1).clamp(0.0, 1.0))
        .toColor();
    _lightSurface = hsl.withLightness(0.97).withSaturation(0.15).toColor();
    _darkPrimary = hsl
        .withLightness(0.55)
        .withSaturation((hsl.saturation * 0.8).clamp(0.0, 1.0))
        .toColor();
    _darkSurface = hsl.withLightness(0.10).withSaturation(0.15).toColor();
    _darkCard = hsl.withLightness(0.14).withSaturation(0.12).toColor();
    _darkAppBar = hsl.withLightness(0.12).withSaturation(0.12).toColor();
  }

  // Saved extracted colors from wallpaper (preserved across theme changes)
  Color? _extractedPrimary;
  Color? _extractedSecondary;
  Color? _extractedAccent;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _wallpaperPath = prefs.getString('wallpaperPath');
    _opacity = prefs.getDouble('wallpaperOpacity') ?? 0.3;
    _listCardOpacity = prefs.getDouble('listCardOpacity') ?? 1.0;
    _gridCardOpacity = prefs.getDouble('gridCardOpacity') ?? 1.0;
    _panX = prefs.getDouble('wallpaperPanX') ?? 0.0;
    _panY = prefs.getDouble('wallpaperPanY') ?? 0.0;
    
    // Load saved extracted wallpaper colors
    final extPrimary = prefs.getInt('wallpaperExtractedPrimary');
    final extSecondary = prefs.getInt('wallpaperExtractedSecondary');
    final extAccent = prefs.getInt('wallpaperExtractedAccent');
    if (extPrimary != null) _extractedPrimary = Color(extPrimary);
    if (extSecondary != null) _extractedSecondary = Color(extSecondary);
    if (extAccent != null) _extractedAccent = Color(extAccent);
    
    // Check if a default theme was applied
    final themeKey = prefs.getString('defaultThemeKey');
    if (_wallpaperPath == null) {
      if (themeKey != null) {
        _applyThemeColors(themeKey);
      } else {
        final primaryValue = prefs.getInt('wallpaperPrimaryColor');
        if (primaryValue != null) {
          final secondaryValue = prefs.getInt('wallpaperSecondaryColor');
          final accentValue = prefs.getInt('wallpaperAccentColor');
          _primaryColor = Color(primaryValue);
          if (secondaryValue != null) {
            _secondaryColor = Color(secondaryValue);
          }
          if (accentValue != null) _accentColor = Color(accentValue);
        } else {
          _applyThemeColors(defaultThemeKey);
          await _persistThemeColors(defaultThemeKey);
        }
      }
    } else {
      final primaryValue = prefs.getInt('wallpaperPrimaryColor');
      final secondaryValue = prefs.getInt('wallpaperSecondaryColor');
      final accentValue = prefs.getInt('wallpaperAccentColor');

      if (primaryValue != null) _primaryColor = Color(primaryValue);
      if (secondaryValue != null) _secondaryColor = Color(secondaryValue);
      if (accentValue != null) _accentColor = Color(accentValue);
    }
    
    _rebuildDerivedPalette();
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setWallpaper(String? path) async {
    _wallpaperPath = path;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString('wallpaperPath', path);
      await _extractColors(path);
    } else {
      await prefs.remove('wallpaperPath');
    }
  }

  Future<void> setOpacity(double value, {bool persist = true}) async {
    final next = value.clamp(0.0, 1.0);
    if (next != _opacity) {
      _opacity = next;
      notifyListeners();
    }
    if (!persist) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('wallpaperOpacity', _opacity);
  }

  Future<void> setListCardOpacity(double value, {bool persist = true}) async {
    final next = value.clamp(0.0, 1.0);
    if (next != _listCardOpacity) {
      _listCardOpacity = next;
      notifyListeners();
    }
    if (!persist) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('listCardOpacity', _listCardOpacity);
  }

  Future<void> setGridCardOpacity(double value, {bool persist = true}) async {
    final next = value.clamp(0.0, 1.0);
    if (next != _gridCardOpacity) {
      _gridCardOpacity = next;
      notifyListeners();
    }
    if (!persist) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('gridCardOpacity', _gridCardOpacity);
  }

  Future<void> setPanX(double value, {bool persist = true}) async {
    final next = value.clamp(-1.0, 1.0);
    if (next != _panX) {
      _panX = next;
      notifyListeners();
    }
    if (!persist) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('wallpaperPanX', _panX);
  }

  Future<void> setPanY(double value, {bool persist = true}) async {
    final next = value.clamp(-1.0, 1.0);
    if (next != _panY) {
      _panY = next;
      notifyListeners();
    }
    if (!persist) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('wallpaperPanY', _panY);
  }

  Future<void> resetPan() async {
    if (_panX == 0.0 && _panY == 0.0) return;
    _panX = 0.0;
    _panY = 0.0;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setDouble('wallpaperPanX', 0.0),
      prefs.setDouble('wallpaperPanY', 0.0),
    ]);
  }

  Alignment get wallpaperAlignment => Alignment(
    _panX.clamp(-1.0, 1.0),
    _panY.clamp(-1.0, 1.0),
  );

  // ── Default themes ─────────────────────────────────────────

  static const Map<String, Map<String, dynamic>> defaultThemes = {
    'spring': {
      'name': '春 · 新绿',
      'icon': Icons.local_florist,
      'color': Color(0xFF4CAF50),
      'primary': Color(0xFF4CAF50),
      'secondary': Color(0xFF81C784),
      'accent': Color(0xFFFFB74D),
    },
    'summer': {
      'name': '夏 · 盛夏',
      'icon': Icons.wb_sunny,
      'color': Color(0xFFFF7043),
      'primary': Color(0xFFFF7043),
      'secondary': Color(0xFFFFB74D),
      'accent': Color(0xFF4FC3F7),
    },
    'autumn': {
      'name': '秋 · 金秋',
      'icon': Icons.park,
      'color': Color(0xFFFF8F00),
      'primary': Color(0xFFE65100),
      'secondary': Color(0xFFFF8F00),
      'accent': Color(0xFF8D6E63),
    },
    'winter': {
      'name': '冬 · 雪境',
      'icon': Icons.ac_unit,
      'color': Color(0xFF5C6BC0),
      'primary': Color(0xFF5C6BC0),
      'secondary': Color(0xFF90CAF9),
      'accent': Color(0xFFB0BEC5),
    },
    'classic_light': {
      'name': '经典白',
      'icon': Icons.light_mode,
      'color': Color(0xFF409EFF),
      'primary': Color(0xFF409EFF),
      'secondary': Color(0xFF67C23A),
      'accent': Color(0xFFE6A23C),
    },
    'classic_dark': {
      'name': '经典黑',
      'icon': Icons.dark_mode,
      'color': Color(0xFF90A4AE),
      'primary': Color(0xFF90A4AE),
      'secondary': Color(0xFF78909C),
      'accent': Color(0xFFB0BEC5),
    },
  };

  Future<void> applyDefaultTheme(String themeKey) async {
    final theme = defaultThemes[themeKey];
    if (theme == null) return;

    _applyThemeColors(themeKey);
    await _persistThemeColors(themeKey);
    notifyListeners();
  }

  void _applyThemeColors(String themeKey) {
    final theme = defaultThemes[themeKey];
    if (theme == null) return;
    _primaryColor = theme['primary'] as Color;
    _secondaryColor = theme['secondary'] as Color;
    _accentColor = theme['accent'] as Color;
    _rebuildDerivedPalette();
  }

  Future<void> _persistThemeColors(String themeKey) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt('wallpaperPrimaryColor', _primaryColor.toARGB32()),
      prefs.setInt('wallpaperSecondaryColor', _secondaryColor.toARGB32()),
      prefs.setInt('wallpaperAccentColor', _accentColor.toARGB32()),
      prefs.setString('defaultThemeKey', themeKey),
    ]);
  }

  bool get hasExtractedColors =>
      _extractedPrimary != null && _wallpaperPath != null;

  bool get isUsingDefaultTheme {
    // We're using default theme if no wallpaper is set
    return _wallpaperPath == null;
  }

  Future<void> restoreWallpaperColors() async {
    if (_extractedPrimary == null || _wallpaperPath == null) return;

    _primaryColor = _extractedPrimary!;
    _secondaryColor = _extractedSecondary ?? _secondaryColor;
    _accentColor = _extractedAccent ?? _accentColor;
    _rebuildDerivedPalette();

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt('wallpaperPrimaryColor', _primaryColor.toARGB32()),
      prefs.setInt('wallpaperSecondaryColor', _secondaryColor.toARGB32()),
      prefs.setInt('wallpaperAccentColor', _accentColor.toARGB32()),
      prefs.remove('defaultThemeKey'),
    ]);
  }

  Future<void> _extractColors(String imagePath) async {
    try {
      final PaletteGenerator paletteGenerator =
          await PaletteGenerator.fromImageProvider(
        ResizeImage(FileImage(File(imagePath)), width: 200),
        size: const Size(200, 200),
        maximumColorCount: 20,
      );

      // Extract dominant colors - swap primary/secondary for better UI fit
      if (paletteGenerator.vibrantColor != null) {
        _primaryColor = paletteGenerator.vibrantColor!.color;
      } else if (paletteGenerator.lightVibrantColor != null) {
        _primaryColor = paletteGenerator.lightVibrantColor!.color;
      } else if (paletteGenerator.dominantColor != null) {
        _primaryColor = paletteGenerator.dominantColor!.color;
      }
      if (paletteGenerator.dominantColor != null) {
        _secondaryColor = paletteGenerator.dominantColor!.color;
      }
      if (paletteGenerator.darkVibrantColor != null) {
        _accentColor = paletteGenerator.darkVibrantColor!.color;
      } else if (paletteGenerator.mutedColor != null) {
        _accentColor = paletteGenerator.mutedColor!.color;
      }

      // Ensure colors have enough contrast
      _primaryColor = _adjustColorForContrast(_primaryColor);
      _secondaryColor = _adjustColorForContrast(_secondaryColor);
      _accentColor = _adjustColorForContrast(_accentColor);
      _rebuildDerivedPalette();

      // Save extracted originals (for restore-from-theme later)
      _extractedPrimary = _primaryColor;
      _extractedSecondary = _secondaryColor;
      _extractedAccent = _accentColor;

      // Save colors
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setInt('wallpaperPrimaryColor', _primaryColor.toARGB32()),
        prefs.setInt('wallpaperSecondaryColor', _secondaryColor.toARGB32()),
        prefs.setInt('wallpaperAccentColor', _accentColor.toARGB32()),
        prefs.setInt('wallpaperExtractedPrimary', _primaryColor.toARGB32()),
        prefs.setInt('wallpaperExtractedSecondary', _secondaryColor.toARGB32()),
        prefs.setInt('wallpaperExtractedAccent', _accentColor.toARGB32()),
        prefs.remove('defaultThemeKey'),
      ]);

      notifyListeners();
    } catch (e) {
      debugPrint('Error extracting colors: $e');
    }
  }

  Color _adjustColorForContrast(Color color) {
    final luminance = color.computeLuminance();
    if (luminance < 0.2) {
      return HSLColor.fromColor(color).withLightness(0.4).toColor();
    } else if (luminance > 0.8) {
      return HSLColor.fromColor(color).withLightness(0.6).toColor();
    }
    return color;
  }

  // ── Light-mode palette ──────────────────────────────────────

  /// Bright, saturated primary for light mode (L ≈ 0.45)
  Color get lightPrimary => _lightPrimary;

  /// Slightly tinted white surface  (L ≈ 0.97)
  Color get lightSurface => _lightSurface;

  /// White card with very subtle tint
  Color get lightCard => Colors.white;

  /// White app bar
  Color get lightAppBar => Colors.white;

  // ── Dark-mode palette ───────────────────────────────────────

  /// Softer, desaturated primary for dark mode (L ≈ 0.55)
  Color get darkPrimary => _darkPrimary;

  /// Dark surface with subtle primary tint  (L ≈ 0.10)
  Color get darkSurface => _darkSurface;

  /// Slightly lighter card for dark mode (L ≈ 0.14)
  Color get darkCard => _darkCard;

  /// AppBar for dark mode (L ≈ 0.12)
  Color get darkAppBar => _darkAppBar;

  // ── Shared helpers ──────────────────────────────────────────

  Color getAdaptiveColor(BuildContext context, {bool isPrimary = true}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isPrimary) return isDark ? darkPrimary : lightPrimary;
    return isDark ? _secondaryColor.withValues(alpha: 0.8) : _secondaryColor;
  }

  ColorScheme getColorScheme(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColorScheme.fromSeed(
      seedColor: isDark ? darkPrimary : lightPrimary,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: isDark ? darkPrimary : lightPrimary,
      secondary: _secondaryColor,
      tertiary: _accentColor,
    );
  }

  Future<void> clearWallpaper() async {
    _wallpaperPath = null;
    _opacity = 0.3;
    _listCardOpacity = 1.0;
    _gridCardOpacity = 1.0;
    _panX = 0.0;
    _panY = 0.0;
    _applyThemeColors(defaultThemeKey);
    _extractedPrimary = null;
    _extractedSecondary = null;
    _extractedAccent = null;

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove('wallpaperPath'),
      prefs.remove('wallpaperOpacity'),
      prefs.remove('listCardOpacity'),
      prefs.remove('gridCardOpacity'),
      prefs.remove('wallpaperPanX'),
      prefs.remove('wallpaperPanY'),
      prefs.remove('wallpaperExtractedPrimary'),
      prefs.remove('wallpaperExtractedSecondary'),
      prefs.remove('wallpaperExtractedAccent'),
      prefs.setString('defaultThemeKey', defaultThemeKey),
      prefs.setInt('wallpaperPrimaryColor', _primaryColor.toARGB32()),
      prefs.setInt('wallpaperSecondaryColor', _secondaryColor.toARGB32()),
      prefs.setInt('wallpaperAccentColor', _accentColor.toARGB32()),
    ]);
  }
}
