import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:JWHelper/app/update/release_notes_view.dart';
import 'package:JWHelper/app/update/update_release_merger.dart';

class UpdateUiState {
  final bool checking;
  final bool hasUpdate;
  final String? latestVersion;
  final String? releaseNotes;
  final String? downloadUrl;
  final String? error;
  final double? progress;
  final String? message;

  const UpdateUiState({
    this.checking = false,
    this.hasUpdate = false,
    this.latestVersion,
    this.releaseNotes,
    this.downloadUrl,
    this.error,
    this.progress,
    this.message,
  });

  UpdateUiState copyWith({
    bool? checking,
    bool? hasUpdate,
    String? latestVersion,
    String? releaseNotes,
    String? downloadUrl,
    String? error,
    double? progress,
    String? message,
    bool clearMessage = false,
    bool clearError = false,
    bool clearProgress = false,
  }) {
    return UpdateUiState(
      checking: checking ?? this.checking,
      hasUpdate: hasUpdate ?? this.hasUpdate,
      latestVersion: latestVersion ?? this.latestVersion,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      error: clearError ? null : (error ?? this.error),
      progress: clearProgress ? null : (progress ?? this.progress),
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

class UpdateCheckResult {
  final bool hasUpdate;
  final String latestVersion;
  final String currentVersion;
  final String releaseNotes;
  final String? downloadUrl;

  UpdateCheckResult({
    required this.hasUpdate,
    required this.latestVersion,
    required this.currentVersion,
    required this.releaseNotes,
    this.downloadUrl,
  });
}

class UpdateService {
  final Dio _dio = Dio(
    BaseOptions(
      headers: const {
        'User-Agent': 'JWHelper-App',
        'Accept': 'application/vnd.github+json',
      },
    ),
  );

  static const String _githubLatestApi =
      'https://api.github.com/repos/Sdpei-CTCA/JWHelper/releases/latest';
  static const String _giteeLatestApi =
      'https://gitee.com/api/v5/repos/SpongeFun/JWHelper/releases/latest';
  static const String _giteeReleasesPage =
      'https://gitee.com/SpongeFun/JWHelper/releases';

  final ValueNotifier<UpdateUiState> updateState =
      ValueNotifier(const UpdateUiState());
  String currentVersion = '';

  Future<void> init() async {
    currentVersion = await getCurrentVersion();
    checkForUpdates(silent: true);
  }

  void dispose() {
    updateState.dispose();
  }

  Future<void> checkForUpdates({bool silent = false}) async {
    if (updateState.value.checking) return;

    updateState.value = updateState.value.copyWith(
      checking: true,
      clearError: !silent,
      clearMessage: !silent,
    );

    try {
      final result = await checkUpdate();

      if (!result.hasUpdate) {
        updateState.value = updateState.value.copyWith(
          checking: false,
          hasUpdate: false,
          latestVersion: result.latestVersion,
          releaseNotes: result.releaseNotes,
          downloadUrl: null,
          message: (!silent) ? '当前已是最新版本' : null,
        );
        return;
      }

      updateState.value = updateState.value.copyWith(
        checking: false,
        hasUpdate: true,
        latestVersion: result.latestVersion,
        releaseNotes: result.releaseNotes,
        downloadUrl: result.downloadUrl,
        clearMessage: true,
        clearError: true,
      );
    } catch (e) {
      updateState.value = updateState.value.copyWith(
        checking: false,
        error: e.toString(),
      );
    }
  }

  Future<String> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '';
    }
  }

  Future<UpdateCheckResult> checkUpdate() async {
    final currentVersion = await getCurrentVersion();

    final results = await Future.wait([
      _fetchGithubRelease(),
      _fetchGiteeRelease(),
    ]);

    final github = results[0];
    final gitee = results[1];
    final merged = mergeReleases(github: github, gitee: gitee);
    final hasNew = isNewerVersion(merged.latestVersion, currentVersion);

    return UpdateCheckResult(
      hasUpdate: hasNew,
      latestVersion: merged.latestVersion,
      currentVersion: currentVersion,
      releaseNotes: merged.releaseNotes,
      downloadUrl: merged.downloadUrl ?? _fallbackReleasePage(merged.downloadPlatform),
    );
  }

  Future<ParsedRelease?> _fetchGithubRelease() async {
    try {
      final response = await _dio.get(_githubLatestApi);
      return _parseReleaseData(
        response.data as Map<String, dynamic>,
        platform: ReleasePlatform.github,
      );
    } catch (_) {
      return null;
    }
  }

  Future<ParsedRelease?> _fetchGiteeRelease() async {
    try {
      final response = await _dio.get(_giteeLatestApi);
      return _parseReleaseData(
        response.data as Map<String, dynamic>,
        platform: ReleasePlatform.gitee,
      );
    } catch (_) {
      return null;
    }
  }

  Future<ParsedRelease?> _parseReleaseData(
    Map<String, dynamic> data, {
    required ReleasePlatform platform,
  }) async {
    final tag = data['tag_name'] as String?;
    final name = data['name'] as String?;
    final version =
        _extractVersionFromText(tag) ?? _extractVersionFromText(name);

    if (version == null) return null;

    final assets = (data['assets'] as List<dynamic>?) ?? [];
    final assetUrl = await _pickAssetUrl(assets);
    final releaseNotes = data['body'] as String? ?? '';

    return ParsedRelease(
      platform: platform,
      version: version,
      releaseNotes: releaseNotes,
      downloadUrl: assetUrl,
    );
  }

  String _fallbackReleasePage(ReleasePlatform platform) {
    return platform == ReleasePlatform.gitee
        ? _giteeReleasesPage
        : 'https://github.com/Sdpei-CTCA/JWHelper/releases';
  }

  Future<void> downloadAndInstallApk({
    required String url,
    required String version,
    required Function(double) onProgress,
    required Function(String) onSaved,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw Exception('仅支持在 Android 设备上下载 APK');
    }

    final dir = await getTemporaryDirectory();
    final fileName = 'JWHelper-$version.apk';
    final savePath = '${dir.path}/$fileName';

    await _dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        onProgress(received / total);
      },
    );

