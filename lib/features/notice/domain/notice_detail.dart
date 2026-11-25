import 'package:flutter/foundation.dart';

/// 通知详情里的一个附件。
@immutable
class NoticeAttachment {
  const NoticeAttachment({required this.name, required this.url});

  final String name;
  final String url;
}

/// 通知详情的正文结构。
///
/// 学校页面的正文是富文本（表格、图片、附件混排），这里只抽取「能安全渲染成
/// 纯文本」的部分：段落文字 + 附件链接。图片与复杂排版统一交给网页版，
/// 由界面上的「在网页中查看完整原文」兜底。
@immutable
class NoticeDetail {
  const NoticeDetail({
    required this.url,
    required this.title,
    required this.paragraphs,
    this.attachments = const [],
    this.hasImages = false,
    this.publishedAt,
  });

  final String url;
  final String title;
  final List<String> paragraphs;
  final List<NoticeAttachment> attachments;

  /// 正文里含图片。纯文本渲染会丢图，界面据此把「看原文」的入口前置。
  final bool hasImages;

  final DateTime? publishedAt;

  bool get isEmpty => paragraphs.isEmpty && attachments.isEmpty;
}
