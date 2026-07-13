import 'dart:io';

import 'package:flutter/material.dart';
import 'package:JWHelper/infrastructure/platform/widget_permission_service.dart';

class WidgetSettingsSheet extends StatefulWidget {
  const WidgetSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const WidgetSettingsSheet(),
    );
  }

  @override
  State<WidgetSettingsSheet> createState() => _WidgetSettingsSheetState();
}

class _WidgetSettingsSheetState extends State<WidgetSettingsSheet>
    with WidgetsBindingObserver {
  late Future<_WidgetPermissionSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  void _refresh() {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
  }

  Future<_WidgetPermissionSnapshot> _loadSnapshot() async {
    final status = await WidgetPermissionService.getStatus();
    final requirements = await WidgetPermissionService.getUnmetRequirements();
    return _WidgetPermissionSnapshot(
      status: status,
      requirements: requirements,
    );
  }

  Future<void> _request(WidgetPermissionType type) async {
    final granted = await WidgetPermissionService.requestRequirement(type);
    if (!mounted) return;

    if (granted && type != WidgetPermissionType.autostart) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_grantedMessage(type))),
      );
    } else if (type == WidgetPermissionType.autostart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请在自启动列表中开启教务小助手')),
      );
    }

    _refresh();
  }

  String _grantedMessage(WidgetPermissionType type) {
    switch (type) {
      case WidgetPermissionType.exactAlarm:
        return '闹钟权限已允许';
      case WidgetPermissionType.notification:
        return '通知（提醒）权限已允许';
      case WidgetPermissionType.autostart:
        return '已打开自启动设置';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '桌面小组件',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              WidgetPermissionService.platformGuideText(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            const _WidgetInfoTile(
              icon: Icons.calendar_today_outlined,
              title: '今日课表',
              subtitle: '显示当前/下一节课，考试周自动切换为考试安排',
            ),
            const SizedBox(height: 8),
            _WidgetInfoTile(
              icon: Icons.school_outlined,
              title: Platform.isIOS ? '绩点与学分' : '学业进度',
              subtitle: '展示绩点与学分完成情况',
            ),
            const SizedBox(height: 16),
            FutureBuilder<_WidgetPermissionSnapshot>(
              future: _snapshotFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data;
                if (data == null) {
                  return const SizedBox.shrink();
                }

                if (!Platform.isAndroid) {
                  return const Card(
                    elevation: 0,
                    child: ListTile(
                      leading: Icon(Icons.verified_outlined),
                      title: Text('权限状态'),
                      subtitle: Text('iOS 小组件无需额外系统权限，打开 App 即可同步数据'),
                    ),
                  );
                }

                return Column(
                  children: [
                    _PermissionStatusTile(
                      title: '闹钟',
                      subtitle: data.status.exactAlarmRequired
                          ? (data.status.canScheduleExactAlarms
                              ? '已允许，课表可定时刷新'
                              : '未允许，课表可能无法按时刷新')
                          : '当前系统版本无需单独授权',
                      granted: data.status.exactAlarmReady,
                      actionLabel: data.status.exactAlarmReady ? null : '去开启',
                      onAction: data.status.exactAlarmReady
                          ? null
                          : () => _request(WidgetPermissionType.exactAlarm),
                    ),
                    const SizedBox(height: 8),
                    _PermissionStatusTile(
                      title: '通知（提醒）',
                      subtitle: data.status.notificationRequired
                          ? (data.status.notificationGranted
                              ? '已允许'
                              : '未允许，HyperOS 上常显示为「提醒」')
                          : '当前系统版本无需单独授权',
                      granted: data.status.notificationReady,
                      actionLabel: data.status.notificationReady ? null : '去开启',
                      onAction: data.status.notificationReady
                          ? null
                          : () => _request(WidgetPermissionType.notification),
                    ),
                    if (data.status.isXiaomiFamily) ...[
                      const SizedBox(height: 8),
                      _PermissionStatusTile(
                        title: '自启动',
                        subtitle: 'HyperOS 无法自动检测，请手动确认已开启',
                        granted: null,
                        actionLabel: '去设置',
                        onAction: () => _request(WidgetPermissionType.autostart),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              '若小组件显示空白或「--」，请先登录并打开 App 同步一次数据。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WidgetPermissionSnapshot {
  const _WidgetPermissionSnapshot({
    required this.status,
    required this.requirements,
  });

  final WidgetPermissionStatus status;
  final List<WidgetPermissionRequirement> requirements;
}

class _PermissionStatusTile extends StatelessWidget {
  const _PermissionStatusTile({
    required this.title,
    required this.subtitle,
    required this.granted,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final bool? granted;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final Color? leadingColor;
    final IconData leadingIcon;
    if (granted == null) {
      leadingColor = Theme.of(context).colorScheme.primary;
      leadingIcon = Icons.info_outline;
    } else if (granted!) {
      leadingColor = Theme.of(context).colorScheme.primary;
      leadingIcon = Icons.check_circle_outline;
    } else {
      leadingColor = Theme.of(context).colorScheme.error;
      leadingIcon = Icons.error_outline;
    }

    return Card(
      elevation: 0,
      color: granted == false
          ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35)
          : null,
      child: ListTile(
        leading: Icon(leadingIcon, color: leadingColor),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: actionLabel == null
            ? null
            : FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
      ),
    );
  }
}

class _WidgetInfoTile extends StatelessWidget {
  const _WidgetInfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
