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

/// 通知详情的正文结构。
///
/// 接口里的 `content` 是富文本片段，这里只抽「能安全渲染成纯文本」的部分：
/// 段落文字 + 附件。图片与复杂排版交给网页版兜底。
@immutable
class NoticeDetail {
  const NoticeDetail({
    required this.url,
    required this.title,
    required this.paragraphs,
    this.attachments = const [],
    this.hasImages = false,
    this.publishedAt,
    this.externalLink = '',
  });

  final String url;
  final String title;
  final List<String> paragraphs;
  final List<NoticeAttachment> attachments;

  /// 正文里含图片。纯文本渲染会丢图，界面据此把「看原文」的入口前置。
  final bool hasImages;

  final DateTime? publishedAt;

  /// 通知本身指向的外部链接（接口字段 `ms_link`）。
  final String externalLink;

  bool get isEmpty => paragraphs.isEmpty && attachments.isEmpty;
}
