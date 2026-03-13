import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:JWHelper/core/constants/config.dart';
import 'package:JWHelper/infrastructure/network/client.dart';
import 'package:JWHelper/features/evaluation/domain/evaluation.dart';

class EvaluationService {
  final ApiClient _client = ApiClient();

  // Get list of pending evaluations
  Future<List<EvaluationItem>> getStudentCourse() async {
    try {
      Response response = await _client.dio.post(
        Config.evaluationHandler,
        data: {"action": "getStudentCourse"},
        options: Options(
          contentType: Headers.formUrlEncodedContentType
        )
      );

      if (response.data is String) {
        try {
          // Python script:
          // courses_json = res.json() (List of batches)
          // for batch in courses_json:
          //   for c in batch.get("List", []):
          //      if not c.get("IsFinish", False): ...
          
          var decoded = jsonDecode(response.data);
          List<EvaluationItem> items = [];
          
          if (decoded is List) {
            for (var batch in decoded) {
              if (batch is Map && batch.containsKey('List') && batch['List'] is List) {
                for (var course in batch['List']) {
                  // Only add unfinished courses
                  if (course['IsFinish'] != true) {
                     items.add(EvaluationItem.fromJson(course));
                  }
                }
              } else if (batch is Map) {
                // Should not happen based on python script, but fallback
                 items.add(EvaluationItem.fromJson(batch as Map<String, dynamic>));
              }
            }
          }
          return items;
        } catch (e) {
            return [];
        }
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<List<EvaluationQuestion>> getQuestions(String courseId) async {
    final paperUrl = "${Config.evaluationHandler}?action=getPaper&rondom=${DateTime.now().millisecondsSinceEpoch / 1000}";
    
    Response paperRes = await _client.dio.post(
      paperUrl,
      data: {"Id": courseId},
      options: Options(contentType: Headers.formUrlEncodedContentType)
    );
    
    dynamic paperData;
    if (paperRes.data is String) {
      paperData = jsonDecode(paperRes.data);
    } else {
      paperData = paperRes.data;
    }
    
    List<dynamic> questions = [];
    
    if (paperData is List && paperData.isNotEmpty) {
       if (paperData[0] is Map && paperData[0].containsKey("Questions")) {
         questions = paperData[0]["Questions"];
       }
    } else if (paperData is Map) {
       if (paperData.containsKey("List") && paperData["List"] is List && (paperData["List"] as List).isNotEmpty) {
          questions = paperData["List"][0]["Questions"] ?? [];
       }
    }
    
    if (questions.isEmpty) {
      throw Exception("无法解析问卷题目数据");
    }
    
    return questions.map((q) => EvaluationQuestion.fromJson(q)).toList();
  }
  
  // Submit evaluation
  Future<void> submitEvaluation(String id, String answerString) async {
       await _client.dio.post(
          Config.evaluationHandler,
          data: {
              "action": "save",
              "answer": answerString,
              "Id": id
          },
          options: Options(
              contentType: Headers.formUrlEncodedContentType
          )
       );
  }
}
