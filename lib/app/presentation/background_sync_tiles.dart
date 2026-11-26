import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:JWHelper/app/background/background_sync.dart';

/// 设置里的「后台轮询」两个开关。
///
/// 拆成独立组件是因为主设置弹窗里已经有十几个条目，直接塞 FutureBuilder +
/// StatefulBuilder 会让那段代码更难读；这里自己维护加载与切换状态。
class BackgroundSyncTiles extends StatefulWidget {
  const BackgroundSyncTiles({super.key, required this.accentColor});

  final Color accentColor;

  @override
  State<BackgroundSyncTiles> createState() => _BackgroundSyncTilesState();
}

class _BackgroundSyncTilesState extends State<BackgroundSyncTiles> {
  bool? _noticeEnabled;
  bool? _classEnabled;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notice = await BackgroundSync.isNoticePollingEnabled();
    final klass = await BackgroundSync.isClassPollingEnabled();
    if (!mounted) return;
    setState(() {
      _noticeEnabled = notice;
      _classEnabled = klass;
    });
  }

  Future<bool> _ensureNotificationPermission() async {
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      status = await Permission.notification.request();
    }
    if (status.isGranted) return true;

    if (!mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要通知权限'),
        content: const Text(
          '后台轮询发现新通知或需要提醒上课时，要发本地通知。请允许「教务小助手」发送通知。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _toggleNotice(bool value) async {
    if (value && !await _ensureNotificationPermission()) return;
    await BackgroundSync.setNoticePollingEnabled(value);
    if (!mounted) return;
    setState(() => _noticeEnabled = value);
  }

  Future<void> _toggleClass(bool value) async {
    if (value && !await _ensureNotificationPermission()) return;
    await BackgroundSync.setClassPollingEnabled(value);
    if (!mounted) return;
    setState(() => _classEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supported = BackgroundSync.isSupported;

    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(Icons.sync, color: widget.accentColor),
          title: const Text('通知后台轮询'),
          subtitle: const Text(
            '约每小时检查一次学校通知，有新通知时提醒',
            style: TextStyle(fontSize: 12),
          ),
          value: _noticeEnabled ?? false,
          activeThumbColor: theme.colorScheme.secondary,
          onChanged: !supported || _noticeEnabled == null
              ? null
              : (value) => _toggleNotice(value),
        ),
        SwitchListTile(
          secondary: Icon(Icons.alarm_on, color: widget.accentColor),
          title: const Text('课程提醒后台轮询'),
          subtitle: const Text(
            '定期续排未来两周的课前提醒，App 不打开也不中断',
            style: TextStyle(fontSize: 12),
          ),
          value: _classEnabled ?? false,
          activeThumbColor: theme.colorScheme.secondary,
          onChanged: !supported || _classEnabled == null
              ? null
              : (value) => _toggleClass(value),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            supported
                ? '后台轮询由系统调度，实际时间可能被推迟；iOS 上不保证按小时执行。'
                : '当前平台不支持后台轮询（仅 Android / iOS）。',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
