import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/features/exam/domain/exam.dart';

class ExamSelection {
  final String semId;
  final String roundId;
  final String campus;

  const ExamSelection({
    required this.semId,
    required this.roundId,
    required this.campus,
  });
}

class ExamSelectionCoordinator {
  static const defaultCampus = '济南';

  static Future<String> loadCampus({String? username}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (username != null && username.isNotEmpty) {
        final userCampus = prefs.getString('campus_$username');
        if (userCampus == '济南' || userCampus == '日照') {
          return userCampus!;
        }
      }
      final saved = prefs.getString('campus');
      if (saved == '济南' || saved == '日照') {
        return saved!;
      }
    } catch (_) {}
    return defaultCampus;
  }

  static List<ExamRound> sortRounds(List<ExamRound> rounds, String campus) {
    if (rounds.isEmpty) return [];
    final sorted = List<ExamRound>.from(rounds);
    sorted.sort((a, b) {
      final aIsCurrent = a.name.contains(campus);
      final bIsCurrent = b.name.contains(campus);
      if (aIsCurrent && !bIsCurrent) return -1;
      if (!aIsCurrent && bIsCurrent) return 1;
      return 0;
    });
    return sorted;
  }

  static ExamRound? selectRound(List<ExamRound> rounds, String campus) {
    if (rounds.isEmpty) return null;
    final sorted = sortRounds(rounds, campus);
    try {
      return sorted.firstWhere(
        (r) => r.name.contains(campus) && r.name.contains('期末考试'),
      );
    } catch (_) {
      return sorted.first;
    }
  }

  static ExamSelection? resolve({
    required List<Semester> semesters,
    required List<ExamRound> rounds,
    required String campus,
  }) {
    if (semesters.isEmpty) return null;
    final round = selectRound(rounds, campus);
    if (round == null) return null;
    return ExamSelection(
      semId: semesters.first.id,
      roundId: round.id,
      campus: campus,
    );
  }
}
