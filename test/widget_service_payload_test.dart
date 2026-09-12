import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/core/constants/class_schedule.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';
import 'package:JWHelper/infrastructure/platform/widget_service.dart';

/// `WidgetService.encodeScheduleItems` 是小组件时间信息的唯一出口：
/// 它在服务端（Dart 侧）就把每条课程解析出 `timeRange`（展示）与
/// `endTime`（判定），原生两端只读不算。这些用例锁住三端一致的行为：
/// * 济南第 10 节缺行 -> 空字符串（端上保持课程可见、不做下课判定）；
/// * 日照第 10 节 -> 17:15 - 17:55（与济南不同）；
/// * 原始 toJson 字段完整保留（缓存兼容）。
void main() {
  ScheduleItem buildItem({
    String name = '高等数学',
    int startUnit = 1,
    int endUnit = 2,
  }) {
    return ScheduleItem(
      name: name,
      teacher: '小洁',
      classroom: '东教楼123',
      dayIndex: 0,
      startUnit: startUnit,
      endUnit: endUnit,
      weekStart: 1,
      weekEnd: 16,
    );
  }

  Map<String, dynamic> firstOf(String json) =>
      (jsonDecode(json) as List<dynamic>).first as Map<String, dynamic>;

  group('WidgetService.encodeScheduleItems', () {
    test('济南：附加 timeRange 与 endTime', () {
      final first = firstOf(WidgetService.encodeScheduleItems(
        [buildItem(startUnit: 1, endUnit: 2)],
        ClassSchedule.campusJinan,
      ));
      expect(first['timeRange'], '08:00 - 09:25');
      expect(first['endTime'], '09:25');
    });

    test('日照第 10 节：使用日照作息（17:15 - 17:55）', () {
      final first = firstOf(WidgetService.encodeScheduleItems(
        [buildItem(startUnit: 10, endUnit: 10)],
        ClassSchedule.campusRizhao,
      ));
      expect(first['timeRange'], '17:15 - 17:55');
      expect(first['endTime'], '17:55');
    });

    test('济南第 10 节缺行：时间字段为空字符串，端上不隐藏课程', () {
      final first = firstOf(WidgetService.encodeScheduleItems(
        [buildItem(startUnit: 10, endUnit: 10)],
        ClassSchedule.campusJinan,
      ));
      expect(first['timeRange'], '');
      expect(first['endTime'], '');
    });

    test('校区为 null 时按济南解析', () {
      final first = firstOf(WidgetService.encodeScheduleItems(
        [buildItem(startUnit: 11, endUnit: 11)],
        null,
      ));
      expect(first['timeRange'], '18:30 - 19:10');
      expect(first['endTime'], '19:10');
    });

    test('完整保留 ScheduleItem.toJson 的原始字段（缓存兼容）', () {
      final first = firstOf(WidgetService.encodeScheduleItems(
        [buildItem()],
        ClassSchedule.campusJinan,
      ));
      expect(first['name'], '高等数学');
      expect(first['teacher'], '小洁');
      expect(first['classroom'], '东教楼123');
      expect(first['dayIndex'], 0);
      expect(first['startUnit'], 1);
      expect(first['endUnit'], 2);
      expect(first['weekStart'], 1);
      expect(first['weekEnd'], 16);
    });

    test('空列表序列化为空 JSON 数组', () {
      expect(
        WidgetService.encodeScheduleItems(const [], ClassSchedule.campusJinan),
        '[]',
      );
    });
  });
}
