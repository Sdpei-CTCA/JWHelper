import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/features/exam/domain/exam.dart';

void main() {
  group('Exam domain models', () {
    test('Exam toJson and fromJson roundtrip', () {
      final exam = Exam(
        courseName: '数据结构',
        courseNo: 'CS101',
        time: '2025-01-10 09:00',
        location: '考场A',
        classNo: '1',
        type: 'Final',
        applyStatus: '已报名',
      );

      final restored = Exam.fromJson(exam.toJson());
      expect(restored.courseName, exam.courseName);
      expect(restored.courseNo, exam.courseNo);
      expect(restored.time, exam.time);
    });

    test('Semester equality is based on id', () {
      final a = Semester(id: '1', name: '2024-2025-1');
      final b = Semester(id: '1', name: 'Different Name');
      final c = Semester(id: '2', name: '2024-2025-1');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('ExamRound equality is based on id', () {
      final a = ExamRound(id: 'r1', name: '期末');
      final b = ExamRound(id: 'r1', name: 'Other');
      final c = ExamRound(id: 'r2', name: '期末');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
