enum ReleasePlatform { github, gitee }

class ParsedRelease {
  final ReleasePlatform platform;
  final String version;
  final String releaseNotes;
  final String? downloadUrl;

  const ParsedRelease({
    required this.platform,
    required this.version,
    required this.releaseNotes,
    this.downloadUrl,
  });
}

class MergedUpdateInfo {
  final String latestVersion;
  final String releaseNotes;
  final String? downloadUrl;
  final ReleasePlatform downloadPlatform;

  const MergedUpdateInfo({
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.downloadPlatform,
  });
}

int compareVersions(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 0;
  if (a.isEmpty) return -1;
  if (b.isEmpty) return 1;

  final aParts = a.split('.').map(int.parse).toList();
  final bParts = b.split('.').map(int.parse).toList();
  for (int i = 0; i < 3; i++) {
    if (aParts[i] > bParts[i]) return 1;
    if (aParts[i] < bParts[i]) return -1;
  }
  return 0;
}

bool isNewerVersion(String latest, String current) {
  return compareVersions(latest, current) > 0;
}

ParsedRelease pickHigherRelease(ParsedRelease a, ParsedRelease b) {
  final cmp = compareVersions(a.version, b.version);
  if (cmp > 0) return a;
  if (cmp < 0) return b;
  return a.platform == ReleasePlatform.gitee ? a : b;
}

MergedUpdateInfo mergeReleases({
  required ParsedRelease? github,
  required ParsedRelease? gitee,
}) {
  if (github == null && gitee == null) {
    throw Exception('GitHub 与 Gitee 均无法获取发布信息');
  }

  final available = <ParsedRelease>[
    if (github != null) github,
    if (gitee != null) gitee,
  ];

  final highest = available.reduce(pickHigherRelease);

  final ReleasePlatform downloadPlatform;
  if (gitee != null && gitee.downloadUrl != null) {
    if (github == null ||
        compareVersions(gitee.version, github.version) >= 0) {
      downloadPlatform = ReleasePlatform.gitee;
    } else {
      downloadPlatform = ReleasePlatform.github;
    }
  } else if (github != null && github.downloadUrl != null) {
    downloadPlatform = ReleasePlatform.github;
  } else {
    downloadPlatform = highest.platform;
  }

  final downloadRelease = switch (downloadPlatform) {
    ReleasePlatform.gitee => gitee!,
    ReleasePlatform.github => github!,
  };

  final releaseNotes = highest.releaseNotes.isNotEmpty
      ? highest.releaseNotes
      : downloadRelease.releaseNotes;

  return MergedUpdateInfo(
    latestVersion: highest.version,
    releaseNotes: releaseNotes,
    downloadUrl: downloadRelease.downloadUrl,
    downloadPlatform: downloadPlatform,
  );
}
