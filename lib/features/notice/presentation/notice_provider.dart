import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_provider.dart';
import 'package:JWHelper/features/notice/data/notice_cache_store.dart';
import 'package:JWHelper/features/notice/data/notice_source.dart';
import 'package:JWHelper/features/notice/data/pubinfo_notice_source.dart';
import 'package:JWHelper/features/notice/domain/notice_detail.dart';
import 'package:JWHelper/features/notice/domain/notice_item.dart';
import 'package:JWHelper/infrastructure/notifications/notification_service.dart';

/// 通知公告的全局状态。
///
/// 登录态直接复用考勤模块的智慧山体 SSO（[AttendanceProvider]）：同一套统一
/// 认证，同一份 `CTTICKET`。因此「没绑定智慧考勤账号」时通知也读不了，界面会
/// 引导用户去绑定，而不是假装空列表。
class NoticeProvider with ChangeNotifier {
  NoticeProvider({
    NoticeSource? source,
    NoticeCacheStore? store,
    NotificationService? notifications,
  })  : _source = source ?? PubinfoNoticeSource(),
        _store = store ?? NoticeCacheStore(),
        _notifications = notifications ?? NotificationService();

  /// 后台静默检查的最小间隔：太频繁会白白耗流量，也会让「新通知」提醒变噪音。
  static const Duration backgroundCheckInterval = Duration(minutes: 20);
  static const int _maxDetailCacheEntries = 20;
  static const int _maxImageCacheEntries = 24;
  static const int _maxImageCacheBytes = 24 * 1024 * 1024;
  static final RegExp _unsafeFileNameRe = RegExp(r'[\\/:*?"<>|]');

  final NoticeSource _source;
  final NoticeCacheStore _store;
  final NotificationService _notifications;

  AttendanceProvider? _auth;
  String _username = '';

  List<NoticeItem> _items = const [];
  Set<String> _readIds = <String>{};
  Set<String> _knownIds = <String>{};
  final LinkedHashMap<String, NoticeDetail> _detailCache = LinkedHashMap();
  final LinkedHashMap<String, Uint8List> _imageCache = LinkedHashMap();
  int _imageCacheBytes = 0;
  final Map<String, Future<Uint8List?>> _inFlightImages = {};

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasLoaded = false;
  bool _reminderEnabled = true;
  bool _initialized = false;
  bool _initializing = false;
  bool _disposed = false;

  String? _errorMessage;
  NoticeErrorKind? _errorKind;
  String _diagnostics = '';
  String _structureSummary = '';

  List<NoticeItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get hasLoaded => _hasLoaded;
  bool get reminderEnabled => _reminderEnabled;
  String? get errorMessage => _errorMessage;
  NoticeErrorKind? get errorKind => _errorKind;
  String get diagnostics => _diagnostics;

  /// 解析失败时的页面结构摘要；用户可一键复制反馈。
  String get structureSummary => _structureSummary;

  /// 当前账号已保存智慧山体账号密码（不论是否校验通过）。
  bool get hasCredentials => _auth?.hasSavedCredentials ?? false;

  int get unreadCount {
    if (_readIds.isEmpty) return _items.length;
    return _items.where((e) => !_readIds.contains(e.id)).length;
  }

  /// 由 `ChangeNotifierProxyProvider` 在每次依赖更新时调用。
  ///
  /// 考勤页里改绑账号后 `AttendanceProvider` 会通知一次，这里要跟着重新按新
  /// 账号初始化（换人后不能沿用上一个人的已读状态），因此不能只在首次调用时
  /// 才干活。
  void attachAuth(AttendanceProvider auth) {
    _auth = auth;
    unawaited(initialize());
  }

