import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:permission_handler/permission_handler.dart';

enum WidgetPermissionType { exactAlarm, notification, autostart }

class WidgetPermissionStatus {
  const WidgetPermissionStatus({
    required this.canScheduleExactAlarms,
    required this.exactAlarmRequired,
    required this.notificationGranted,
    required this.notificationRequired,
    required this.isXiaomiFamily,
    required this.sdkInt,
  });

  final bool canScheduleExactAlarms;
  final bool exactAlarmRequired;
  final bool notificationGranted;
  final bool notificationRequired;
  final bool isXiaomiFamily;
  final int sdkInt;

  bool get exactAlarmReady => !exactAlarmRequired || canScheduleExactAlarms;
  bool get notificationReady => !notificationRequired || notificationGranted;

  bool get detectableReady => exactAlarmReady && notificationReady;
}

class WidgetPermissionRequirement {
  const WidgetPermissionRequirement({
    required this.type,
    required this.title,
    required this.description,
    required this.settingsHint,
    this.detectable = true,
  });

  final WidgetPermissionType type;
  final String title;
  final String description;
  final String settingsHint;
  final bool detectable;
}

class WidgetPermissionService {
  static const MethodChannel _channel =
      MethodChannel('edu.sdpei.JWSystem/widget_permission');
  static const String exactAlarmDeniedKey = 'widget_exact_alarm_denied';
  static bool _promptedThisSession = false;

