import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/core/constants/class_schedule.dart';

/// `ClassSchedule` 是课表分组的唯一时间来源（课表页 / Android 小组件 / iOS 小组件
/// 均由它派生），因此这里的边界必须锁死：
/// * 两校区第 1-9 节一致；
/// * 济南没有第 10 节（回退策略防止课程丢分组）；
/// * 第 11/12 节两校区时间不同。
void main() {
  group('ClassSchedule.normalizeCampus', () {
    test('日照原样返回', () {
      expect(ClassSchedule.normalizeCampus('日照'), ClassSchedule.campusRizhao);
    });

    test('济南或未知/空校区都回退到济南', () {
      expect(ClassSchedule.normalizeCampus('济南'), ClassSchedule.campusJinan);
      expect(ClassSchedule.normalizeCampus(null), ClassSchedule.campusJinan);
      expect(ClassSchedule.normalizeCampus(''), ClassSchedule.campusJinan);
      expect(ClassSchedule.normalizeCampus('北京'), ClassSchedule.campusJinan);
    });
  });

  group('ClassSchedule 时间查询', () {
    test('两校区第 1-9 节完全一致', () {
      for (var period = 1; period <= 9; period++) {
        expect(
          ClassSchedule.startTime(ClassSchedule.campusJinan, period),
          ClassSchedule.startTime(ClassSchedule.campusRizhao, period),
          reason: '第 $period 节开始时间应一致',
        );
        expect(
          ClassSchedule.endTime(ClassSchedule.campusJinan, period),
          ClassSchedule.endTime(ClassSchedule.campusRizhao, period),
          reason: '第 $period 节结束时间应一致',
        );
      }
    });

    test('济南没有第 10 节（返回 null），日照第 10 节为 17:15-17:55', () {
      expect(ClassSchedule.startTime(ClassSchedule.campusJinan, 10), isNull);
      expect(ClassSchedule.endTime(ClassSchedule.campusJinan, 10), isNull);
      expect(ClassSchedule.timeRange(ClassSchedule.campusJinan, 10), isNull);
      expect(ClassSchedule.startTime(ClassSchedule.campusRizhao, 10), '17:15');
      expect(ClassSchedule.endTime(ClassSchedule.campusRizhao, 10), '17:55');
    });

    test('第 11/12 节两校区时间不同', () {
      expect(ClassSchedule.startTime(ClassSchedule.campusJinan, 11), '18:30');
      expect(ClassSchedule.startTime(ClassSchedule.campusRizhao, 11), '19:00');
      expect(ClassSchedule.endTime(ClassSchedule.campusJinan, 12), '19:55');
      expect(ClassSchedule.endTime(ClassSchedule.campusRizhao, 12), '20:25');
    });

    test('timeRange 拼接为 "HH:mm-HH:mm"', () {
      expect(
        ClassSchedule.timeRange(ClassSchedule.campusJinan, 1),
        '08:00-08:40',
      );
      expect(
        ClassSchedule.timeRange(ClassSchedule.campusRizhao, 12),
        '19:45-20:25',
      );
    });
  });

  group('ClassSchedule.sessionFor（课表页上午/下午/晚上分组）', () {
    test('按开始时间划界：12:00 前为上午', () {
      expect(
        ClassSchedule.sessionFor(ClassSchedule.campusJinan, 5), // 11:15
        ClassSession.morning,
      );
    });

    test('日照第 10 节（17:15 开始）属于下午', () {
      expect(
        ClassSchedule.sessionFor(ClassSchedule.campusRizhao, 10),
        ClassSession.afternoon,
      );
    });

    test('第 11 节（济南 18:30 / 日照 19:00）属于晚上', () {
      expect(
        ClassSchedule.sessionFor(ClassSchedule.campusJinan, 11),
        ClassSession.evening,
      );
      expect(
        ClassSchedule.sessionFor(ClassSchedule.campusRizhao, 11),
        ClassSession.evening,
      );
    });

    test('缺时间的节次按阈值回退（济南第 10 节 -> 晚上），课程不会丢分组', () {
      expect(
        ClassSchedule.sessionFor(ClassSchedule.campusJinan, 10),
        ClassSession.evening,
      );
    });

    test('回退阈值边界：1-4 上午、5-8 下午、其余晚上', () {
      // 正常校区下验证边界节次的实际归属。
      expect(
        ClassSchedule.sessionFor(ClassSchedule.campusJinan, 4), // 10:30
        ClassSession.morning,
      );
      expect(
        ClassSchedule.sessionFor(ClassSchedule.campusJinan, 6), // 14:00
        ClassSession.afternoon,
      );
      expect(
        ClassSchedule.sessionFor(ClassSchedule.campusRizhao, 9), // 16:30
        ClassSession.afternoon,
      );
    });

    test('未提供校区时按济南处理', () {
      expect(ClassSchedule.sessionFor(null, 1), ClassSession.morning);
      expect(ClassSchedule.sessionFor(null, 11), ClassSession.evening);
    });
  });
}
