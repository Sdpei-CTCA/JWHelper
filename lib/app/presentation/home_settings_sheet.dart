import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:JWHelper/app/presentation/background_sync_tiles.dart';
import 'package:JWHelper/app/presentation/reminder_diagnostics_tile.dart';
import 'package:JWHelper/app/presentation/widget_settings_sheet.dart';
import 'package:JWHelper/app/state/data_provider.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_account_form.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_provider.dart';
import 'package:JWHelper/features/schedule/presentation/wallpaper_settings_screen.dart';
import 'package:JWHelper/infrastructure/notifications/notification_service.dart';
import 'package:JWHelper/infrastructure/platform/widget_permission_service.dart';
import 'package:JWHelper/shared/theme/theme_provider.dart';

/// 申请通知权限；未授权时弹出引导前往系统设置的提示框。
Future<bool> ensureNotificationPermission(
  BuildContext context, {
  required String rationale,
}) async {
  var status = await Permission.notification.status;
  if (!status.isGranted) {
    status = await Permission.notification.request();
  }
  if (status.isGranted) return true;

  if (!context.mounted) return false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('需要通知权限'),
      content: Text(rationale),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            openAppSettings();
            Navigator.pop(dialogContext);
          },
          child: const Text('去设置'),
        ),
      ],
    ),
  );
  return false;
}

/// 首页「设置与关于」底部弹窗。
///
/// 独立为 [StatefulWidget] 后，版本号、课前提醒开关、桌面小组件权限等异步查询
/// 在 [initState] 仅发起一次，避免弹窗任意刷新时重复创建 Future。
class HomeSettingsSheet extends StatefulWidget {
  const HomeSettingsSheet({
    super.key,
    required this.currentVersion,
    required this.onRestoreSchedule,
    required this.onCheckUpdate,
    required this.onLogout,
  });

  final String currentVersion;
  final VoidCallback onRestoreSchedule;
  final VoidCallback onCheckUpdate;
  final VoidCallback onLogout;

  static Future<void> show(
    BuildContext context, {
    required String currentVersion,
    required VoidCallback onRestoreSchedule,
    required VoidCallback onCheckUpdate,
    required VoidCallback onLogout,
  }) {
    context.read<AttendanceProvider>().ensureLoaded();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HomeSettingsSheet(
        currentVersion: currentVersion,
        onRestoreSchedule: onRestoreSchedule,
        onCheckUpdate: onCheckUpdate,
        onLogout: onLogout,
      ),
    );
  }

  @override
  State<HomeSettingsSheet> createState() => _HomeSettingsSheetState();
}

class _HomeSettingsSheetState extends State<HomeSettingsSheet> {
  Future<PackageInfo>? _packageInfoFuture;
  late Future<List<WidgetPermissionRequirement>> _unmetPermissionsFuture;
  bool _reminderEnabled = true;

  @override
  void initState() {
    super.initState();
    if (widget.currentVersion.isEmpty) {
      _packageInfoFuture = PackageInfo.fromPlatform();
    }
    _unmetPermissionsFuture = WidgetPermissionService.getUnmetRequirements();
    _loadReminderEnabled();
  }

  Future<void> _loadReminderEnabled() async {
    final enabled = await NotificationService().isEnabled;
    if (!mounted) return;
    setState(() => _reminderEnabled = enabled);
  }

