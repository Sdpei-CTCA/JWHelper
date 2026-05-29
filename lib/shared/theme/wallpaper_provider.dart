import 'dart:io';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WallpaperProvider with ChangeNotifier {
  String? _wallpaperPath;
  double _opacity = 0.3;
  double _listCardOpacity = 1.0;
  double _gridCardOpacity = 1.0;
  Color _primaryColor = const Color(0xFF409EFF);
  Color _secondaryColor = const Color(0xFF67C23A);
  Color _accentColor = const Color(0xFFE6A23C);
  bool _isLoaded = false;

  String? get wallpaperPath => _wallpaperPath;
  double get opacity => _opacity;
  double get listCardOpacity => _listCardOpacity;
  double get gridCardOpacity => _gridCardOpacity;
  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;
  Color get accentColor => _accentColor;
  bool get isLoaded => _isLoaded;

  WallpaperProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _wallpaperPath = prefs.getString('wallpaperPath');
    _opacity = prefs.getDouble('wallpaperOpacity') ?? 0.3;
    _listCardOpacity = prefs.getDouble('listCardOpacity') ?? 1.0;
    _gridCardOpacity = prefs.getDouble('gridCardOpacity') ?? 1.0;
    
    // Load saved colors
    final primaryValue = prefs.getInt('wallpaperPrimaryColor');
    final secondaryValue = prefs.getInt('wallpaperSecondaryColor');
    final accentValue = prefs.getInt('wallpaperAccentColor');
    
    if (primaryValue != null) _primaryColor = Color(primaryValue);
    if (secondaryValue != null) _secondaryColor = Color(secondaryValue);
    if (accentValue != null) _accentColor = Color(accentValue);
    
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

  Future<void> setOpacity(double value) async {
    _opacity = value.clamp(0.0, 1.0);
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('wallpaperOpacity', _opacity);
  }

  Future<void> setListCardOpacity(double value) async {
    _listCardOpacity = value.clamp(0.0, 1.0);
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('listCardOpacity', _listCardOpacity);
  }

  Future<void> setGridCardOpacity(double value) async {
    _gridCardOpacity = value.clamp(0.0, 1.0);
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('gridCardOpacity', _gridCardOpacity);
  }

  Future<void> _extractColors(String imagePath) async {
    try {
      final PaletteGenerator paletteGenerator = 
        await PaletteGenerator.fromImageProvider(
          FileImage(File(imagePath)),
          size: const Size(200, 200),
          maximumColorCount: 20,
        );

      // Extract dominant colors
      if (paletteGenerator.dominantColor != null) {
        _primaryColor = paletteGenerator.dominantColor!.color;
      }
      if (paletteGenerator.vibrantColor != null) {
        _secondaryColor = paletteGenerator.vibrantColor!.color;
      } else if (paletteGenerator.lightVibrantColor != null) {
        _secondaryColor = paletteGenerator.lightVibrantColor!.color;
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

      // Save colors
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('wallpaperPrimaryColor', _primaryColor.toARGB32());
      await prefs.setInt('wallpaperSecondaryColor', _secondaryColor.toARGB32());
      await prefs.setInt('wallpaperAccentColor', _accentColor.toARGB32());
      
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
  Color get lightPrimary {
    final hsl = HSLColor.fromColor(_primaryColor);
    return hsl.withLightness(0.45.clamp(0.0, 1.0)).withSaturation(
      (hsl.saturation * 1.1).clamp(0.0, 1.0),
    ).toColor();
  }

  /// Slightly tinted white surface  (L ≈ 0.97)
  Color get lightSurface {
    final hsl = HSLColor.fromColor(_primaryColor);
    return hsl.withLightness(0.97).withSaturation(0.15).toColor();
  }

  /// White card with very subtle tint
  Color get lightCard => Colors.white;

  /// White app bar
  Color get lightAppBar => Colors.white;

  // ── Dark-mode palette ───────────────────────────────────────

  /// Softer, desaturated primary for dark mode (L ≈ 0.55)
  Color get darkPrimary {
    final hsl = HSLColor.fromColor(_primaryColor);
    return hsl.withLightness(0.55.clamp(0.0, 1.0)).withSaturation(
      (hsl.saturation * 0.8).clamp(0.0, 1.0),
    ).toColor();
  }

  /// Dark surface with subtle primary tint  (L ≈ 0.10)
  Color get darkSurface {
    final hsl = HSLColor.fromColor(_primaryColor);
    return hsl.withLightness(0.10).withSaturation(0.15).toColor();
  }

  /// Slightly lighter card for dark mode (L ≈ 0.14)
  Color get darkCard {
    final hsl = HSLColor.fromColor(_primaryColor);
    return hsl.withLightness(0.14).withSaturation(0.12).toColor();
  }

  /// AppBar for dark mode (L ≈ 0.12)
  Color get darkAppBar {
    final hsl = HSLColor.fromColor(_primaryColor);
    return hsl.withLightness(0.12).withSaturation(0.12).toColor();
  }

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
    _primaryColor = const Color(0xFF409EFF);
    _secondaryColor = const Color(0xFF67C23A);
    _accentColor = const Color(0xFFE6A23C);
    
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wallpaperPath');
    await prefs.remove('wallpaperOpacity');
    await prefs.remove('listCardOpacity');
    await prefs.remove('gridCardOpacity');
    await prefs.remove('wallpaperPrimaryColor');
    await prefs.remove('wallpaperSecondaryColor');
    await prefs.remove('wallpaperAccentColor');
  }
}
