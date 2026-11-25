import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:JWHelper/features/notice/domain/notice_detail.dart';
import 'package:JWHelper/features/notice/domain/notice_item.dart';

/// 列表解析的统计信息。
///
/// 学校页面结构未知、且随时可能改版，所以把「看了多少个链接、认出多少条、
/// 多少条带日期」一并回传。解析结果为空时，界面可以据此提示是「真的没通知」
/// 还是「页面没认出来」，也方便排查。
class NoticeListParseResult {
  const NoticeListParseResult({
    required this.items,
    required this.anchorCount,
    required this.datedCount,
  });

  final List<NoticeItem> items;
  final int anchorCount;
  final int datedCount;

  bool get isEmpty => items.isEmpty;
}

/// 把学校发布平台的 HTML 转成结构化数据。
///
/// 解析策略刻意做成「启发式」而不是死绑 CSS 选择器：
/// 1. 遍历所有链接，按地址特征筛掉导航/附件/脚本链接；
/// 2. 从链接往上找最近的、文本里带日期的容器（`li` / `tr` / `div` 都行），
///    容器文本里减掉标题和日期，剩下的短文本当发布部门；
/// 3. 找不到日期的，只接受确实位于列表行（`li`/`tr`/`dd`）里的详情链接。
///
/// 这样即使学校把列表从 `<ul>` 改成 `<table>`，只要结构还是「一行一条、带日期」，
/// 就不用改代码。全部解析逻辑集中在本文件，改版时只需要动这里。
class NoticeParser {
  NoticeParser._();

  /// 单页最多保留多少条，防止把整站导航当成列表抓进来。
  static const int maxItems = 80;

  static final RegExp _dateFull =
      RegExp(r'(20\d{2})\s*[-/.年]\s*(\d{1,2})\s*[-/.月]\s*(\d{1,2})');
  static final RegExp _dateCompact = RegExp(r'(20\d{2})(\d{2})(\d{2})');
  static final RegExp _dateShort =
      RegExp(r'(?<!\d)(\d{1,2})\s*[-/月]\s*(\d{1,2})(?!\d)');

  static final RegExp _attachmentExt = RegExp(
    r'\.(pdf|docx?|xlsx?|pptx?|zip|rar|7z|txt|csv)(\?|#|$)',
    caseSensitive: false,
  );

  static const Set<String> _navTexts = {
    '首页',
    '上一页',
    '下一页',
    '末页',
    '尾页',
    '更多',
    '更多>>',
    '更多>>>',
    'more',
    '返回',
    '登录',
    '退出',
  };

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

  /// 解析列表页。
  static NoticeListParseResult parseList(String html, Uri baseUri) {
    final document = html_parser.parse(html);
    for (final node in document.querySelectorAll('script, style, noscript')) {
      node.remove();
    }

    final anchors = document.querySelectorAll('a');
    final seen = <String>{};
    final dated = <NoticeItem>[];
    final undated = <NoticeItem>[];
    var datedCount = 0;

    for (final anchor in anchors) {
      final href = (anchor.attributes['href'] ?? '').trim();
      if (!_looksLikeContentLink(href)) {
        continue;
      }

      final title = _titleOf(anchor);
      if (title.length < 5 || _navTexts.contains(title.toLowerCase())) {
        continue;
      }

      final uri = _resolve(baseUri, href);
      if (uri == null) {
        continue;
      }

      DateTime? publishedAt;
      var department = '';

      final datedContainer = _containerWithDate(anchor);
      if (datedContainer != null) {
        final containerText = _clean(datedContainer.text);
        publishedAt = extractDate(containerText);
        department = _departmentOf(
          containerText,
          title,
          _clean(anchor.text),
        );
        if (publishedAt != null) {
          datedCount++;
        }
      } else if (_rowAncestor(anchor) == null) {
        // 既不在带日期的容器里，也不在列表行里，基本就是导航链接。
        continue;
      }

      final id = uri.toString();
      if (!seen.add(id)) {
        continue;
      }

      final item = NoticeItem(
        id: id,
        title: title,
        url: id,
        publishedAt: publishedAt,
        department: department,
      );
      (publishedAt != null ? dated : undated).add(item);

      if (dated.length + undated.length >= maxItems) {
        break;
      }
    }

    dated.sort((a, b) => b.publishedAt!.compareTo(a.publishedAt!));

    return NoticeListParseResult(
      items: [...dated, ...undated],
      anchorCount: anchors.length,
      datedCount: datedCount,
    );
  }

