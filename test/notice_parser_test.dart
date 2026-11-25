import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/features/notice/data/notice_parser.dart';

void main() {
  final baseUri = Uri.parse('https://pubinfo.sdpei.edu.cn/index.jsp');

  group('列表解析', () {
    test('从 ul/li 结构里认出标题、部门与日期', () {
      const html = '''
<html><body>
  <div class="nav">
    <a href="index.jsp">首页</a>
    <a href="login.jsp">登录</a>
    <a href="list.jsp?id=2">更多</a>
  </div>
  <ul class="news-list">
    <li>
      <span class="dept">教务处</span>
      <a href="/2026/1120/c1234a5678/page.htm"
         title="关于2026-2027学年第一学期期末考试安排的通知">关于2026-2027学年第一学期期末考试安排…</a>
      <span class="date">2026-11-20</span>
    </li>
    <li>
      <span class="dept">学生工作处</span>
      <a href="/2026/1118/c1234a5600/page.htm">关于开展冬季安全教育主题班会的通知</a>
      <span class="date">2026-11-18</span>
    </li>
  </ul>
</body></html>
''';

      final result = NoticeParser.parseList(html, baseUri);

      expect(result.items.length, 2, reason: '导航链接不应被当成通知');
      expect(result.items.first.title, '关于2026-2027学年第一学期期末考试安排的通知');
      expect(result.items.first.publishedAt, DateTime(2026, 11, 20));
      expect(result.items.first.department, '教务处');
      expect(result.items.first.url,
          'https://pubinfo.sdpei.edu.cn/2026/1120/c1234a5678/page.htm');
      expect(result.items.last.publishedAt, DateTime(2026, 11, 18));
      // 倒序：新的在前
      expect(result.items.first.publishedAt!.isAfter(result.items.last.publishedAt!),
          isTrue);
    });

    test('表格布局同样能解析', () {
      const html = '''
<html><body>
<table class="list">
  <tr><th>标题</th><th>部门</th><th>日期</th></tr>
  <tr>
    <td><a href="detail.jsp?id=101">关于做好2027届毕业生图像采集工作的通知</a></td>
    <td>教务处</td>
    <td>2026/11/22</td>
  </tr>
  <tr>
    <td><a href="detail.jsp?id=102">2026年冬季校园招聘会安排</a></td>
    <td>就业指导中心</td>
    <td>2026/11/21</td>
  </tr>
</table>
</body></html>
''';

      final result = NoticeParser.parseList(html, baseUri);

      expect(result.items.length, 2);
      expect(result.items.first.title, '关于做好2027届毕业生图像采集工作的通知');
      expect(result.items.first.publishedAt, DateTime(2026, 11, 22));
      expect(result.items.first.department, '教务处');
    });

    test('没有日期的列表行仍然保留，但纯导航链接被过滤', () {
      const html = '''
<html><body>
  <a href="index.jsp">首页</a>
  <ul>
    <li><a href="/info/1024/1234.htm">关于公布教学改革立项名单的通知</a></li>
  </ul>
</body></html>
''';

      final result = NoticeParser.parseList(html, baseUri);

      expect(result.items.length, 1);
      expect(result.items.single.publishedAt, isNull);
    });

    test('同一链接重复出现只保留一条', () {
      const html = '''
<html><body>
  <ul>
    <li><a href="/2026/1120/c1a2/page.htm">关于开展实验室安全检查的通知</a> 2026-11-20</li>
    <li><a href="/2026/1120/c1a2/page.htm">关于开展实验室安全检查的通知</a> 2026-11-20</li>
  </ul>
</body></html>
''';

      final result = NoticeParser.parseList(html, baseUri);
      expect(result.items.length, 1);
    });

    test('页面里没有任何通知时返回空列表而不是抛异常', () {
      const html = '<html><body><h1>系统维护中</h1></body></html>';
      final result = NoticeParser.parseList(html, baseUri);
      expect(result.items, isEmpty);
    });

    test('解析失败时能给出可反馈的结构摘要', () {
      const html = '''
<html><body>
  <div id="main" class="notice-list">
    <a href="/2026/1101/c1a1/page.htm">关于做好期末考试安排的通知</a>
    <a href="/2026/1102/c1a2/page.htm">关于开展教学检查工作的通知</a>
  </div>
</body></html>
''';
      final summary = NoticeParser.summarizeStructure(html, baseUri);

      expect(summary, contains('div#main.notice-list'));
      expect(summary, contains('2 链接'));
      expect(summary, contains('/2026/1101/c1a1/page.htm'));
    });
  });

  group('详情解析', () {
    const html = '''
<html><head><title>关于开展实验室安全检查的通知-山东体育学院</title></head>
<body>
  <h1>关于开展实验室安全检查的通知</h1>
  <div class="info">教务处 2026-11-20</div>
  <div id="vsb_content">
    <p>各教学单位：</p>
    <p>为进一步加强实验室安全管理，定于本周开展专项检查。</p>
    <p>请各单位做好准备。<br>特此通知。</p>
    <p><img src="/upload/2026/11/20/a.jpg"></p>
    <p><a href="/upload/files/check-list.pdf">实验室安全检查表.pdf</a></p>
  </div>
</body></html>
''';

    test('正文段落、图片标记与附件都能取到', () {
      final detail = NoticeParser.parseDetail(
        html,
        Uri.parse('https://pubinfo.sdpei.edu.cn/2026/1120/c1a2/page.htm'),
      );

      expect(detail.title, '关于开展实验室安全检查的通知');
      expect(detail.paragraphs.first, '各教学单位：');
      expect(detail.paragraphs.any((p) => p.contains('专项检查')), isTrue);
      expect(detail.paragraphs.any((p) => p.contains('特此通知')), isTrue);
      expect(detail.hasImages, isTrue);
      expect(detail.attachments.length, 1);
      expect(detail.attachments.single.name, '实验室安全检查表.pdf');
      expect(detail.attachments.single.url,
          'https://pubinfo.sdpei.edu.cn/upload/files/check-list.pdf');
    });

    test('没有明确正文容器时也能兜底取到文字', () {
      const plain = '''
<html><body>
  <div><div><p>第一段内容，足够长以便通过正文长度判断。</p>
  <p>第二段内容，同样需要有一定的长度，避免被当作空白页。</p></div></div>
</body></html>
''';
      final detail = NoticeParser.parseDetail(
        plain,
        Uri.parse('https://pubinfo.sdpei.edu.cn/2026/1120/c9a9/page.htm'),
        fallbackTitle: '兜底标题',
      );

      expect(detail.paragraphs, isNotEmpty);
      expect(detail.isEmpty, isFalse);
    });
  });

  group('日期识别', () {
    test('跳过不成立的年份区间，取真正的发布日期', () {
      final date = NoticeParser.extractDate('关于2026-2027学年期末考试 2026-11-20');
      expect(date, DateTime(2026, 11, 20));
    });

    test('支持中文日期与紧凑格式', () {
      expect(NoticeParser.extractDate('2026年11月20日'), DateTime(2026, 11, 20));
      expect(NoticeParser.extractDate('20261120'), DateTime(2026, 11, 20));
    });

    test('没有日期时返回 null', () {
      expect(NoticeParser.extractDate('关于期末考试安排的通知'), isNull);
    });
  });
}
