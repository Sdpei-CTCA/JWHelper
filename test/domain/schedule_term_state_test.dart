import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/app/domain/schedule_term_state.dart';

void main() {
  group('ScheduleTermState', () {
    test('isTermUnavailable when schedule empty and no start day', () {
      expect(
        ScheduleTermState.isTermUnavailable(schedule: [], startDay: null),
        isTrue,
      );
      expect(
        ScheduleTermState.isTermUnavailable(schedule: [], startDay: ''),
        isTrue,
      );
    });

    test('not unavailable when schedule has items', () {
      expect(
        ScheduleTermState.isTermUnavailable(
          schedule: const [{'name': 'Math'}],
          startDay: null,
        ),
        isFalse,
      );
    });

    test('not unavailable when start day exists even if schedule empty', () {
      expect(
        ScheduleTermState.isTermUnavailable(
          schedule: [],
          startDay: '2025-09-01',
        ),
        isFalse,
      );
    });
  });
}