  Future<void> _toggleClassReminder(bool newValue) async {
    if (newValue) {
      final granted = await ensureNotificationPermission(
        context,
        rationale: '课前提醒功能需要通知权限。请在系统设置中允许「教务小助手」发送通知。',
      );
      if (!granted || !mounted) return;
    }

    await NotificationService().setEnabled(newValue);
    if (!mounted) return;
    setState(() => _reminderEnabled = newValue);

    if (newValue) {
      final dataProvider = context.read<DataProvider>();
      if (dataProvider.scheduleLoaded) {
        await dataProvider.rescheduleScheduleOutputs();
      } else {
        await dataProvider.loadSchedule();
      }
    } else {
      await NotificationService().cancelClassReminders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85,
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            '设置与关于',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildHeader(context, primaryColor),
                const SizedBox(height: 24),
                Text(
                  '常规设置',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                _buildGeneralCard(context, theme, primaryColor),
                const SizedBox(height: 24),
                Text(
                  '关于',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                _buildAboutCard(context, primaryColor),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onLogout();
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      '退出登录',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'GPL3.0 License\nOriginal Author: Chendayday-2025\nRemake by: Sdpei-CTCA',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color primaryColor) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                cacheWidth:
                    (70 * MediaQuery.devicePixelRatioOf(context)).round(),
                errorBuilder: (context, error, stackTrace) => Container(
                  color: primaryColor,
                  child: const Icon(Icons.school, size: 40, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '教务小助手',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (widget.currentVersion.isNotEmpty)
            Text(
              'v${widget.currentVersion}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            )
          else
            FutureBuilder<PackageInfo>(
              future: _packageInfoFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    'v${snapshot.data!.version}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  );
                }
                return const Text(
                  'v...',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGeneralCard(
    BuildContext context,
    ThemeData theme,
    Color primaryColor,
  ) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              final (themeText, icon) = switch (themeProvider.themeMode) {
                ThemeMode.system => ('跟随系统', Icons.brightness_auto),
                ThemeMode.light => ('浅色模式', Icons.brightness_7),
                ThemeMode.dark => ('深色模式', Icons.brightness_2),
              };
              return ListTile(
                leading: Icon(icon, color: primaryColor),
                title: const Text('外观主题'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(themeText, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right,
                        size: 16, color: Colors.grey),
                  ],
                ),
                onTap: themeProvider.toggleTheme,
              );
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: Icon(Icons.wallpaper, color: primaryColor),
            title: const Text('课表外观自定义'),
            subtitle: const Text('自定义课表背景、配色和卡片透明度',
                style: TextStyle(fontSize: 12)),
            trailing:
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const WallpaperSettingsScreen()),
              );
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Selector<DataProvider, ({bool isLocal, bool loading})>(
            selector: (_, d) =>
                (isLocal: d.isScheduleLocalMode, loading: d.scheduleLoading),
            builder: (sheetContext, state, _) {
              return ListTile(
                leading: Icon(Icons.restore, color: primaryColor),
                title: const Text('恢复课表'),
                subtitle: Text(
                  state.isLocal
                      ? '当前为自定义课表，点击从教务重新获取'
                      : '从教务网站重新获取最新课表',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: state.loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right,
                        size: 16, color: Colors.grey),
                onTap: state.loading
                    ? null
                    : () {
                        Navigator.pop(sheetContext);
                        widget.onRestoreSchedule();
                      },
              );
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Selector<DataProvider, String>(
            selector: (_, d) => d.campus,
            builder: (context, campus, _) {
              return ListTile(
                leading: Icon(Icons.location_city, color: primaryColor),
                title: const Text('当前校区'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(campus, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(width: 8),
                    const Icon(Icons.compare_arrows,
                        size: 16, color: Colors.grey),
                  ],
                ),
                onTap: () async {
                  final newCampus = campus == '济南' ? '日照' : '济南';
                  await context.read<DataProvider>().setCampus(newCampus);
                },
              );
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            secondary: Icon(Icons.notifications_active, color: primaryColor),
            title: const Text('课前提醒'),
            subtitle:
                const Text('课前10分钟发送本地通知', style: TextStyle(fontSize: 12)),
            value: _reminderEnabled,
            activeThumbColor: theme.colorScheme.secondary,
            onChanged: _toggleClassReminder,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          BackgroundSyncTiles(accentColor: primaryColor),
          ReminderDiagnosticsTile(accentColor: primaryColor),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Selector<AttendanceProvider, String>(
            selector: (_, p) => p.savedUsername,
            builder: (context, username, _) {
              return ListTile(
                leading: Icon(Icons.how_to_reg_outlined, color: primaryColor),
                title: const Text('智慧考勤账号'),
                subtitle: Text(
                  username.isEmpty
                      ? '未配置，考勤签到前需填写学号与密码'
                      : '已绑定学号: $username',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right,
                    size: 16, color: Colors.grey),
                onTap: () => AttendanceAccountDialog.show(context),
              );
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          FutureBuilder<List<WidgetPermissionRequirement>>(
            future: _unmetPermissionsFuture,
            builder: (context, snapshot) {
              final missing = (snapshot.data ?? const [])
                  .where((item) => item.detectable)
                  .toList();
              final subtitle = !WidgetPermissionService.isHomeWidgetSupported
                  ? '当前平台不支持'
                  : missing.isNotEmpty
                      ? '缺少权限：${missing.map((e) => e.title).join('、')}'
                      : '添加课表、学业进度到桌面';
              return ListTile(
                leading: Icon(Icons.widgets_outlined, color: primaryColor),
                title: const Text('桌面小组件'),
                subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right,
                    size: 16, color: Colors.grey),
                onTap: () => WidgetSettingsSheet.show(context),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context, Color primaryColor) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.update, color: primaryColor),
            title: const Text('检查更新'),
            trailing:
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            onTap: () {
              Navigator.pop(context);
              widget.onCheckUpdate();
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: Icon(Icons.code, color: primaryColor),
            title: const Text('开源仓库'),
            subtitle: const Text('GitHub: Sdpei-CTCA/JWHelper',
                style: TextStyle(fontSize: 12)),
            trailing:
                const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
            onTap: () =>
                launchUrl(Uri.parse('https://github.com/Sdpei-CTCA/JWHelper')),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: Icon(Icons.feedback, color: primaryColor),
            title: const Text('反馈与交流'),
            subtitle:
                const Text('加入QQ群反馈问题', style: TextStyle(fontSize: 12)),
            trailing:
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            onTap: () =>
                launchUrl(Uri.parse('https://qm.qq.com/q/YOwkJmn3gc')),
          ),
        ],
      ),
    );
  }
}
