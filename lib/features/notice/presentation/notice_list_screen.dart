import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_account_form.dart';
import 'package:JWHelper/features/notice/data/notice_source.dart';
import 'package:JWHelper/features/notice/data/pubinfo_notice_source.dart';
import 'package:JWHelper/features/notice/domain/notice_item.dart';
import 'package:JWHelper/features/notice/presentation/notice_detail_screen.dart';
import 'package:JWHelper/features/notice/presentation/notice_format.dart';
import 'package:JWHelper/features/notice/presentation/notice_provider.dart';
import 'package:JWHelper/features/notice/presentation/notice_settings_sheet.dart';
import 'package:JWHelper/features/notice/presentation/notice_web_screen.dart';

/// 通知公告列表。
///
/// 从首页标题栏的铃铛进入，是一个 push 出来的整页，不占底部导航。
class NoticeListScreen extends StatefulWidget {
  const NoticeListScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NoticeListScreen()),
    );
  }

  @override
  State<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends State<NoticeListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notice = context.read<NoticeProvider>();
      if (!notice.hasLoaded || notice.items.isEmpty) {
        notice.refresh();
      }
    });
  }

  Future<void> _openItem(NoticeItem item) async {
    final notice = context.read<NoticeProvider>();
    await notice.markRead(item);
    if (!mounted) return;
    await NoticeDetailScreen.open(context, item);
  }

  Future<void> _bindAccount() async {
    final saved = await AttendanceAccountDialog.show(context);
    if (!mounted || !saved) return;
    await context.read<NoticeProvider>().refresh();
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(PubinfoNoticeSource.origin);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// 打开应用内网页版：登录态拿不到时，这是唯一能看到内容的兜底。
  void _openWeb() {
    NoticeWebScreen.open(
      context,
      url: Uri.parse(PubinfoNoticeSource.origin),
      title: '通知公告',
    );
  }

  /// 复制诊断信息。Release 包拿不到私有目录里的原始页面，这个按钮是唯一
  /// 能把「页面到底长什么样」反馈出来的通道。
  Future<void> _copyDiagnostics(NoticeProvider notice) async {
    final text = [
      notice.errorMessage ?? '',
      notice.diagnostics,
      notice.structureSummary,
    ].where((e) => e.trim().isNotEmpty).join('\n\n');

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('诊断信息已复制，可直接粘贴反馈')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notice = context.watch<NoticeProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('通知公告', style: TextStyle(fontWeight: FontWeight.bold)),
            if (notice.items.isNotEmpty)
              Text(
                notice.unreadCount > 0
                    ? '${notice.unreadCount} 条未读'
                    : '全部已读',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '全部已读',
            icon: const Icon(Icons.done_all),
            onPressed: notice.unreadCount == 0 ? null : notice.markAllRead,
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  notice.refresh();
                  break;
                case 'settings':
                  NoticeSettingsSheet.show(context);
                  break;
                case 'browser':
                  _openInBrowser();
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'refresh', child: Text('刷新')),
              PopupMenuItem(value: 'settings', child: Text('通知设置')),
              PopupMenuItem(value: 'browser', child: Text('用浏览器打开')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notice.refresh(),
        child: _buildBody(notice),
      ),
    );
  }

  Widget _buildBody(NoticeProvider notice) {
    if (notice.items.isEmpty) {
      if (notice.isLoading || notice.isRefreshing) {
        return const Center(child: CircularProgressIndicator());
      }
      if (notice.errorMessage != null) {
        return _buildError(notice);
      }
      return _buildEmpty();
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: notice.items.length + (notice.errorMessage != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (notice.errorMessage != null) {
          if (index == 0) {
            return _StaleBanner(onRetry: () => notice.refresh());
          }
          index -= 1;
        }
        final item = notice.items[index];
        final isLast = index == notice.items.length - 1;
        return Column(
          children: [
            _NoticeTile(item: item, onTap: () => _openItem(item)),
            if (!isLast)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        );
      },
    );
  }

  Widget _buildEmpty() {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        Icon(
          Icons.notifications_none,
          size: 44,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '暂无通知',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            '下拉刷新试试',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(NoticeProvider notice) {
    final theme = Theme.of(context);
    final kind = notice.errorKind;
    final needsBinding = kind == NoticeErrorKind.notConfigured;
    final needsRelogin = kind == NoticeErrorKind.authFailed;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Icon(
          needsBinding || needsRelogin
              ? Icons.lock_outline
              : Icons.cloud_off_outlined,
          size: 44,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 14),
        Text(
          notice.errorMessage ?? '加载通知失败',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (needsBinding || needsRelogin)
                FilledButton.icon(
                  onPressed: _bindAccount,
                  icon: const Icon(Icons.account_circle_outlined, size: 18),
                  label: Text(needsBinding ? '绑定账号' : '重新登录'),
                ),
              OutlinedButton(onPressed: () => notice.refresh(), child: const Text('重试')),
              OutlinedButton(onPressed: _openWeb, child: const Text('网页版')),
            ],
          ),
        ),
        if (notice.diagnostics.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            notice.diagnostics,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => _copyDiagnostics(notice),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('复制诊断信息'),
            ),
          ),
        ],
      ],
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.item, required this.onTap});

  final NoticeItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !item.isRead;
    final meta = [
      if (item.department.isNotEmpty) item.department,
      if (item.publishedAt != null) formatNoticeDate(item.publishedAt),
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unread)
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 8),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: unread ? 1 : 0.7),
                    ),
                  ),
                ),
              ],
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.only(left: unread ? 15 : 0),
                child: Text(
                  meta,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 有缓存但刷新失败时，在列表顶部给一条不打断阅读的提示。
class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined,
              size: 16, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '显示的是上次缓存的内容',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
