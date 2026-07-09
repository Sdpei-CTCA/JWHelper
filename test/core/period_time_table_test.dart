import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/core/constants/period_time_table.dart';

void main() {
  group('PeriodTimeTable', () {
    test('jinan period 2 matches ScheduleWidgetTimeTable', () {
      final date = DateTime(2026, 7, 6);
      expect(
        PeriodTimeTable.periodStartTime(
          2,
          campus: PeriodTimeTable.campusJinan,
          date: date,
        ),
        '08:45',
      );
      expect(
        PeriodTimeTable.periodEndMinutes(
          2,
          campus: PeriodTimeTable.campusJinan,
          date: date,
        ),
        9 * 60 + 30,
      );
      expect(
        PeriodTimeTable.formatTimeRange(
          2,
          2,
          campus: PeriodTimeTable.campusJinan,
          date: date,
        ),
        '08:45 - 09:30',
      );
    });

    test('rizhao summer afternoon uses summer times', () {
      final date = DateTime(2026, 7, 6);
      expect(PeriodTimeTable.isSummer(date), isTrue);
      expect(
        PeriodTimeTable.periodStartTime(
          5,
          campus: PeriodTimeTable.campusRizhao,
          date: date,
        ),
        '14:30',
      );
      expect(
        PeriodTimeTable.periodEndMinutes(
          5,
          campus: PeriodTimeTable.campusRizhao,
          date: date,
        ),
        15 * 60 + 10,
      );
    });

    test('rizhao winter afternoon uses winter times', () {
      final date = DateTime(2026, 11, 6);
      expect(PeriodTimeTable.isSummer(date), isFalse);
      expect(
        PeriodTimeTable.periodStartTime(
          5,
          campus: PeriodTimeTable.campusRizhao,
          date: date,
        ),
        '14:00',
      );
      expect(
        PeriodTimeTable.periodEndMinutes(
          5,
          campus: PeriodTimeTable.campusRizhao,
          date: date,
        ),
        14 * 60 + 40,
      );
    });

    test('may is summer and october is winter', () {
      expect(PeriodTimeTable.isSummer(DateTime(2026, 5, 1)), isTrue);
      expect(PeriodTimeTable.isSummer(DateTime(2026, 10, 1)), isFalse);
    });
  });
}
