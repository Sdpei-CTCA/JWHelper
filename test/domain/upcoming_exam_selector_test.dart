import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/app/domain/upcoming_exam_selector.dart';
import 'package:JWHelper/features/exam/domain/exam.dart';

Exam _exam(String name, String time) {
  return Exam(
    courseName: name,
    courseNo: '001',
    time: time,
    location: '教学楼',
    classNo: '1',
    type: 'Final',
    applyStatus: '',
  );
}

void main() {
  group('UpcomingExamSelector', () {
    test('filters past exams and sorts by time', () {
      final now = DateTime.now();
      final past = now.subtract(const Duration(days: 1));
      final future1 = now.add(const Duration(days: 1));
      final future2 = now.add(const Duration(days: 2));

      final exams = [
        _exam('C', future2.toIso8601String()),
        _exam('A', past.toIso8601String()),
        _exam('B', future1.toIso8601String()),
      ];

      final selected = UpcomingExamSelector.select(exams);
      expect(selected.length, 2);
      expect(selected[0].courseName, 'B');
      expect(selected[1].courseName, 'C');
    });

    test('limits to 2 exams by default', () {
      final now = DateTime.now();
      final exams = List.generate(
        4,
        (i) => _exam('E$i', now.add(Duration(days: i + 1)).toIso8601String()),
      );

      final selected = UpcomingExamSelector.select(exams);
      expect(selected.length, 2);
    });

    test('keeps unparseable time exams but sorts them last', () {
      final now = DateTime.now();
      final exams = [
        _exam('Unknown', '待定'),
        _exam('Soon', now.add(const Duration(days: 1)).toIso8601String()),
      ];

      final selected = UpcomingExamSelector.select(exams);
      expect(selected.first.courseName, 'Soon');
      expect(selected.last.courseName, 'Unknown');
    });
  });
}
