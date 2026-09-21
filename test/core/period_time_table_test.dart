import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/core/constants/period_time_table.dart';

/// 官方《教学作息时间安排表》的逐行转录（与官方表格单元格一一对应），
/// 作为断言的期望值。济南第 10 节在官方表中为 `/`，故不入表。
///
/// 官方表不区分夏令时/冬令时，因此这里没有季节维度；`PeriodTimeTable`
/// 的取值也不再接受日期参数，作息全天候唯一。
const Map<String, Map<int, (String, String)>> _official = {
  PeriodTimeTable.campusJinan: {
    1: ('8:00', '8:40'),
    2: ('8:45', '9:25'),
    3: ('9:45', '10:25'),
    4: ('10:30', '11:10'),
    5: ('11:15', '11:55'),
    6: ('14:00', '14:40'),
    7: ('14:45', '15:25'),
    8: ('15:45', '16:25'),
    9: ('16:30', '17:10'),
    11: ('18:30', '19:10'),
    12: ('19:15', '19:55'),
  },
  PeriodTimeTable.campusRizhao: {
    1: ('8:00', '8:40'),
    2: ('8:45', '9:25'),
    3: ('9:45', '10:25'),
    4: ('10:30', '11:10'),
    5: ('11:15', '11:55'),
    6: ('14:00', '14:40'),
    7: ('14:45', '15:25'),
    8: ('15:45', '16:25'),
    9: ('16:30', '17:10'),
    10: ('17:15', '17:55'),
    11: ('19:00', '19:40'),
    12: ('19:45', '20:25'),
  },
};

/// 把官方表的 `8:00` 补零成 `08:00`，用于比对 `formatTimeRange`。
String _pad(String hm) {
  final parts = hm.split(':');
  return '${parts[0].padLeft(2, '0')}:${parts[1]}';
}

void main() {
  group('PeriodTimeTable 与官方作息表逐行一致', () {
    _official.forEach((campus, rows) {
      test('$campus 全部节次的时间与官方表一致', () {
        rows.forEach((period, expected) {
          final (start, end) = expected;
          expect(
            PeriodTimeTable.formatScheduleCell(period, campus: campus),
            '$start\n$end',
            reason: '$campus 第 $period 节的课表格时间',
          );
          expect(
            PeriodTimeTable.formatTimeRange(period, period, campus: campus),
            '${_pad(start)} - ${_pad(end)}',
            reason: '$campus 第 $period 节的时间区间',
          );
          expect(
            PeriodTimeTable.periodStartTime(period, campus: campus),
            _pad(start),
            reason: '$campus 第 $period 节的开始时间',
          );
          expect(
            PeriodTimeTable.periodEndMinutes(period, campus: campus),
            int.parse(end.split(':')[0]) * 60 + int.parse(end.split(':')[1]),
            reason: '$campus 第 $period 节的下课分钟数',
          );
        });
      });
    });

    test('两校区第 1-9 节完全一致', () {
      for (var period = 1; period <= 9; period++) {
        expect(
          PeriodTimeTable.periodStartMinutes(period,
              campus: PeriodTimeTable.campusJinan),
          PeriodTimeTable.periodStartMinutes(period,
              campus: PeriodTimeTable.campusRizhao),
          reason: '第 $period 节开始时间应一致',
        );
        expect(
          PeriodTimeTable.periodEndMinutes(period,
              campus: PeriodTimeTable.campusJinan),
          PeriodTimeTable.periodEndMinutes(period,
              campus: PeriodTimeTable.campusRizhao),
          reason: '第 $period 节结束时间应一致',
        );
      }
    });

    test('济南没有第 10 节（官方表中为 /），日照第 10 节为 17:15-17:55', () {
      expect(
        PeriodTimeTable.periodStartMinutes(10,
            campus: PeriodTimeTable.campusJinan),
        isNull,
      );
      expect(
        PeriodTimeTable.periodEndMinutes(10,
            campus: PeriodTimeTable.campusJinan),
        isNull,
      );
      expect(
        PeriodTimeTable.formatScheduleCell(10,
            campus: PeriodTimeTable.campusJinan),
        '',
      );
      expect(
        PeriodTimeTable.periodStartTime(10,
            campus: PeriodTimeTable.campusRizhao),
        '17:15',
      );
    });

    test('第 11-12 节两校区不同：济南早于日照', () {
      expect(
        PeriodTimeTable.periodStartMinutes(11,
            campus: PeriodTimeTable.campusJinan),
        18 * 60 + 30,
      );
      expect(
        PeriodTimeTable.periodStartMinutes(11,
            campus: PeriodTimeTable.campusRizhao),
        19 * 60,
      );
      expect(
        PeriodTimeTable.periodEndMinutes(12,
            campus: PeriodTimeTable.campusJinan),
        19 * 60 + 55,
      );
      expect(
        PeriodTimeTable.periodEndMinutes(12,
            campus: PeriodTimeTable.campusRizhao),
        20 * 60 + 25,
      );
    });

    test('未知校区按济南处理', () {
      expect(
        PeriodTimeTable.periodStartMinutes(1, campus: '北京'),
        PeriodTimeTable.periodStartMinutes(1,
            campus: PeriodTimeTable.campusJinan),
      );
    });
  });

  group('endMinutesForUnit', () {
    test('存在的节次返回其下课时间', () {
      expect(
        PeriodTimeTable.endMinutesForUnit(3,
            campus: PeriodTimeTable.campusJinan),
        10 * 60 + 25,
      );
      expect(
        PeriodTimeTable.endMinutesForUnit(10,
            campus: PeriodTimeTable.campusRizhao),
        17 * 60 + 55,
      );
    });

    test('不存在的节次回退到 23:59，使课程保持可见而不被误判为已下课', () {
      expect(
        PeriodTimeTable.endMinutesForUnit(10,
            campus: PeriodTimeTable.campusJinan),
        23 * 60 + 59,
      );
    });
  });

  group('sessionForPeriod（官方表的“时段”列）', () {
    test('上午 1-5 节、下午 6-10 节、晚上 11-12 节', () {
      for (var period = 1; period <= 5; period++) {
        expect(PeriodTimeTable.sessionForPeriod(period), ClassSession.morning,
            reason: '第 $period 节属于上午');
      }
      for (var period = 6; period <= 10; period++) {
        expect(PeriodTimeTable.sessionForPeriod(period), ClassSession.afternoon,
            reason: '第 $period 节属于下午');
      }
      for (var period = 11; period <= 12; period++) {
        expect(PeriodTimeTable.sessionForPeriod(period), ClassSession.evening,
            reason: '第 $period 节属于晚上');
      }
    });

    test('两个边界节次：第 5 节是上午（11:15），日照第 10 节是下午（17:15）', () {
      // 这两个节次按“时间阈值”推断会分别落到下午与晚上，必须按官方表的
      // 时段列（节次区间）判定才正确。
      expect(PeriodTimeTable.sessionForPeriod(5), ClassSession.morning);
      expect(PeriodTimeTable.sessionForPeriod(10), ClassSession.afternoon);
    });
  });
}
