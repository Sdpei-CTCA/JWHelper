import 'package:flutter/foundation.dart';

/// 通知详情里的一个附件。
@immutable
class NoticeAttachment {
  const NoticeAttachment({
    required this.name,
    required this.url,
    this.suffix = '',
  });

  final String name;

  /// 下载地址。需要登录态，必须带 Cookie 请求或在应用内网页里打开。
  final String url;

  /// 扩展名（pdf/docx/…），用于选图标。
  final String suffix;
}

/// 正文里的一个内容块。
///
/// 学校正文是「文字 + 图片」混排的 HTML，按 DOM 顺序切成块才能在原生页面里
/// 还原大致版式；只抽段落会把图片全丢到最后。
sealed class NoticeBlock {
  const NoticeBlock();
}

class NoticeTextBlock extends NoticeBlock {
  const NoticeTextBlock(this.text);

  final String text;
}

class NoticeImageBlock extends NoticeBlock {
  const NoticeImageBlock(this.url);

  /// 图片绝对地址。加载需要登录态，由 [NoticeProvider] 统一带 Cookie 下载。
  final String url;
}

/// 通知详情的正文结构。
@immutable
class NoticeDetail {
  const NoticeDetail({
    required this.url,
    required this.title,
    required this.blocks,
    this.attachments = const [],
    this.publishedAt,
    this.externalLink = '',
  });

  final String url;
  final String title;

  /// 按出现顺序排列的段落与图片。
  final List<NoticeBlock> blocks;

  final List<NoticeAttachment> attachments;
  final DateTime? publishedAt;

  /// 通知本身指向的外部链接（接口字段 `ms_link`）。
  final String externalLink;

  bool get isEmpty => blocks.isEmpty && attachments.isEmpty;

  List<String> get paragraphs => blocks
      .whereType<NoticeTextBlock>()
      .map((e) => e.text)
      .toList(growable: false);

  List<String> get images => blocks
      .whereType<NoticeImageBlock>()
      .map((e) => e.url)
      .toList(growable: false);
}
