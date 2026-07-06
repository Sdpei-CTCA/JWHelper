import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/app/coordinators/exam_selection_coordinator.dart';
import 'package:JWHelper/features/exam/domain/exam.dart';

ExamRound _round(String id, String name) => ExamRound(id: id, name: name);

void main() {
  group('ExamSelectionCoordinator', () {
    test('sortRounds prioritizes current campus', () {
      final rounds = [
        _round('1', '日照期末考试'),
        _round('2', '济南期末考试'),
      ];

      final sorted = ExamSelectionCoordinator.sortRounds(rounds, '济南');
      expect(sorted.first.name, contains('济南'));
    });

    test('selectRound prefers campus final exam round', () {
      final rounds = [
        _round('1', '日照补考'),
        _round('2', '济南期末考试'),
        _round('3', '日照期末考试'),
      ];

      final selected = ExamSelectionCoordinator.selectRound(rounds, '济南');
      expect(selected?.id, '2');
    });

    test('selectRound falls back to first sorted round', () {
      final rounds = [
        _round('1', '日照补考'),
        _round('2', '济南补考'),
      ];

      final selected = ExamSelectionCoordinator.selectRound(rounds, '济南');
      expect(selected?.id, '2');
    });

    test('resolve returns selection when semesters and rounds exist', () {
      final semesters = [Semester(id: '2024-1', name: '2024-2025-1')];
      final rounds = [_round('r1', '济南期末考试')];

      final selection = ExamSelectionCoordinator.resolve(
        semesters: semesters,
        rounds: rounds,
        campus: '济南',
      );

      expect(selection?.semId, '2024-1');
      expect(selection?.roundId, 'r1');
      expect(selection?.campus, '济南');
    });
  });
}
