import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:JWHelper/features/notice/data/notice_source.dart';
import 'package:JWHelper/features/notice/domain/notice_detail.dart';
import 'package:JWHelper/features/notice/domain/notice_item.dart';
import 'package:JWHelper/features/notice/presentation/notice_format.dart';
import 'package:JWHelper/features/notice/presentation/notice_provider.dart';
import 'package:JWHelper/features/notice/presentation/notice_web_screen.dart';

/// 通知详情。
///
/// 正文优先用原生排版渲染；遇到图片、表格或解析失败，就引导到内嵌网页原文——
/// 宁可多一步点击，也不要把排版错乱的正文硬塞给用户。
class NoticeDetailScreen extends StatefulWidget {
  const NoticeDetailScreen({super.key, required this.item});

  final NoticeItem item;

  static Future<void> open(BuildContext context, NoticeItem item) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NoticeDetailScreen(item: item)),
    );
  }

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  NoticeDetail? _detail;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await context.read<NoticeProvider>().loadDetail(widget.item);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } on NoticeException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载正文失败：$e';
        _isLoading = false;
      });
    }
  }

  void _openWeb() {
    NoticeWebScreen.open(context, url: Uri.parse(widget.item.url));
  }

  /// 附件下载地址需要登录态，系统浏览器会跳到统一认证。
  /// 所以先打开应用内网页版，让用户在原页面里下载。
  void _openAttachment(NoticeAttachment attachment) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${attachment.name}」需登录态下载，已打开网页版'),
        duration: const Duration(seconds: 3),
      ),
    );
    _openWeb();
  }

  Future<void> _openExternal(String link) async {
    var url = link.trim();
    if (!url.startsWith('http')) {
      url = 'http://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开链接')),
      );
    }
  }

  IconData _attachmentIcon(String suffix) {
    switch (suffix.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知详情'),
        actions: [
          IconButton(
            tooltip: '查看原文',
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openWeb,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildError(_error!);
    }
    final detail = _detail;
    if (detail == null || detail.paragraphs.isEmpty) {
      return _buildError('这条通知的正文没能解析出来');
    }
    return _buildContent(detail);
  }

  Widget _buildContent(NoticeDetail detail) {
    final theme = Theme.of(context);
    final date = detail.publishedAt ?? widget.item.publishedAt;
    final meta = [
      if (widget.item.department.isNotEmpty) widget.item.department,
      if (date != null) formatNoticeFullDate(date),
    ].join(' · ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          detail.title.isEmpty ? widget.item.title : detail.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            meta,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Divider(color: theme.dividerColor, height: 1),
        const SizedBox(height: 16),
        if (detail.hasImages)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _NoticeHint(
              icon: Icons.image_outlined,
              text: '正文含图片，这里只显示文字；完整排版请点右上角查看原文。',
            ),
          ),
        for (final paragraph in detail.paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SelectableText(
              paragraph,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                height: 1.75,
              ),
            ),
          ),
        if (detail.externalLink.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link),
            title: const Text('这条通知指向外部链接'),
            subtitle: Text(
              detail.externalLink,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openExternal(detail.externalLink),
          ),
        if (detail.attachments.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '附件（${detail.attachments.length}）',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          for (final attachment in detail.attachments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_attachmentIcon(attachment.suffix)),
              title: Text(
                attachment.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _openAttachment(attachment),
            ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _openWeb,
          icon: const Icon(Icons.open_in_browser, size: 18),
          label: const Text('在网页中查看完整原文'),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.article_outlined,
              size: 40,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: _load, child: const Text('重试')),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _openWeb,
                  icon: const Icon(Icons.open_in_browser, size: 18),
                  label: const Text('查看原文'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeHint extends StatelessWidget {
  const _NoticeHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
