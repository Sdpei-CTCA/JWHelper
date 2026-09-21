import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/core/constants/period_time_table.dart';

/// 原生端作息表与 Dart 正本的同步校验。
///
/// 作息表在三个平台各有一份硬编码副本（Dart / Kotlin / Swift）。历史上已经因为
/// 只改了其中一份而导致同一节课在三端显示的时间不一致，本测试直接解析原生源文件
/// 里的数值并与 [PeriodTimeTable] 逐项比对，把“漏改一份”变成 CI 上的失败。
///
/// 解析依赖源文件中 map 的书写格式（Kotlin 的 `N to H * 60 + M`、Swift 的
/// `N: H * 60 + M`）。若原生侧被格式化工具改写导致解析不到，测试会明确报出
/// 找不到声明的 map，按提示调整 [parseTable] 即可。
void main() {
  group('原生作息表与 Dart 正本保持同步', () {
    final kotlin = File(
      'android/app/src/main/kotlin/edu/sdpei/JWSystem/ScheduleWidgetTimeTable.kt',
    );
    final swift = File('ios/ScheduleWidget/WidgetShared.swift');

    test('Kotlin ScheduleWidgetTimeTable 与 Dart 一致', () {
      final source = kotlin.readAsStringSync();
      _expectCampusMatches('Kotlin 济南', {
        'start': parseTable(source, 'jinanStartMinutes'),
        'end': parseTable(source, 'jinanEndMinutes'),
      }, PeriodTimeTable.campusJinan);
      _expectCampusMatches('Kotlin 日照', {
        'start': parseTable(source, 'rizhaoStartMinutes'),
        'end': parseTable(source, 'rizhaoEndMinutes'),
      }, PeriodTimeTable.campusRizhao);
    });

    test('Swift WidgetTimeTable 与 Dart 一致', () {
      final source = swift.readAsStringSync();
      _expectCampusMatches('Swift 济南', {
        'start': parseTable(source, 'jinanStartMinutes'),
        'end': parseTable(source, 'jinanEndMinutes'),
      }, PeriodTimeTable.campusJinan);
      _expectCampusMatches('Swift 日照', {
        'start': parseTable(source, 'rizhaoStartMinutes'),
        'end': parseTable(source, 'rizhaoEndMinutes'),
      }, PeriodTimeTable.campusRizhao);
    });
  });
}

void _expectCampusMatches(
  String label,
  Map<String, Map<int, int>> actual,
  String campus,
) {
  final expectedStarts = <int, int>{};
  final expectedEnds = <int, int>{};
  for (var period = 1; period <= 12; period++) {
    final start = PeriodTimeTable.periodStartMinutes(period, campus: campus);
    final end = PeriodTimeTable.periodEndMinutes(period, campus: campus);
    if (start != null) expectedStarts[period] = start;
    if (end != null) expectedEnds[period] = end;
  }

  expect(
    actual['start']!.keys.toSet(),
    expectedStarts.keys.toSet(),
    reason: '$label 的节次集合与 Dart 正本不一致（多出或缺少节次）',
  );
  expect(
    actual['end']!.keys.toSet(),
    expectedEnds.keys.toSet(),
    reason: '$label 的节次集合与 Dart 正本不一致（多出或缺少节次）',
  );

  expectedStarts.forEach((period, minutes) {
    expect(
      actual['start']![period],
      minutes,
      reason: '$label 第 $period 节的开始时间与 Dart 正本不一致'
          '（原生 ${actual['start']![period]} 分 vs Dart $minutes 分）',
    );
  });
  expectedEnds.forEach((period, minutes) {
    expect(
      actual['end']![period],
      minutes,
      reason: '$label 第 $period 节的结束时间与 Dart 正本不一致'
          '（原生 ${actual['end']![period]} 分 vs Dart $minutes 分）',
    );
  });
}

/// 从原生源文件中解析形如 `name = mapOf(` / `name: [Int: Int] = [` 的节次映射，
/// 返回 节次 -> 零点起的分钟数。
Map<int, int> parseTable(String source, String name) {
  final lines = source.split(RegExp(r'\r?\n'));
  final header = lines.indexWhere(
    (line) => line.contains(name) && (line.contains('mapOf(') || line.contains('= [')),
  );
  if (header < 0) {
    fail('在原生源文件中找不到 "$name" 的声明。'
        '若原生侧改变了书写格式，请同步更新本测试的解析逻辑。');
  }

  final entry = RegExp(r'^(\d+)\s*(?:to|:)\s*(.+?),?$');
  final table = <int, int>{};
  for (var i = header + 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line == ')' || line == ']') break;
    final match = entry.firstMatch(line);
    if (match == null) continue;
    table[int.parse(match.group(1)!)] = parseMinutesExpression(match.group(2)!);
  }
  if (table.isEmpty) {
    fail('"$name" 未解析出任何节次，请检查解析逻辑。');
  }
  return table;
}

/// 计算 `8 * 60 + 45` 这类仅含数字、`*`、`+` 的分钟表达式。
int parseMinutesExpression(String expression) {
  var total = 0;
  for (final term in expression.split('+')) {
    final factors = term.split('*').map((f) => int.parse(f.trim()));
    total += factors.reduce((a, b) => a * b);
  }
  return total;
}