  /// 解析详情页正文。
  static NoticeDetail parseDetail(String html, Uri url, {String? fallbackTitle}) {
    final document = html_parser.parse(html);
    for (final node in document.querySelectorAll('script, style, noscript')) {
      node.remove();
    }

    final title = _detailTitle(document, fallbackTitle);
    final content = _pickContent(document);

    if (content == null) {
      return NoticeDetail(
        url: url.toString(),
        title: title,
        paragraphs: const [],
        publishedAt: extractDate(_clean(document.body?.text ?? '')),
      );
    }

    final buffer = StringBuffer();
    var hasImages = false;
    _walk(content, buffer, () => hasImages = true);

    final paragraphs = <String>[];
    for (final raw in buffer.toString().split('\n')) {
      final line = _cleanMultiline(raw);
      if (line.isEmpty) continue;
      // 正文里重复出现的标题不再重复渲染。
      if (line == title) continue;
      paragraphs.add(line);
    }

    final attachments = _attachmentsIn(content, url);

    return NoticeDetail(
      url: url.toString(),
      title: title,
      paragraphs: paragraphs,
      attachments: attachments,
      hasImages: hasImages,
      publishedAt: extractDate(_clean(document.body?.text ?? '')),
    );
  }

  /// 从一段文本里找日期。列表页与详情页共用。
  ///
  /// 必须遍历所有匹配：标题里常出现「2026-2027学年」这种不成立的日期，
  /// 只取第一个匹配会把它当成日期，把真正的发布日期漏掉。
  static DateTime? extractDate(String text) {
    if (text.isEmpty) return null;

    for (final match in _dateFull.allMatches(text)) {
      final date = _buildDate(match.group(1), match.group(2), match.group(3));
      if (date != null) return date;
    }

    for (final match in _dateCompact.allMatches(text)) {
      final date = _buildDate(match.group(1), match.group(2), match.group(3));
      if (date != null) return date;
    }

    // 只写了「11-25」的列表：按最近一年推断，跨年时自动落到去年。
    for (final match in _dateShort.allMatches(text)) {
      final month = int.tryParse(match.group(1) ?? '');
      final day = int.tryParse(match.group(2) ?? '');
      if (month == null || day == null) continue;
      if (month < 1 || month > 12 || day < 1 || day > 31) continue;
      final now = DateTime.now();
      final year = month > now.month + 1 ? now.year - 1 : now.year;
      return _buildDate('$year', '$month', '$day');
    }

    return null;
  }

  static DateTime? _buildDate(String? y, String? m, String? d) {
    final year = int.tryParse(y ?? '');
    final month = int.tryParse(m ?? '');
    final day = int.tryParse(d ?? '');
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    if (year < 2000 || year > 2100) return null;
    return DateTime(year, month, day);
  }

  static bool _looksLikeContentLink(String href) {
    if (href.isEmpty) return false;
    final lower = href.toLowerCase();
    if (lower.startsWith('#') ||
        lower.startsWith('javascript') ||
        lower.startsWith('mailto') ||
        lower.startsWith('tel')) {
      return false;
    }
    if (lower.contains('logout') || lower.contains('login')) {
      return false;
    }
    if (_attachmentExt.hasMatch(lower)) {
      return false;
    }
    if (lower.contains('.jsp') ||
        lower.contains('.do') ||
        lower.contains('.action') ||
        lower.contains('.htm') ||
        lower.contains('content') ||
        lower.contains('detail') ||
        lower.contains('article') ||
        lower.contains('/info/') ||
        lower.contains('show') ||
        RegExp(r'[?&]id=\d+').hasMatch(lower)) {
      return true;
    }
    // 相对路径且带数字编号的（如 /2026/1105/c1380a96503/page.htm 已由 .htm 覆盖）
    return RegExp(r'/\d{3,}(/|$|\?)').hasMatch(lower);
  }

  static String _titleOf(dom.Element anchor) {
    final text = _clean(anchor.text);
    final attr = _clean(anchor.attributes['title'] ?? '');
    if (attr.length > text.length && attr.length >= 5) {
      return attr;
    }
    return text;
  }

  /// 从锚点往上找最近一个「文本里含日期」的容器。
  static dom.Element? _containerWithDate(dom.Element anchor) {
    dom.Element? node = anchor.parent;
    for (var depth = 0; depth < 5 && node != null; depth++) {
      if (extractDate(_clean(node.text)) != null) {
        return node;
      }
      node = node.parent;
    }
    return null;
  }

  /// 最近的列表行元素（`li` / `tr` / `dd`）。
  static dom.Element? _rowAncestor(dom.Element anchor) {
    dom.Element? node = anchor.parent;
    for (var depth = 0; depth < 4 && node != null; depth++) {
      final tag = node.localName ?? '';
      if (tag == 'li' || tag == 'tr' || tag == 'dd') {
        return node;
      }
      node = node.parent;
    }
    return null;
  }