  /// 首次进入时读缓存；有账号的话再静默刷新一次。
  Future<void> initialize() async {
    final auth = _auth;
    if (auth == null || _initializing) return;

    _initializing = true;
    try {
      await auth.ensureLoaded();
      final username = auth.savedUsername;
      if (_initialized && username == _username) {
        return;
      }

      // 换绑了智慧山体账号：清空上一个人的列表、缓存与已读状态，避免串号。
      if (_initialized) {
        _items = const [];
        _readIds = <String>{};
        _knownIds = <String>{};
        _detailCache.clear();
        _imageCache.clear();
        _imageCacheBytes = 0;
        _inFlightImages.clear();
        _hasLoaded = false;
        _errorMessage = null;
        _errorKind = null;
        _diagnostics = '';
        _structureSummary = '';
      }

      _initialized = true;
      _username = username;
      final cachedResults = await Future.wait([
        _store.readReadIds(username),
        _store.readKnownIds(username),
        _store.readReminderEnabled(),
        _store.readList(username),
      ]);
      _readIds = cachedResults[0] as Set<String>;
      _knownIds = cachedResults[1] as Set<String>;
      _reminderEnabled = cachedResults[2] as bool;
      final cached = cachedResults[3] as List<NoticeItem>;
      if (cached.isNotEmpty) {
        _items = _applyReadFlags(cached);
        _hasLoaded = true;
        _notify();
      }

      // 有缓存时先展示缓存，再用后台刷新覆盖；没缓存则直接转圈加载。
      if (auth.hasSavedCredentials) {
        if (_items.isEmpty) {
          _isLoading = true;
          _notify();
        }
        await refresh(silent: _items.isNotEmpty);
      } else {
        _errorKind = NoticeErrorKind.notConfigured;
        _errorMessage = '还没绑定智慧山体账号，绑定后即可查看学校通知';
        _hasLoaded = true;
        _notify();
      }
    } finally {
      _initializing = false;
    }
  }

  /// 下拉刷新 / 首次加载。
  ///
  /// [silent] 为 true 时不显示整页 loading、不弹错误条（用于后台检查）。
  Future<void> refresh({bool silent = false}) async {
    if (_disposed) return;

    if (_isRefreshing) return;
    _isRefreshing = true;
    if (!silent) {
      _errorMessage = null;
      _errorKind = null;
    }
    _notify();

    try {
      await _authorize();
      _applyCredentials();

      final fetched = await _withAuthRetry(() => _source.fetchList());
      final source = _source;
      _diagnostics =
          source is PubinfoNoticeSource ? source.lastDiagnostics : '';

      final isFirstRun = _knownIds.isEmpty && _items.isEmpty;
      final freshIds = fetched
          .map((e) => e.id)
          .where((id) => !_knownIds.contains(id))
          .toSet();

      _items = _applyReadFlags(fetched);
      _hasLoaded = true;
      _errorMessage = null;
      _errorKind = null;

      _knownIds = {
        ..._knownIds,
        ...fetched.map((e) => e.id),
      };
      // 只保留最近的一批，避免 SharedPreferences 无限增长。
      if (_knownIds.length > 600) {
        _knownIds = fetched.map((e) => e.id).toSet();
      }

      await _store.saveList(_username, fetched);
      await _store.saveKnownIds(_username, _knownIds);
      await _store.saveLastCheckAt(DateTime.now());

      // 首次安装时把当前全部通知视为「已见过」，避免一进来就弹一堆提醒。
      if (!isFirstRun && freshIds.isNotEmpty && silent) {
        await _maybeNotify(freshIds.length, fetched.first.title);
      }
    } on NoticeException catch (e) {
      _captureSourceDiagnostics();
      // 后台静默刷新失败时不覆盖界面上已有的内容与错误提示：
      // 用户正看着缓存列表，不该因为一次网络抖动就变成整页报错。
      if (!silent || _items.isEmpty) {
        _errorKind = e.kind;
        _errorMessage = e.message;
      }
      debugPrint('Notice refresh failed (${e.kind.name}): ${e.message}');
      if (e.kind == NoticeErrorKind.notConfigured ||
          e.kind == NoticeErrorKind.authFailed) {
        _hasLoaded = true;
      }
    } catch (e) {
      if (!silent || _items.isEmpty) {
        _errorKind = NoticeErrorKind.network;
        _errorMessage = '加载通知失败：$e';
      }
      debugPrint('Notice refresh failed: $e');
    } finally {
      _isRefreshing = false;
      _isLoading = false;
      _notify();
    }
  }

