import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/features/exam/data/exam_service.dart';
import 'package:JWHelper/features/exam/domain/exam.dart';

class ExamSemestersResult {
  final List<Semester> semesters;

  const ExamSemestersResult({required this.semesters});
}

class ExamRoundsResult {
  final List<ExamRound> rounds;

  const ExamRoundsResult({required this.rounds});
}

class ExamListResult {
  final List<Exam> exams;
  final bool loaded;

  const ExamListResult({required this.exams, required this.loaded});
}

class ExamLoaderUsecase {
  static String semestersKey(String username) => 'exam_semesters_$username';
  static String roundsKey(String semId, String username) => 'exam_rounds_${semId}_$username';
  static String examsKey(String semId, String roundId, String username) => 'exams_${semId}_${roundId}_$username';

  static Future<ExamSemestersResult> loadSemesters({
    required ExamService service,
    required String username,
    required bool forceRefresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final String? cachedData = prefs.getString(semestersKey(username));
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        final semesters = decoded.map((e) => Semester.fromJson(e)).toList();
        return ExamSemestersResult(semesters: semesters);
      }
    }

    try {
      final semesters = await service.getSemesters();
      final String encoded = jsonEncode(semesters.map((e) => e.toJson()).toList());
      await prefs.setString(semestersKey(username), encoded);
      return ExamSemestersResult(semesters: semesters);
    } catch (e) {
      debugPrint('Error loading exam semesters: $e');
      final String? cachedData = prefs.getString(semestersKey(username));
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        final semesters = decoded.map((e) => Semester.fromJson(e)).toList();
        return ExamSemestersResult(semesters: semesters);
      }
      rethrow;
    }
  }

  static Future<ExamRoundsResult> loadRounds({
    required ExamService service,
    required String username,
    required String semId,
    required bool forceRefresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = roundsKey(semId, username);

    if (!forceRefresh) {
      final String? cachedData = prefs.getString(key);
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        final rounds = decoded.map((e) => ExamRound.fromJson(e)).toList();
        return ExamRoundsResult(rounds: rounds);
      }
    }

    try {
      final rounds = await service.getExamRounds(semId);
      final String encoded = jsonEncode(rounds.map((e) => e.toJson()).toList());
      await prefs.setString(key, encoded);
      return ExamRoundsResult(rounds: rounds);
    } catch (e) {
      debugPrint('Error loading exam rounds: $e');
      final String? cachedData = prefs.getString(key);
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        final rounds = decoded.map((e) => ExamRound.fromJson(e)).toList();
        return ExamRoundsResult(rounds: rounds);
      }
      rethrow;
    }
  }

  static Future<ExamListResult> loadExams({
    required ExamService service,
    required String username,
    required String semId,
    required String roundId,
    required bool forceRefresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = examsKey(semId, roundId, username);

    if (!forceRefresh) {
      final String? cachedData = prefs.getString(key);
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        final exams = decoded.map((e) => Exam.fromJson(e)).toList();
        return ExamListResult(exams: exams, loaded: true);
      }
    }

    try {
      final exams = await service.getExamList(semId, roundId);
      final String encoded = jsonEncode(exams.map((e) => e.toJson()).toList());
      await prefs.setString(key, encoded);
      return ExamListResult(exams: exams, loaded: true);
    } catch (e) {
      debugPrint('Error loading exams: $e');
      final String? cachedData = prefs.getString(key);
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        final exams = decoded.map((e) => Exam.fromJson(e)).toList();
        return ExamListResult(exams: exams, loaded: true);
      }
      rethrow;
    }
  }

  static Future<ExamListResult> loadExamsFallback({
    required ExamService service,
    required String username,
    required String semId,
    required String etId,
    required String semName,
    required String etName,
  }) async {
    final exams = await service.getExamsFromExport(
      semId: semId,
      etId: etId,
      semName: semName,
      etName: etName,
    );

    final prefs = await SharedPreferences.getInstance();
    final String key = examsKey(semId, etId, username);
    final String encoded = jsonEncode(exams.map((e) => e.toJson()).toList());
    await prefs.setString(key, encoded);
    return ExamListResult(exams: exams, loaded: true);
  }
}