  /// 从容器文本里刨掉标题与日期，剩下的短文本当作发布部门。
  ///
  /// [linkText] 是链接上实际显示的文字——列表里的标题常被截断成「关于……
  /// 的通知…」，与完整标题对不上，所以两者都要刨掉，只刨标题会把截断版
  /// 留在结果里导致部门取不到。
  static String _departmentOf(
    String containerText,
    String title,
    String linkText,
  ) {
    var text = containerText;
    if (linkText.length >= 3) {
      text = text.replaceFirst(linkText, ' ');
    }
    if (title.length >= 3) {
      text = text.replaceFirst(title, ' ');
    }
    text = text
        .replaceAll(_dateFull, ' ')
        .replaceAll(_dateCompact, ' ')
        .replaceAll(_dateShort, ' ');
    text = text
        .replaceAll(RegExp(r'[\[\]【】()（）<>《》|·:：,，\-—…\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.isEmpty || text.length > 16) return '';
    if (RegExp(r'^\d+$').hasMatch(text)) return '';
    return text;
  }

  static Uri? _resolve(Uri base, String href) {
    final uri = Uri.tryParse(href);
    if (uri == null) return null;
    try {
      return base.resolveUri(uri);
    } catch (_) {
      return null;
    }
  }

  static String _detailTitle(dom.Document document, String? fallback) {
    for (final selector in const [
      'h1',
      '.title',
      '#title',
      '.article-title',
      '.content-title',
    ]) {
      final element = document.querySelector(selector);
      final text = _clean(element?.text ?? '');
      if (text.length >= 4 && text.length <= 120) {
        return text;
      }
    }

    final pageTitle = _clean(document.querySelector('title')?.text ?? '');
    if (pageTitle.isNotEmpty) {
      // 常见形式：「标题-山东体育学院」/「标题_山东体育学院」
      final cut = pageTitle.split(RegExp(r'\s*[-_|—]\s*')).first.trim();
      if (cut.length >= 4) return cut;
      return pageTitle;
    }

    return fallback ?? '';
  }

  static dom.Element? _pickContent(dom.Document document) {
    for (final selector in const [
      '#vsb_content',
      '.v_news_content',
      '#content',
      '.content',
      '#zoom',
      '.article-content',
      '.article',
      'article',
      '#main-content',
      '.main-content',
      '#showContent',
      '.show-content',
    ]) {
      final element = document.querySelector(selector);
      if (element != null && _clean(element.text).length > 30) {
        return element;
      }
    }

    // 兜底：段落最多、文本最长的容器。比「整页 body」精确一些。
    dom.Element? best;
    var bestScore = 0;
    for (final candidate in document.querySelectorAll('div, td, section')) {
      final paragraphCount = candidate.querySelectorAll('p').length;
      final textLength = _clean(candidate.text).length;
      if (textLength < 40) continue;
      final score = paragraphCount * 100 + textLength;
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    if (best != null) return best;

    // 最后才退回整页：通知详情页通常就是正文，比直接报错好。
    final body = document.body;
    if (body != null && _clean(body.text).length >= 60) {
      return body;
    }
    return null;
  }

  static void _walk(dom.Node node, StringBuffer out, void Function() onImage) {
    if (node is dom.Text) {
      out.write(node.text.replaceAll('\u00a0', ' '));
      return;
    }
    if (node is! dom.Element) {
      for (final child in node.nodes) {
        _walk(child, out, onImage);
      }
      return;
    }

    final tag = node.localName ?? '';
    if (tag == 'script' || tag == 'style' || tag == 'noscript' || tag == 'iframe') {
      return;
    }
    if (tag == 'br') {
      out.write('\n');
      return;
    }
    if (tag == 'img') {
      onImage();
      return;
    }

    final isBlock = _blockTags.contains(tag);
    if (isBlock) out.write('\n');
    for (final child in node.nodes) {
      _walk(child, out, onImage);
    }
    if (isBlock) out.write('\n');
  }

  static List<NoticeAttachment> _attachmentsIn(dom.Element content, Uri base) {
    final result = <NoticeAttachment>[];
    final seen = <String>{};
    for (final anchor in content.querySelectorAll('a')) {
      final href = (anchor.attributes['href'] ?? '').trim();
      if (href.isEmpty || !_attachmentExt.hasMatch(href)) continue;
      final uri = _resolve(base, href);
      if (uri == null) continue;
      final url = uri.toString();
      if (!seen.add(url)) continue;
      final name = _clean(anchor.text).isNotEmpty
          ? _clean(anchor.text)
          : Uri.decodeFull(uri.pathSegments.isEmpty ? url : uri.pathSegments.last);
      result.add(NoticeAttachment(name: name, url: url));
    }
    return result;
  }

  static String _clean(String input) {
    return input
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _cleanMultiline(String input) {
    return input
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }
}
