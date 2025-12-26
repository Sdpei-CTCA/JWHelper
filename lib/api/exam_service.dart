import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../config.dart';
import 'client.dart';
import '../models/exam.dart';

// Top-level function for compute
List<Semester> _parseExamSemesters(String html) {
  final document = html_parser.parse(html);
  final options = document.querySelectorAll("#ddlSemester option");
  
  return options.map((e) => Semester(
    id: e.attributes['value'] ?? "",
    name: e.text.trim(),
  )).toList();
}

List<Exam> _parseExportedHtml(String html) {
  final document = html_parser.parse(html);
  final rows = document.querySelectorAll("tr");
  final List<Exam> exams = [];

  bool headerFound = false;

  for (var row in rows) {
    final cells = row.children;
    if (cells.isEmpty) continue;

    if (cells.any((c) => c.text.contains("课程名"))) {
      headerFound = true;
      continue;
    }

    if (!headerFound) continue;

    if (cells.length < 4) continue;

    final name = cells[0].text.trim();
    final no = cells[1].text.trim();
    final type = cells[2].text.trim();
    final time = cells[3].text.trim();
    
    String location = "";
    if (cells.length >= 6) {
       location = cells[5].text.trim();
    } else if (cells.length >= 5) {
       location = cells[4].text.trim();
    }

    exams.add(Exam(
      courseName: name,
      courseNo: no,
      time: time,
      location: location,
      classNo: "",
      type: type,
      applyStatus: "",
    ));
  }
  return exams;
}

class ExamService {
  final ApiClient _client = ApiClient();

  Future<List<Semester>> getSemesters() async {
    try {
      final response = await _client.dio.get(
        "${Config.baseUrl}/Student/StudentExamArrangeTable.aspx",
      );
      
      return await compute(_parseExamSemesters, response.data.toString());
    } catch (e) {
      debugPrint("Error fetching semesters: $e");
      rethrow;
    }
  }

  Future<List<ExamRound>> getExamRounds(String semId) async {
    try {
      final response = await _client.dio.post(
        "${Config.baseUrl}/Student/StudentExamArrangeTableHandler.ashx",
        queryParameters: {
          "action": "thirdchange",
          "rondom": DateTime.now().millisecondsSinceEpoch / 1000,
        },
        data: {"semId": semId},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            "X-Requested-With": "XMLHttpRequest",
          },
        ),
      );

      if (response.data == null || response.data.toString().isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(response.data);
      if (jsonList.isNotEmpty && jsonList[0]['EtLst'] != null) {
        final List<dynamic> etList = jsonList[0]['EtLst'];
        return etList.map((e) => ExamRound(
          id: e['id'].toString(),
          name: e['name'].toString(),
        )).toList();
      }
      return [];

    } catch (e) {
      debugPrint("Error fetching exam rounds: $e");
      rethrow;
    }
  }

  Future<List<Exam>> getExamList(String semId, String etId) async {
    try {
      final response = await _client.dio.post(
        "${Config.baseUrl}/Student/StudentExamArrangeTableHandler.ashx",
        data: {
          "semId": semId,
          "etID": etId,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            "X-Requested-With": "XMLHttpRequest",
          },
        ),
      );

      // The response is JSON
      // {"a":true,"b":[{"periodTime":"","CourseNO":"...","CourseName":"...","serialNumber":"3",...}]}
      
      if (response.data == null || response.data.toString().isEmpty) {
        return [];
      }

      final Map<String, dynamic> jsonResponse = jsonDecode(response.data);
      if (jsonResponse['b'] == null) {
        return [];
      }

      final List<dynamic> list = jsonResponse['b'];
      return list.map((e) {
        return Exam(
          courseName: e['CourseName']?.toString() ?? "",
          courseNo: e['CourseNO']?.toString() ?? "",
          time: e['periodTime']?.toString() ?? "",
          location: e['learningSpace']?.toString() ?? "",
          classNo: e['serialNumber']?.toString() ?? "",
          type: e['EvaluationMethod']?.toString() ?? "",
          applyStatus: e['ApplyStatus']?.toString() ?? "",
        );
      }).toList();

    } catch (e) {
      debugPrint("Error fetching exam list: $e");
      rethrow;
    }
  }

  Future<List<Exam>> getExamsFromExport({
    required String semId,
    required String etId,
    required String semName,
    required String etName,
  }) async {
    try {
      final response = await _client.dio.post(
        "${Config.baseUrl}/Student/StudentExamArrangeTableHandler.ashx",
        queryParameters: {
          "ron": Random().nextDouble(),
        },
        data: {
          "action": "doexport",
          "semId": semId,
          "etID": etId,
          "semName": semName,
          "etName": etName,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(minutes: 3),
          headers: {
            "X-Requested-With": "XMLHttpRequest",
            "Referer": "${Config.baseUrl}/Student/StudentExamArrangeTable.aspx",
          },
        ),
      );

      final String filePath = response.data.toString();
      if (filePath.isEmpty || !filePath.startsWith("/")) {
         throw Exception("Invalid file path received: $filePath");
      }

      final fileResponse = await _client.dio.get(
        "${Config.baseUrl}$filePath",
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(minutes: 3),
        ),
      );

      return await compute(_parseExportedHtml, fileResponse.data.toString());
    } catch (e) {
      debugPrint("Error getting exams from export: $e");
      rethrow;
    }
  }

  Future<List<int>> exportExamTable({
    required String semId,
    required String etId,
    required String semName,
    required String etName,
  }) async {
    try {
      final response = await _client.dio.post(
        "${Config.baseUrl}/Student/StudentExamArrangeTableHandler.ashx",
        queryParameters: {
          "ron": Random().nextDouble(),
        },
        data: {
          "action": "doexport",
          "semId": semId,
          "etID": etId,
          "semName": semName,
          "etName": etName,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(minutes: 3),
          headers: {
            "X-Requested-With": "XMLHttpRequest",
            "Referer": "${Config.baseUrl}/Student/StudentExamArrangeTable.aspx",
          },
        ),
      );

      final String filePath = response.data.toString();
      if (filePath.isEmpty || !filePath.startsWith("/")) {
         throw Exception("Invalid file path received: $filePath");
      }

      final fileResponse = await _client.dio.get(
        "${Config.baseUrl}$filePath",
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 3),
        ),
      );

      if (fileResponse.statusCode == 200) {
        return fileResponse.data;
      } else {
        throw Exception("Failed to download file: ${fileResponse.statusCode}");
      }
    } catch (e) {
      debugPrint("Error exporting exam table: $e");
      rethrow;
    }
  }
}
