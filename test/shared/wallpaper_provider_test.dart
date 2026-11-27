import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/shared/theme/wallpaper_provider.dart';

Future<void> _waitLoaded(WallpaperProvider provider) async {
  for (var i = 0; i < 50 && !provider.isLoaded; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(provider.isLoaded, isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('derived palette caches colors and updates when theme changes',
      () async {
    final provider = WallpaperProvider();
    await _waitLoaded(provider);

    final initialLightPrimary = provider.lightPrimary;
    final initialDarkSurface = provider.darkSurface;

    // Repeated reads return the exact same cached values.
    expect(provider.lightPrimary, equals(initialLightPrimary));
    expect(provider.darkSurface, equals(initialDarkSurface));

    await provider.applyDefaultTheme('spring');
    final springHsl = HSLColor.fromColor(const Color(0xFF4CAF50));
    final expectedSpringLight = springHsl
        .withLightness(0.45)
        .withSaturation((springHsl.saturation * 1.1).clamp(0.0, 1.0))
        .toColor();
    expect(provider.lightPrimary, equals(expectedSpringLight));
    expect(provider.lightPrimary, isNot(equals(initialLightPrimary)));

    await provider.applyDefaultTheme('winter');
    expect(provider.lightPrimary, isNot(equals(expectedSpringLight)));
  });

  test('persist=false updates memory without disk writes until persist=true',
      () async {
    final provider = WallpaperProvider();
    await _waitLoaded(provider);

    var notifications = 0;
    provider.addListener(() => notifications++);

    await provider.setOpacity(0.65, persist: false);
    await provider.setListCardOpacity(0.8, persist: false);
    await provider.setGridCardOpacity(0.75, persist: false);
    await provider.setPanX(0.4, persist: false);
    await provider.setPanY(-0.3, persist: false);

    expect(provider.opacity, closeTo(0.65, 1e-6));
    expect(provider.listCardOpacity, closeTo(0.8, 1e-6));
    expect(provider.gridCardOpacity, closeTo(0.75, 1e-6));
    expect(provider.panX, closeTo(0.4, 1e-6));
    expect(provider.panY, closeTo(-0.3, 1e-6));
    expect(notifications, 5);

    final prefsBeforePersist = await SharedPreferences.getInstance();
    expect(prefsBeforePersist.containsKey('wallpaperOpacity'), isFalse);
    expect(prefsBeforePersist.containsKey('listCardOpacity'), isFalse);
    expect(prefsBeforePersist.containsKey('gridCardOpacity'), isFalse);
    expect(prefsBeforePersist.containsKey('wallpaperPanX'), isFalse);
    expect(prefsBeforePersist.containsKey('wallpaperPanY'), isFalse);

    // Persisting unchanged values writes to disk without extra notifications.
    await provider.setOpacity(0.65, persist: true);
    await provider.setListCardOpacity(0.8, persist: true);
    await provider.setGridCardOpacity(0.75, persist: true);
    await provider.setPanX(0.4, persist: true);
    await provider.setPanY(-0.3, persist: true);

    expect(notifications, 5);
    final prefsAfterPersist = await SharedPreferences.getInstance();
    expect(prefsAfterPersist.getDouble('wallpaperOpacity'), closeTo(0.65, 1e-6));
    expect(prefsAfterPersist.getDouble('listCardOpacity'), closeTo(0.8, 1e-6));
    expect(prefsAfterPersist.getDouble('gridCardOpacity'), closeTo(0.75, 1e-6));
    expect(prefsAfterPersist.getDouble('wallpaperPanX'), closeTo(0.4, 1e-6));
    expect(prefsAfterPersist.getDouble('wallpaperPanY'), closeTo(-0.3, 1e-6));
  });

  test('resetPan resets both axes in a single notification and persists',
      () async {
    final provider = WallpaperProvider();
    await _waitLoaded(provider);

    await provider.setPanX(0.5, persist: false);
    await provider.setPanY(-0.5, persist: false);

    var notifications = 0;
    provider.addListener(() => notifications++);

    await provider.resetPan();
    expect(provider.panX, 0.0);
    expect(provider.panY, 0.0);
    expect(notifications, 1);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('wallpaperPanX'), 0.0);
    expect(prefs.getDouble('wallpaperPanY'), 0.0);

    // Calling resetPan again when already centered is a no-op.
    await provider.resetPan();
    expect(notifications, 1);
  });
}
