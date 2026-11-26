import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/app/background/background_sync.dart';
import 'package:JWHelper/infrastructure/notifications/notification_service.dart';
import 'package:JWHelper/infrastructure/platform/widget_permission_service.dart';

/// 「通知与提醒自检」：把「为什么收不到提醒」需要看的几项一次列出来。
///
/// 同学反馈的「课前提醒不响、打开 App 才一起弹」基本都是权限或系统省电策略
/// 导致的，把这些状态摆出来比让用户猜要省事。
class ReminderDiagnosticsTile extends StatefulWidget {
  const ReminderDiagnosticsTile({super.key, required this.accentColor});

  final Color accentColor;

  @override
  State<ReminderDiagnosticsTile> createState() => _ReminderDiagnosticsTileState();
}

class _ReminderDiagnosticsTileState extends State<ReminderDiagnosticsTile> {
  WidgetPermissionStatus? _status;
  bool _classReminderEnabled = true;
  bool _noticePolling = false;
  int _scheduledCount = 0;
  DateTime? _nextAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await WidgetPermissionService.getStatus();
    final notification = NotificationService();
    final enabled = await notification.isEnabled;
    final prefs = await SharedPreferences.getInstance();

    final count = prefs.getInt('class_reminder_count') ?? 0;
    final nextMillis = prefs.getInt('class_reminder_next_at');
    final noticePolling = await BackgroundSync.isNoticePollingEnabled();

    if (!mounted) return;
    setState(() {
      _status = status;
      _classReminderEnabled = enabled;
      _noticePolling = noticePolling;
      _scheduledCount = count;
      _nextAt = nextMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(nextMillis);
    });
  }

  String _formatTime(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  String get _subtitle {
    final status = _status;
    if (status == null) return '正在检查权限与排程…';
    if (!status.notificationReady) return '通知权限未开启，提醒不会显示';
    if (!status.exactAlarmReady) return '未授予「闹钟和提醒」，提醒可能延迟';
    if (!_classReminderEnabled) return '课前提醒开关已关闭';
    if (_scheduledCount == 0) return '当前没有待发送的课前提醒';
    final next = _nextAt == null ? '' : '，下一条 ${_formatTime(_nextAt!)}';
    return '已排 $_scheduledCount 条课前提醒$next';
  }

  Future<void> _showDetails() async {
    await _load();
    if (!mounted) return;
    final status = _status;

    await showDialog<void>(
      context: context,
      builder: (context) {
        Widget row(String label, String value, {Color? color}) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(fontSize: 13, color: color),
                  ),
                ),
              ],
            ),
          );
        }

        final scheme = Theme.of(context).colorScheme;
        final ok = scheme.primary;
        final bad = scheme.error;

        return AlertDialog(
          title: const Text('通知与提醒自检'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row(
                  '通知权限',
                  status == null
                      ? '未知'
                      : (status.notificationReady ? '已允许' : '未允许'),
                  color: status == null
                      ? null
                      : (status.notificationReady ? ok : bad),
                ),
                row(
                  '精确闹钟',
                  status == null
                      ? '未知'
                      : (!status.exactAlarmRequired
                          ? '系统无需授权'
                          : (status.canScheduleExactAlarms ? '已允许' : '未允许')),
                  color: status == null
                      ? null
                      : (status.exactAlarmReady ? ok : bad),
                ),
                row('课前提醒开关', _classReminderEnabled ? '已开启' : '已关闭',
                    color: _classReminderEnabled ? ok : bad),
                row('已排提醒', '$_scheduledCount 条'),
                row('下一条提醒',
                    _nextAt == null ? '无' : _formatTime(_nextAt!)),
                row('通知后台轮询', _noticePolling ? '已开启' : '未开启'),
                const SizedBox(height: 10),
                Text(
                  '提示：Android 12+ 需要「闹钟和提醒」权限课前提醒才能准点；'
                  '小米 / 红米等机型还需允许自启动、关闭省电限制，否则锁屏后提醒可能被拦。'
                  'iOS 的后台任务由系统调度，不保证准时。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.pop(context);
              },
              child: const Text('去系统设置'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final hasProblem = status != null &&
        (!status.notificationReady ||
            !status.exactAlarmReady ||
            !_classReminderEnabled);

    return ListTile(
      leading: Icon(
        hasProblem ? Icons.error_outline : Icons.fact_check_outlined,
        color: hasProblem
            ? Theme.of(context).colorScheme.error
            : widget.accentColor,
      ),
      title: const Text('通知与提醒自检'),
      subtitle: Text(_subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
      onTap: _showDetails,
    );
  }
}