  /// 后台检查：限流、无 UI 反馈，只在有新通知时弹一条本地提醒。
  ///
  /// 调用时机是「App 启动完成」与「从后台回到前台」，不引入后台任务插件。
  Future<void> checkForNewInBackground({bool force = false}) async {
    if (_disposed) return;
    if (_auth?.hasSavedCredentials != true) return;

    if (!force) {
      final last = await _store.readLastCheckAt();
      if (last != null &&
          DateTime.now().difference(last) < backgroundCheckInterval) {
        return;
      }
    }

    // 先记下尝试时间：失败（比如断网）也按节流算，避免每次回前台都重试。
    await _store.saveLastCheckAt(DateTime.now());
    await refresh(silent: true);
  }

  Future<void> markRead(NoticeItem item) async {
    if (_readIds.contains(item.id)) return;
    _readIds = {..._readIds, item.id};
    _items = _applyReadFlags(_items);
    await _store.saveReadIds(_username, _readIds);
    _notify();
  }

  Future<void> markAllRead() async {
    final ids = _items.map((e) => e.id).toSet();
    if (ids.isEmpty) return;
    _readIds = {..._readIds, ...ids};
    _items = _applyReadFlags(_items);
    await _store.saveReadIds(_username, _readIds);
    _notify();
  }

  Future<void> clearReadState() async {
    _readIds = <String>{};
    _items = _applyReadFlags(_items);
    await _store.clearReadState(_username);
    _notify();
  }

  Future<NoticeDetail> loadDetail(NoticeItem item) async {
    final cached = _detailCache.remove(item.id);
    if (cached != null) {
      _detailCache[item.id] = cached;
      return cached;
    }

    await _authorize();
    _applyCredentials();

    final detail = await _withAuthRetry(() => _source.fetchDetail(item));
    _putDetailCache(item.id, detail);
    return detail;
  }

  void _putDetailCache(String id, NoticeDetail detail) {
    _detailCache.remove(id);
    _detailCache[id] = detail;
    while (_detailCache.length > _maxDetailCacheEntries) {
      _detailCache.remove(_detailCache.keys.first);
    }
  }

  void _putImageCache(String url, Uint8List bytes) {
    final existing = _imageCache.remove(url);
    if (existing != null) {
      _imageCacheBytes -= existing.lengthInBytes;
    }
    if (bytes.lengthInBytes > _maxImageCacheBytes) {
      return;
    }
    _imageCache[url] = bytes;
    _imageCacheBytes += bytes.lengthInBytes;
    while (_imageCache.length > _maxImageCacheEntries ||
        _imageCacheBytes > _maxImageCacheBytes) {
      final oldestKey = _imageCache.keys.first;
      final removed = _imageCache.remove(oldestKey);
      if (removed != null) {
        _imageCacheBytes -= removed.lengthInBytes;
      }
    }
  }

  Future<Uint8List?> _fetchBytesWithAuthRetry(String url) async {
    _applyCredentials();
    var bytes = await _source.fetchBytes(url);

    // 首次失败多半是会话没建好：用保存的凭据重登一次再试。
    if (bytes == null && (_auth?.hasSavedCredentials ?? false)) {
      final error = await _auth?.ensureAuthorized(force: true);
      if (error == null) {
        _applyCredentials();
        bytes = await _source.fetchBytes(url);
      }
    }
    return bytes;
  }

  /// 下载正文图片（带登录态），有界 LRU 内存缓存一份；失败不缓存以便重试。
  Future<Uint8List?> loadImage(String url) {
    final cached = _imageCache.remove(url);
    if (cached != null) {
      _imageCache[url] = cached;
      return Future<Uint8List?>.value(cached);
    }

    final inFlight = _inFlightImages[url];
    if (inFlight != null) return inFlight;

    final future = () async {
      try {
        final bytes = await _fetchBytesWithAuthRetry(url);
        if (bytes != null && bytes.isNotEmpty) {
          _putImageCache(url, bytes);
        }
        return bytes;
      } catch (e) {
        debugPrint('Notice image load failed: $e');
        return null;
      } finally {
        _inFlightImages.remove(url);
      }
    }();

    _inFlightImages[url] = future;
    return future;
  }

