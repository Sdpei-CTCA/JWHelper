import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/features/notice/data/notice_parser.dart';

void main() {
  final origin = Uri.parse('https://pubinfo.sdpei.edu.cn');

  group('列表接口解析', () {
    // 取自真实接口的裁剪样本，字段名与取值保持不变。
    const rawJson = '''
{
  "iTotalRecords": 88,
  "aaData": [
    {
      "ms_id": 21707,
      "ms_title": "关于智慧考勤系统升级的通知",
      "ms_link": "",
      "sffj": 1,
      "releasetime": 1792891499086,
      "create_time": 1792891499086,
      "dwbzmc": "网络信息中心"
    },
    {
      "ms_id": 21636,
      "ms_title": "易校园使用说明",
      "ms_link": "https://static.sdpei.edu.cn/yingxin/help.html",
      "sffj": 0,
      "releasetime": 1724468207362,
      "dwbzmc": "网络信息中心"
    },
    {
      "ms_id": 21500,
      "ms_title": "   ",
      "sffj": 0
    }
  ]
}
''';

    test('取出主键、标题、部门、时间与附件标记', () {
      final json = jsonDecode(rawJson) as Map<String, dynamic>;
      final items = NoticeParser.parseListJson(json, origin);

      expect(items.length, 2, reason: '标题为空的行应被丢弃');
      expect(items.first.id, '21707');
      expect(items.first.title, '关于智慧考勤系统升级的通知');
      expect(items.first.department, '网络信息中心');
      expect(items.first.hasAttachment, isTrue);
      expect(items.first.publishedAt,
          DateTime.fromMillisecondsSinceEpoch(1792891499086));
      expect(items.first.url,
          'https://pubinfo.sdpei.edu.cn/page/infomation/infoxq.jsp?id=21707');
      expect(items.last.hasAttachment, isFalse);
    });

    test('保持接口顺序，不按时间重排（置顶通知要留在前面）', () {
      final json = jsonDecode(rawJson) as Map<String, dynamic>;
      final items = NoticeParser.parseListJson(json, origin);

      expect(items.first.id, '21707');
      expect(
        items.first.publishedAt!.isAfter(items.last.publishedAt!),
        isTrue,
        reason: '这条样本里接口顺序恰好也是时间倒序',
      );
    });

    test('缺少 aaData 时返回空列表而不是抛异常', () {
      expect(NoticeParser.parseListJson({}, origin), isEmpty);
      expect(NoticeParser.parseListJson({'aaData': 'oops'}, origin), isEmpty);
    });
  });

  group('详情接口解析', () {
    const rawJson = '''
{
  "ms_id": 21707,
  "ms_title": "关于智慧考勤系统升级的通知",
  "ms_link": "",
  "releasetime": 1792891499086,
  "content": "<p>各位同学：</p><p>&nbsp;&nbsp;&nbsp;结合前期反馈，系统计划于本周日升级。<br/></p><p><img src=\\"http://x/a.jpg\\"/></p>",
  "fj": [
    {"mia_id": 35257, "ms_id": 21707, "fjname": "操作说明-学生分册.pdf", "suffix": "pdf"}
  ],
  "fj_count": 1
}
''';

    test('正文转段落，附件与图片标记都能取到', () {
      final json = jsonDecode(rawJson) as Map<String, dynamic>;
      final detail = NoticeParser.parseDetailJson(json, origin);

      expect(detail.title, '关于智慧考勤系统升级的通知');
      expect(detail.paragraphs.length, 2);
      expect(detail.paragraphs.first, '各位同学：');
      expect(detail.paragraphs.last.contains('系统计划于本周日升级'), isTrue);
      // &nbsp; 与缩进不应留在正文里
      expect(detail.paragraphs.last.startsWith('结合'), isTrue);
      expect(detail.hasImages, isTrue);
      expect(detail.attachments.length, 1);
      expect(detail.attachments.single.name, '操作说明-学生分册.pdf');
      expect(detail.attachments.single.suffix, 'pdf');
      expect(detail.attachments.single.url,
          'https://pubinfo.sdpei.edu.cn/info/downfile?id=35257&infoid=21707');
      expect(detail.url,
          'https://pubinfo.sdpei.edu.cn/page/infomation/infoxq.jsp?id=21707');
      expect(detail.isEmpty, isFalse);
    });

    test('外部链接会被保留', () {
      final detail = NoticeParser.parseDetailJson({
        'ms_id': 21636,
        'ms_title': '易校园使用说明',
        'ms_link': 'https://static.sdpei.edu.cn/yingxin/help.html',
        'content': '<p>详见链接。</p>',
      }, origin);

      expect(detail.externalLink,
          'https://static.sdpei.edu.cn/yingxin/help.html');
    });

    test('没有正文时 isEmpty 为真，交给界面提示看原文', () {
      final detail = NoticeParser.parseDetailJson({
        'ms_id': 1,
        'ms_title': '只有附件的通知',
        'content': '',
      }, origin);

      expect(detail.isEmpty, isTrue);
    });
  });

  group('正文 HTML 转段落', () {
    test('br 与块级标签都当换行，表格单元格不会粘成一行', () {
      final paragraphs = NoticeParser.contentToParagraphs(
        '<div>第一行<br/>第二行</div><table><tr><td>甲</td><td>乙</td></tr></table>',
      );

      expect(paragraphs, contains('第一行'));
      expect(paragraphs, contains('第二行'));
      expect(paragraphs, contains('甲'));
      expect(paragraphs, contains('乙'));
    });

    test('空内容返回空列表', () {
      expect(NoticeParser.contentToParagraphs('   '), isEmpty);
      expect(NoticeParser.contentToParagraphs('<p></p>'), isEmpty);
    });
  });

  group('失败诊断', () {
    test('响应片段会被截断成可复制的文本', () {
      final summary = NoticeParser.summarizeBody('x' * 900);
      expect(summary.contains('响应长度 900'), isTrue);
      expect(summary.length < 500, isTrue);
    });
  });
}
