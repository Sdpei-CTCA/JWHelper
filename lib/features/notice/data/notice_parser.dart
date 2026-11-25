import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:JWHelper/features/notice/domain/notice_detail.dart';
import 'package:JWHelper/features/notice/domain/notice_item.dart';

/// 学校信息发布平台的数据解析。
///
/// 平台的实际数据接口（抓包确认）：
/// - 列表：`GET /info/getInfoAllIndex?begin_num=0&num=50&scode=cloudtop&sate=2&d_state=2&dxtx=-1&in_ms_title=`
/// - 详情：`GET /info/getInfoById?id=<ms_id>`
/// - 附件：`GET /info/downfile?id=<mia_id>&infoid=<ms_id>`
///
/// 列表与详情都是 JSON，只有详情正文 `content` 是 HTML 片段，因此这里只保留
/// 「把 HTML 片段转成段落」的解析，不再猜测页面结构。
class NoticeParser {
  NoticeParser._();

  /// 站点标识，接口固定要带。
  static const String scode = 'cloudtop';

  static const String listPath = '/info/getInfoAllIndex';
  static const String detailPath = '/info/getInfoById';
  static const String downloadPath = '/info/downfile';

  /// 详情页（网页版），用于「查看原文」。
  static const String detailPagePath = '/page/infomation/infoxq.jsp';

  static const Set<String> _blockTags = {
    'p',
    'div',
    'li',
    'tr',
    'td',
    'section',
    'article',
    'blockquote',
    'ul',
    'ol',
    'table',
    'tbody',
    'thead',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
  };

  /// 解析列表接口。
  ///
  /// 返回顺序与网站一致（置顶在前、其余按更新时间倒序），不做二次排序，
  /// 免得把学校手动置顶的通知压下去。
  static List<NoticeItem> parseListJson(Map<String, dynamic> json, Uri origin) {
    final rows = json['aaData'];
    if (rows is! List) return const [];

    final items = <NoticeItem>[];
    for (final row in rows) {
      if (row is! Map) continue;

      final id = row['ms_id']?.toString().trim() ?? '';
      final title = (row['ms_title']?.toString() ?? '').trim();
      if (id.isEmpty || title.isEmpty) continue;

      items.add(NoticeItem(
        id: id,
        title: title,
        url: '$origin$detailPagePath?id=$id',
        publishedAt: _epoch(row['releasetime']) ?? _epoch(row['create_time']),
        department: (row['dwbzmc'] ?? '').toString().trim(),
        hasAttachment: _isTruthy(row['sffj']),
      ));
    }
    return items;
  }

  /// 解析详情接口。
  static NoticeDetail parseDetailJson(
    Map<String, dynamic> json,
    Uri origin, {
    String? fallbackTitle,
  }) {
    final id = json['ms_id']?.toString() ?? '';
    final title = (json['ms_title']?.toString() ?? '').trim();
    final content = json['content']?.toString() ?? '';

    final paragraphs = contentToParagraphs(content);

    final attachments = <NoticeAttachment>[];
    final files = json['fj'];
    if (files is List) {
      for (final file in files) {
        if (file is! Map) continue;
        final fileId = file['mia_id']?.toString() ?? '';
        final name = (file['fjname']?.toString() ?? '').trim();
        if (fileId.isEmpty || name.isEmpty) continue;
        attachments.add(NoticeAttachment(
          name: name,
          suffix: (file['suffix']?.toString() ?? '').trim(),
          url: '$origin$downloadPath?id=$fileId&infoid=$id',
        ));
      }
    }

    return NoticeDetail(
      url: '$origin$detailPagePath?id=$id',
      title: title.isEmpty ? (fallbackTitle ?? '') : title,
      paragraphs: paragraphs,
      attachments: attachments,
      hasImages: content.contains('<img'),
      publishedAt: _epoch(json['releasetime']) ?? _epoch(json['create_time']),
      externalLink: (json['ms_link']?.toString() ?? '').trim(),
    );
  }

  /// 把详情正文的 HTML 片段转成纯文本段落。
  ///
  /// 正文里 `<br>`、`<p>`、表格单元格都当作换行；图片只做标记（不渲染），
  /// 由界面提示「看原文」。
  static List<String> contentToParagraphs(String content) {
    if (content.trim().isEmpty) return const [];

    final document = html_parser.parse('<div id="__content__">$content</div>');
    final root = document.querySelector('#__content__');
    if (root == null) return const [];

    for (final node in root.querySelectorAll('script, style, noscript')) {
      node.remove();
    }

    final buffer = StringBuffer();
    _walk(root, buffer);

    final paragraphs = <String>[];
    for (final raw in buffer.toString().split('\n')) {
      final line = _cleanLine(raw);
      if (line.isEmpty) continue;
      paragraphs.add(line);
    }
    return paragraphs;
  }

  /// 解析失败时把响应片段转成可复制的诊断文本。
  static String summarizeBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return '响应为空';
    final preview =
        trimmed.length > 400 ? '${trimmed.substring(0, 400)}…' : trimmed;
    return '响应长度 ${trimmed.length}\n$preview';
  }

  static void _walk(dom.Node node, StringBuffer out) {
    if (node is dom.Text) {
      out.write(node.text.replaceAll('\u00a0', ' '));
      return;
    }
    if (node is! dom.Element) {
      for (final child in node.nodes) {
        _walk(child, out);
      }
      return;
    }

    final tag = node.localName ?? '';
    if (tag == 'script' ||
        tag == 'style' ||
        tag == 'noscript' ||
        tag == 'iframe') {
      return;
    }
    if (tag == 'br') {
      out.write('\n');
      return;
    }
    if (tag == 'img') {
      return;
    }

    final isBlock = _blockTags.contains(tag);
    if (isBlock) out.write('\n');
    for (final child in node.nodes) {
      _walk(child, out);
    }
    if (isBlock) out.write('\n');
  }

  static DateTime? _epoch(dynamic value) {
    if (value == null) return null;
    final millis = value is int ? value : int.tryParse(value.toString());
    if (millis == null || millis <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static bool _isTruthy(dynamic value) {
    if (value == true) return true;
    if (value is int) return value != 0;
    final text = value?.toString();
    return text == '1' || text == 'true';
  }

  static String _cleanLine(String input) {
    return input
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }
}