  static bool get isHomeWidgetSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static Future<WidgetPermissionStatus> getStatus() async {
    if (!Platform.isAndroid) {
      return const WidgetPermissionStatus(
        canScheduleExactAlarms: true,
        exactAlarmRequired: false,
        notificationGranted: true,
        notificationRequired: false,
        isXiaomiFamily: false,
        sdkInt: 0,
      );
    }

    try {
      final result = await _channel.invokeMethod<Object>('getWidgetPermissionStatus');
      if (result is Map) {
        return WidgetPermissionStatus(
          canScheduleExactAlarms: result['canScheduleExactAlarms'] == true,
          exactAlarmRequired: result['exactAlarmRequired'] == true,
          notificationGranted: result['notificationGranted'] == true,
          notificationRequired: result['notificationRequired'] == true,
          isXiaomiFamily: result['isXiaomiFamily'] == true,
          sdkInt: (result['sdkInt'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (e) {
      debugPrint('Native widget permission status failed: $e');
    }

    return _fallbackStatus();
  }

  static Future<WidgetPermissionStatus> _fallbackStatus() async {
    final info = await DeviceInfoPlugin().androidInfo;
    final sdkInt = info.version.sdkInt;
    final exactAlarmRequired = sdkInt >= 31;
    final notificationRequired = sdkInt >= 33;
    final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
    final notificationStatus = await Permission.notification.status;
    final brand = info.brand.toLowerCase();
    final manufacturer = info.manufacturer.toLowerCase();

    return WidgetPermissionStatus(
      canScheduleExactAlarms: exactAlarmStatus.isGranted,
      exactAlarmRequired: exactAlarmRequired,
      notificationGranted: notificationStatus.isGranted,
      notificationRequired: notificationRequired,
      isXiaomiFamily: manufacturer.contains('xiaomi') ||
          brand.contains('xiaomi') ||
          brand.contains('redmi') ||
          brand.contains('poco'),
      sdkInt: sdkInt,
    );
  }

  static Future<List<WidgetPermissionRequirement>> getUnmetRequirements() async {
    if (!isHomeWidgetSupported || !Platform.isAndroid) return [];

    final status = await getStatus();
    final missing = <WidgetPermissionRequirement>[];

    if (status.exactAlarmRequired && !status.canScheduleExactAlarms) {
      missing.add(WidgetPermissionRequirement(
        type: WidgetPermissionType.exactAlarm,
        title: '闹钟',
        description:
            '课表小组件需要在每节课结束、跨天时准时刷新，请开启「闹钟」权限（系统名称：闹钟和提醒）。',
        settingsHint: _exactAlarmSettingsHint(status),
      ));
    }

    if (status.notificationRequired && !status.notificationGranted) {
      missing.add(const WidgetPermissionRequirement(
        type: WidgetPermissionType.notification,
        title: '通知（提醒）',
        description:
            'HyperOS 等系统常将通知显示为「提醒」。'
            '开启后课前提醒可正常发送，部分机型后台调度也更稳定。',
        settingsHint: '系统设置 → 应用 → 教务小助手 → 通知管理 → 允许通知',
      ));
    }

    if (status.isXiaomiFamily) {
      missing.add(const WidgetPermissionRequirement(
        type: WidgetPermissionType.autostart,
        title: '自启动',
        description:
            '小米/红米机型需在「自启动」中允许本应用，'
            '重启手机后课表小组件才能继续定时刷新。',
        settingsHint: '系统设置 → 应用设置 → 自启动管理 → 教务小助手 → 开启',
        detectable: false,
      ));
    }

    return missing;
  }

  static String _exactAlarmSettingsHint(WidgetPermissionStatus status) {
    if (status.isXiaomiFamily) {
      return '系统设置 → 应用 → 教务小助手 → 权限管理 → 闹钟和提醒 → 允许';
    }
    return '系统设置 → 应用 → 特殊应用权限 → 闹钟和提醒 → 教务小助手 → 允许';
  }

  static Future<bool> requestRequirement(WidgetPermissionType type) async {
    switch (type) {
      case WidgetPermissionType.exactAlarm:
        final status = await Permission.scheduleExactAlarm.request();
        return status.isGranted;
      case WidgetPermissionType.notification:
        final status = await Permission.notification.request();
        return status.isGranted;
      case WidgetPermissionType.autostart:
        try {
          return await _channel.invokeMethod<bool>('openAutostartSettings') ?? false;
        } catch (_) {
          await openAppSettings();
          return false;
        }
    }
  }

  static Future<bool> consumeNativeExactAlarmDeniedFlag() async {
    if (!Platform.isAndroid) return false;
    try {
      final denied = await HomeWidget.getWidgetData<bool>(
        exactAlarmDeniedKey,
        defaultValue: false,
      );
      if (denied == true) {
        await HomeWidget.saveWidgetData<bool>(exactAlarmDeniedKey, false);
        return true;
      }
    } catch (e) {
      debugPrint('Failed to read widget exact alarm flag: $e');
    }
    return false;
  }

  static Future<void> promptIfNeeded(BuildContext context) async {
    if (!context.mounted || !isHomeWidgetSupported) return;

    final nativeDenied = await consumeNativeExactAlarmDeniedFlag();
    final missing = await getUnmetRequirements()
        .then((items) => items.where((item) => item.detectable).toList());
    if (!nativeDenied && missing.isEmpty) return;
    if (_promptedThisSession && missing.isEmpty) return;

    _promptedThisSession = true;
    if (!context.mounted) return;

    if (missing.isNotEmpty) {
      await showRequirementsDialog(context, missing);
      return;
    }

    if (nativeDenied && context.mounted) {
      final status = await getStatus();
      if (!context.mounted) return;
      await showRequirementsDialog(
        context,
        [
          WidgetPermissionRequirement(
            type: WidgetPermissionType.exactAlarm,
            title: '闹钟',
            description:
                '课表小组件未能设置定时刷新，可能因为未授予「闹钟」权限。'
                '请开启后，小组件才能在每节课结束后自动更新。',
            settingsHint: _exactAlarmSettingsHint(status),
          ),
        ],
      );
    }
  }

  static Future<void> showRequirementsDialog(
    BuildContext context,
    List<WidgetPermissionRequirement> requirements,
  ) async {
    if (!context.mounted || requirements.isEmpty) return;

    final body = requirements
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(item.description),
                const SizedBox(height: 4),
                Text(
                  '开启路径：${item.settingsHint}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('小组件相关权限'),
        content: SingleChildScrollView(child: Column(children: body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('稍后'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              for (final item in requirements) {
                final granted = await requestRequirement(item.type);
                if (item.type == WidgetPermissionType.autostart) {
                  break;
                }
                if (granted) continue;
                if (context.mounted) {
                  await openAppSettings();
                }
                break;
              }
            },
            child: const Text('去开启'),
          ),
        ],
      ),
    );
  }

  static String platformGuideText() {
    if (Platform.isIOS) {
      return '长按主屏幕 → 点左上角「+」→ 搜索「教务小助手」→ 添加「今日课表」或「绩点与学分」小组件。';
    }
    if (Platform.isAndroid) {
      return '长按主屏幕 → 小组件 → 找到「教务小助手」→ 添加「今日课表」或「学业进度」。';
    }
    return '当前平台不支持桌面小组件。';
  }
}
