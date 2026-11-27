import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_account_form.dart';
import 'package:JWHelper/features/notice/data/pubinfo_notice_source.dart';
import 'package:JWHelper/features/notice/presentation/notice_provider.dart';

/// 通知模块的设置项。
///
/// 放在通知页右上角的「更多」里，而不是塞进全局设置弹窗：这些选项只影响通知
/// 模块本身，跟着页面走更好找，也避免动到首页那个已经很长的设置弹窗。
class NoticeSettingsSheet extends StatelessWidget {
  const NoticeSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // 内容超过半屏时可以继续长高，再由内部滚动兜住，避免矮屏溢出。
      isScrollControlled: true,
      builder: (_) => const NoticeSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notice = context.watch<NoticeProvider>();
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [Text('通知设置', style: theme.textTheme.titleMedium)],
                ),
              ),
              SwitchListTile(
                title: const Text('新通知提醒'),
                subtitle: const Text('打开 App 时检查一次，有新通知弹一条提醒'),
                value: notice.reminderEnabled,
                onChanged: (value) => notice.setReminderEnabled(value),
              ),
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('智慧山体账号'),
                subtitle: Text(
                  notice.hasCredentials ? '已绑定，用于获取通知平台的登录态' : '未绑定，绑定后才能读取通知',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final saved = await AttendanceAccountDialog.show(context);
                  if (!context.mounted) return;
                  if (saved) {
                    Navigator.of(context).pop();
                    await notice.refresh();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.done_all),
                title: const Text('清空已读标记'),
                subtitle: const Text('把所有通知重新标记为未读'),
                onTap: () async {
                  await notice.clearReadState();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已清空已读标记')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_browser),
                title: const Text('用浏览器打开通知平台'),
                subtitle: const Text('遇到排版复杂或需要下载附件时使用'),
                onTap: () async {
                  final uri = Uri.parse(PubinfoNoticeSource.origin);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  '通知内容来自学校信息发布平台，需要登录态才能读取；本机只缓存标题与链接，不保存正文。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