  /// 下载附件到本地缓存目录，返回文件路径；失败返回 null。
  Future<String?> downloadAttachment(NoticeAttachment attachment) async {
    try {
      final bytes = await _fetchBytesWithAuthRetry(attachment.url);
      if (bytes == null || bytes.isEmpty) return null;

      final dir = await getTemporaryDirectory();
      final folder = Directory('${dir.path}/notice_attachments');
      await folder.create(recursive: true);

      final file = File('${folder.path}/${_safeFileName(attachment.name)}');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (e) {
      debugPrint('Notice attachment download failed: $e');
      return null;
    }
  }

  /// 文件名里去掉系统不接受的字符，避免写入失败；保留中文。
  String _safeFileName(String name) {
    final trimmed = name.trim();
    final cleaned = trimmed.replaceAll(_unsafeFileNameRe, '_');
    if (cleaned.isEmpty) return 'attachment';
    if (cleaned.length <= 80) return cleaned;
    final dot = cleaned.lastIndexOf('.');
    if (dot <= 0 || cleaned.length - dot > 8) return cleaned.substring(0, 80);
    final ext = cleaned.substring(dot);
    return '${cleaned.substring(0, 80 - ext.length)}$ext';
  }

  Future<void> setReminderEnabled(bool value) async {
    _reminderEnabled = value;
    await _store.saveReminderEnabled(value);
    _notify();
  }

  void _applyCredentials() {
    _source.updateCredentials(
      userToken: _auth?.userToken ?? '',
      ctTicket: _auth?.ctTicket ?? '',
      appCtTicket: _auth?.appCtTicket ?? '',
    );
  }

  /// 把数据源里的诊断信息同步到状态层，供「复制诊断」使用。
  void _captureSourceDiagnostics() {
    final source = _source;
    if (source is! PubinfoNoticeSource) return;
    if (source.lastDiagnostics.isNotEmpty) {
      _diagnostics = source.lastDiagnostics;
    }
    _structureSummary = source.lastStructureSummary;
  }

  /// 票据被通知平台拒绝时，强制重登一次再试。
  ///
  /// 与考勤页的 `withAuthRetry` 同思路：缓存的统一认证令牌放几天后失效是最
  /// 常见的失败原因，重登一次通常就好了，不该直接把错误甩给用户。
  Future<T> _withAuthRetry<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on NoticeException catch (e) {
      if (e.kind != NoticeErrorKind.authFailed) rethrow;
      final auth = _auth;
      if (auth == null) rethrow;

      debugPrint('Notice ticket rejected, re-authorizing once: ${e.message}');
      final error = await auth.ensureAuthorized(force: true);
      if (error != null) rethrow;

      _applyCredentials();
      return action();
    }
  }

  Future<String?> _authorize() async {
    final auth = _auth;
    if (auth == null) {
      throw const NoticeException(
        NoticeErrorKind.notConfigured,
        '还没绑定智慧山体账号，绑定后即可查看学校通知',
      );
    }

    await auth.ensureLoaded();
    if (!auth.hasSavedCredentials) {
      throw const NoticeException(
        NoticeErrorKind.notConfigured,
        '还没绑定智慧山体账号，绑定后即可查看学校通知',
      );
    }

    final error = await auth.ensureAuthorizedWithRecovery();
    if (error != null) {
      throw NoticeException(
        NoticeErrorKind.authFailed,
        error.isEmpty ? '统一认证登录失败，请重新登录' : error,
      );
    }
    return null;
  }

  Future<void> _maybeNotify(int count, String latestTitle) async {
    if (!_reminderEnabled || count <= 0) return;

    final today = _dayKey(DateTime.now());
    final lastDay = await _store.readLastNotifyDay();
    if (lastDay == today) return;

    await _notifications.showNoticeSummary(
      count: count,
      latestTitle: latestTitle,
    );
    await _store.saveLastNotifyDay(today);
  }

  List<NoticeItem> _applyReadFlags(List<NoticeItem> items) {
    return items
        .map((e) => e.copyWith(isRead: _readIds.contains(e.id)))
        .toList(growable: false);
  }

  String _dayKey(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '${time.year}-$month-$day';
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
