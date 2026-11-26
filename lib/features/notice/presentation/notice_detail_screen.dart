import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:JWHelper/features/notice/data/notice_source.dart';
import 'package:JWHelper/features/notice/domain/notice_detail.dart';
import 'package:JWHelper/features/notice/domain/notice_item.dart';
import 'package:JWHelper/features/notice/presentation/notice_format.dart';
import 'package:JWHelper/features/notice/presentation/notice_provider.dart';
import 'package:JWHelper/features/notice/presentation/notice_web_screen.dart';

/// 通知详情。
///
/// 正文按「文字 / 图片」块顺序渲染；图片需要登录态，统一走
/// [NoticeProvider.loadImage] 带 Cookie 下载，不能交给 `Image.network`。
/// 排版特别复杂或需要下载附件时，右上角可切到网页版原文。
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

  /// 正在下载的附件地址；不为空时列表上显示进度。
  String? _downloadingUrl;

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

  /// 附件用登录态直接下载到本地，再交给系统查看器打开。
  ///
  /// 之前是「打开网页版让用户自己下」，但既然 App 已经持有统一认证登录态，
  /// 直接下载体验更好；下载失败才退回网页版。
  Future<void> _openAttachment(NoticeAttachment attachment) async {
    if (_downloadingUrl != null) return;

    setState(() => _downloadingUrl = attachment.url);
    final path =
        await context.read<NoticeProvider>().downloadAttachment(attachment);
    if (!mounted) return;
    setState(() => _downloadingUrl = null);

    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('附件下载失败，已打开网页版')),
      );
      _openWeb();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('附件已下载，正在打开…'),
        duration: Duration(milliseconds: 1500),
      ),
    );

    final result = await OpenFilex.open(path);
    if (!mounted) return;
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('附件已保存到 $path，但没有可打开它的应用'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
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
        leading: BackButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
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
    if (detail == null || detail.isEmpty) {
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
          Row(
            children: [
              if (widget.item.isPinned)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.push_pin,
                    size: 13,
                    color: theme.colorScheme.primary,
                  ),
                ),
              Expanded(
                child: Text(
                  meta,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Divider(color: theme.dividerColor, height: 1),
        const SizedBox(height: 16),
        for (var i = 0; i < detail.blocks.length; i++) _buildBlock(detail.blocks[i], i),
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
              subtitle: const Text(
                '点击下载并打开',
                style: TextStyle(fontSize: 11),
              ),
              trailing: _downloadingUrl == attachment.url
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download, size: 18),
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

  Widget _buildBlock(NoticeBlock block, int index) {
    final theme = Theme.of(context);

    if (block is NoticeImageBlock) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: NoticeImage(url: block.url),
      );
    }

    final text = (block as NoticeTextBlock).text;
    return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: SelectableText(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 15,
              height: 1.75,
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 220.ms, delay: (index.clamp(0, 6) * 30).ms);
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

/// 正文图片：带 Cookie 下载后内存渲染，点击可全屏查看。
class NoticeImage extends StatefulWidget {
  const NoticeImage({super.key, required this.url});

  final String url;

  @override
  State<NoticeImage> createState() => _NoticeImageState();
}

class _NoticeImageState extends State<NoticeImage> {
  Future<Uint8List?>? _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<NoticeProvider>().loadImage(widget.url);
  }

  @override
  void didUpdateWidget(covariant NoticeImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _future = context.read<NoticeProvider>().loadImage(widget.url);
    }
  }

  void _openFullscreen(Uint8List bytes) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: InteractiveViewer(
          maxScale: 5,
          child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            height: 160,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '图片加载失败，可在网页版中查看',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return GestureDetector(
          onTap: () => _openFullscreen(bytes),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              fit: BoxFit.fitWidth,
              width: double.infinity,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ).animate().fadeIn(duration: 260.ms, curve: Curves.easeOut);
      },
    );
  }
}