    final opened = await launchUrl(
      Uri.file(savePath),
      mode: LaunchMode.externalApplication,
    );

    if (!opened) {
      onSaved(savePath);
    }
  }

  // Helper methods
  String? _extractVersionFromText(String? text) {
    if (text == null) return null;
    final match = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(text);
    if (match == null) return null;
    return '${match.group(1)}.${match.group(2)}.${match.group(3)}';
  }

  bool _isApkAsset(String name) => name.toLowerCase().endsWith('.apk');

  Future<String?> _pickAssetUrl(List<dynamic> assets) async {
    if (assets.isEmpty) return null;

    String? findForPattern(String pattern) {
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = asset['name'] as String? ?? '';
          if (!_isApkAsset(name)) continue;
          if (name.toLowerCase().contains(pattern.toLowerCase())) {
            return asset['browser_download_url'] as String?;
          }
        }
      }
      return null;
    }

    List<String> supportedAbis = [];
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        supportedAbis = androidInfo.supportedAbis;
      } catch (_) {}
    }

    for (final abi in supportedAbis) {
      final url = findForPattern(abi);
      if (url != null) return url;
    }

    const fallbackOrder = ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'];
    for (final pattern in fallbackOrder) {
      final url = findForPattern(pattern);
      if (url != null) return url;
    }

    for (final asset in assets) {
      if (asset is Map<String, dynamic>) {
        final name = asset['name'] as String? ?? '';
        if (!_isApkAsset(name)) continue;
        final url = asset['browser_download_url'] as String?;
        if (url != null) return url;
      }
    }
    return null;
  }

  Widget buildAboutIcon() {
    return ValueListenableBuilder<UpdateUiState>(
      valueListenable: updateState,
      builder: (context, state, child) {
        final icon = Icon(Icons.settings, color: Theme.of(context).colorScheme.primary);
        if (!state.hasUpdate) return icon;
        return Badge(
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          smallSize: 10,
          offset: const Offset(8, -8),
          child: icon,
        );
      },
    );
  }

  Future<void> performDownload(BuildContext context) async {
    final state = updateState.value;
    if (state.downloadUrl == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到可用的下载链接')),
        );
      }
      return;
    }

    final url = state.downloadUrl!;

    try {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开下载链接: $e')),
        );
      }
    }
  }

  Widget buildUpdateSection(BuildContext context) {
    return ValueListenableBuilder<UpdateUiState>(
      valueListenable: updateState,
      builder: (context, state, child) {
        if (state.checking) {
          return const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              SizedBox(width: 8),
              Text('正在检查更新...'),
            ],
          );
        }

        if (state.hasUpdate) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.new_releases, color: Theme.of(context).colorScheme.tertiary),
                  const SizedBox(width: 6),
                  Text('发现新版本 v${state.latestVersion ?? ''}'),
                ],
              ),
              const SizedBox(height: 6),
              if ((state.releaseNotes ?? '').isNotEmpty)
                ReleaseNotesView(markdown: state.releaseNotes!),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => performDownload(context),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('去浏览器下载'),
              ),
              TextButton.icon(
                onPressed: () => checkForUpdates(silent: false),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重新检查'),
              ),
            ],
          );
        }

        return Column(
          children: [
            FilledButton.icon(
              onPressed: () => checkForUpdates(silent: false),
              icon: const Icon(Icons.system_update_alt),
              label: const Text('检查更新'),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 6),
              Text(
                state.error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            if (state.message != null) ...[
              const SizedBox(height: 6),
              Text(
                state.message!,
                style: const TextStyle(color: Colors.green, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> downloadLatestApk({
    required BuildContext context,
    required String? downloadUrl,
    required String? latestVersion,
    required Function(double?) onProgress,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('仅支持在 Android 设备上下载 APK')),
        );
      }
      return;
    }

    if (downloadUrl == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到可用的下载链接')),
        );
      }
      return;
    }

    onProgress(0);
    try {
      await downloadAndInstallApk(
        url: downloadUrl,
        version: latestVersion ?? 'latest',
        onProgress: (progress) {
          if (context.mounted) {
            onProgress(progress);
          }
        },
        onSaved: (path) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已下载到: $path')),
            );
          }
        },
      );

      if (context.mounted) {
        onProgress(null);
      }
    } catch (e) {
      if (context.mounted) {
        onProgress(null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败：$e')),
        );
      }
    }
  }
}
