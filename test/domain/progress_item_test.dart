import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/features/progress/data/progress_service.dart';
import 'package:JWHelper/features/progress/domain/progress_item.dart';

void main() {
  group('Progress domain models', () {
    test('ProgressGroup toJson and fromJson roundtrip', () {
      final group = ProgressGroup(
        id: 'g1',
        name: '专业必修',
        required: 20,
        earned: 15,
        courses: [
          ProgressCourse(
            name: '编译原理',
            credit: '3',
            score: '88',
            isPassed: true,
          ),
        ],
      );

      final restored = ProgressGroup.fromJson(group.toJson());
      expect(restored.id, group.id);
      expect(restored.name, group.name);
      expect(restored.required, group.required);
      expect(restored.earned, group.earned);
      expect(restored.courses, hasLength(1));
      expect(restored.courses!.first.name, '编译原理');
    });

    test('ProgressInfo toJson and fromJson roundtrip', () {
      final info = ProgressInfo(label: '平均绩点', value: '3.6');
      final restored = ProgressInfo.fromJson(info.toJson());

      expect(restored.label, info.label);
      expect(restored.value, info.value);
    });

    test('parseProgressHtml falls back to 课程要求最低学分 when 未设置', () {
      const html = '''
        <html><body>
          <span id="lblMainAvgCreditHour">3.5</span>
          <span id="lblAcquiredCreditsInProg2">12</span>
          <span id="lblLeastCreditsOfProg">未设置</span>
          <div>（课程要求最低学分：6）</div>
          <table id="tableTree">
            <tr>
              <td><a id="childA24233">通识选修(4/未设置)</a>（课程要求最低学分：6）</td>
            </tr>
          </table>
        </body></html>
      ''';

      final parsed = ProgressService.parseProgressHtmlForTest(html);
      final info = parsed['info'] as List<ProgressInfo>;
      final groups = parsed['groups'] as List<ProgressGroup>;

      final minInfo = info.firstWhere((i) => i.label == '要求最低学分');
      expect(minInfo.value, '6');
      expect(groups, hasLength(1));
      expect(groups.first.required, 6.0);
    });

    test('parseRequiredCreditsFromGroupResponse extracts fallback credits', () {
      expect(
        ProgressService.parseRequiredCreditsFromGroupResponse({
          'Datas': [],
          'Title': '通识选修（课程要求最低学分：6）',
        }),
        6.0,
      );
      expect(
        ProgressService.parseRequiredCreditsFromGroupResponse({
          'Datas': [],
          'LeastCredit': 8,
        }),
        8.0,
      );
      expect(
        ProgressService.parseRequiredCreditsFromGroupResponse(
          null,
          rawText: '<div>课程要求最低学分: 12.5</div>',
        ),
        12.5,
      );
    });
  });
}
