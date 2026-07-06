import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/app/update/update_release_merger.dart';

void main() {
  const github14 = ParsedRelease(
    platform: ReleasePlatform.github,
    version: '1.4.0',
    releaseNotes: 'github notes',
    downloadUrl: 'https://github.com/example/app.apk',
  );

  const gitee14 = ParsedRelease(
    platform: ReleasePlatform.gitee,
    version: '1.4.0',
    releaseNotes: 'gitee notes',
    downloadUrl: 'https://gitee.com/example/app.apk',
  );

  const gitee13 = ParsedRelease(
    platform: ReleasePlatform.gitee,
    version: '1.3.0',
    releaseNotes: 'gitee old',
    downloadUrl: 'https://gitee.com/example/old.apk',
  );

  const github15 = ParsedRelease(
    platform: ReleasePlatform.github,
    version: '1.5.0',
    releaseNotes: 'github newer',
    downloadUrl: 'https://github.com/example/new.apk',
  );

  test('equal versions prefer gitee download', () {
    final merged = mergeReleases(github: github14, gitee: gitee14);
    expect(merged.latestVersion, '1.4.0');
    expect(merged.downloadPlatform, ReleasePlatform.gitee);
    expect(merged.downloadUrl, gitee14.downloadUrl);
    expect(merged.releaseNotes, 'gitee notes');
  });

  test('gitee lower than github uses github download', () {
    final merged = mergeReleases(github: github15, gitee: gitee13);
    expect(merged.latestVersion, '1.5.0');
    expect(merged.downloadPlatform, ReleasePlatform.github);
    expect(merged.downloadUrl, github15.downloadUrl);
    expect(merged.releaseNotes, 'github newer');
  });

  test('gitee higher than github uses gitee download', () {
    final merged = mergeReleases(
      github: gitee13.copyWith(
        platform: ReleasePlatform.github,
        version: '1.2.0',
      ),
      gitee: github15.copyWith(
        platform: ReleasePlatform.gitee,
        downloadUrl: 'https://gitee.com/example/new.apk',
      ),
    );
    expect(merged.latestVersion, '1.5.0');
    expect(merged.downloadPlatform, ReleasePlatform.gitee);
  });

  test('single source fallback', () {
    final merged = mergeReleases(github: github14, gitee: null);
    expect(merged.downloadPlatform, ReleasePlatform.github);
    expect(merged.downloadUrl, github14.downloadUrl);
  });

  test('throws when both sources unavailable', () {
    expect(() => mergeReleases(github: null, gitee: null), throwsException);
  });

  test('isNewerVersion compares semver triples', () {
    expect(isNewerVersion('1.4.1', '1.4.0'), isTrue);
    expect(isNewerVersion('1.4.0', '1.4.0'), isFalse);
    expect(isNewerVersion('1.3.9', '1.4.0'), isFalse);
  });
}

extension _ParsedReleaseCopy on ParsedRelease {
  ParsedRelease copyWith({
    ReleasePlatform? platform,
    String? version,
    String? releaseNotes,
    String? downloadUrl,
  }) {
    return ParsedRelease(
      platform: platform ?? this.platform,
      version: version ?? this.version,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }
}
