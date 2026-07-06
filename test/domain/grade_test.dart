import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/features/grades/domain/grade.dart';

void main() {
  group('Grade', () {
    final grade = Grade(
      semester: '2024-2025-1',
      courseName: '高等数学',
      credit: '4',
      score: '92',
      gpa: '4.0',
    );

    test('toJson and fromJson roundtrip', () {
      final json = grade.toJson();
      final restored = Grade.fromJson(json);

      expect(restored.semester, grade.semester);
      expect(restored.courseName, grade.courseName);
      expect(restored.credit, grade.credit);
      expect(restored.score, grade.score);
      expect(restored.gpa, grade.gpa);
    });

    test('fromJson handles missing fields', () {
      final restored = Grade.fromJson({});

      expect(restored.semester, '');
      expect(restored.courseName, '');
      expect(restored.credit, '');
      expect(restored.score, '');
      expect(restored.gpa, '');
    });
  });
}
