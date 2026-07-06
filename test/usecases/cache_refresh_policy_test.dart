import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/app/usecases/cache_refresh_policy.dart';

void main() {
  group('CacheRefreshPolicy', () {
    test('shouldReadDiskCache returns true when not force refreshing', () {
      expect(CacheRefreshPolicy.shouldReadDiskCache(false), isTrue);
    });

    test('shouldReadDiskCache returns false when force refreshing', () {
      expect(CacheRefreshPolicy.shouldReadDiskCache(true), isFalse);
    });

    test('shouldFallbackOnEmpty returns true when not force refreshing', () {
      expect(CacheRefreshPolicy.shouldFallbackOnEmpty(false), isTrue);
    });

    test('shouldFallbackOnEmpty returns false when force refreshing', () {
      expect(CacheRefreshPolicy.shouldFallbackOnEmpty(true), isFalse);
    });
  });
}
