import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/app/cache/offline_cache_keys.dart';
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
  static String semestersKey(String username) =>
      OfflineCacheKeys.examSemesters(username);
  static String roundsKey(String semId, String username) =>
      'exam_rounds_${semId}_$username';
  static String examsKey(String semId, String roundId, String username) =>
      'exams_${semId}_${roundId}_$username';

  static List<T>? _readCachedList<T>(
    SharedPreferences prefs,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final cachedData = prefs.getString(key);
    if (cachedData == null || cachedData.isEmpty) return null;
    try {
      final decoded = jsonDecode(cachedData);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Error decoding exam cache [$key]: $e');
      return null;
    }
  }

  static Future<ExamSemestersResult> loadSemesters({
    required ExamService service,
    required String username,
    required bool forceRefresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = semestersKey(username);
    if (!forceRefresh) {
      final cached = _readCachedList(prefs, key, Semester.fromJson);
      if (cached != null) {
        return ExamSemestersResult(semesters: cached);
      }
    }

    try {
      final semesters = await service.getSemesters();
      final String encoded =
          jsonEncode(semesters.map((e) => e.toJson()).toList());
      await prefs.setString(key, encoded);
      return ExamSemestersResult(semesters: semesters);
    } catch (e) {
      debugPrint('Error loading exam semesters: $e');
      final cached = _readCachedList(prefs, key, Semester.fromJson);
      if (cached != null) {
        return ExamSemestersResult(semesters: cached);
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
      final cached = _readCachedList(prefs, key, ExamRound.fromJson);
      if (cached != null) {
        return ExamRoundsResult(rounds: cached);
      }
    }

    try {
      final rounds = await service.getExamRounds(semId);
      final String encoded = jsonEncode(rounds.map((e) => e.toJson()).toList());
      await prefs.setString(key, encoded);
      return ExamRoundsResult(rounds: rounds);
    } catch (e) {
      debugPrint('Error loading exam rounds: $e');
      final cached = _readCachedList(prefs, key, ExamRound.fromJson);
      if (cached != null) {
        return ExamRoundsResult(rounds: cached);
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
      final cached = _readCachedList(prefs, key, Exam.fromJson);
      if (cached != null) {
        return ExamListResult(exams: cached, loaded: true);
      }
    }

    try {
      final exams = await service.getExamList(semId, roundId);
      final String encoded = jsonEncode(exams.map((e) => e.toJson()).toList());
      await prefs.setString(key, encoded);
      return ExamListResult(exams: exams, loaded: true);
    } catch (e) {
      debugPrint('Error loading exams: $e');
      final cached = _readCachedList(prefs, key, Exam.fromJson);
      if (cached != null) {
        return ExamListResult(exams: cached, loaded: true);
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
