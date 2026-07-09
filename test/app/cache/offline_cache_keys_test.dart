import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/app/cache/offline_cache_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineCacheKeys', () {
    test('hasOfflineCache returns true when grades cache exists', () async {
      SharedPreferences.setMockInitialValues({
        'grades_cache_2021001': '[{"semester":"2024-2025-1"}]',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(OfflineCacheKeys.hasOfflineCache(prefs, '2021001'), isTrue);
      expect(OfflineCacheKeys.hasOfflineCache(prefs, '2021002'), isFalse);
      expect(OfflineCacheKeys.hasOfflineCache(prefs, ''), isFalse);
    });

    test('hasOfflineCache detects exam caches by username suffix', () async {
      SharedPreferences.setMockInitialValues({
        'exams_2024_1_2021001': '[{"name":"高等数学"}]',
        'exams_2024_1_2021002': '[{"name":"英语"}]',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(OfflineCacheKeys.hasOfflineCache(prefs, '2021001'), isTrue);
      expect(OfflineCacheKeys.hasOfflineCache(prefs, '2021002'), isTrue);
      expect(OfflineCacheKeys.hasOfflineCache(prefs, '202100'), isFalse);
    });

    test('belongsToUser rejects empty username', () {
      expect(OfflineCacheKeys.belongsToUser('grades_cache_2021001', ''), isFalse);
      expect(OfflineCacheKeys.belongsToUser('grades_cache_2021001', '2021001'),
          isTrue);
    });
  });
}
