import 'dart:convert';
import 'package:dio/dio.dart';
import '../config.dart';
import 'client.dart';
import '../models/evaluation.dart';

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

  // Auto Evaluate logic matching Python script
  Future<void> autoEvaluate(String courseId) async {
    List<EvaluationQuestion> questions = await getQuestions(courseId);
    
    // 2. Construct Answer String
    // Default strategy
    const String defaultOption = "A"; // 100分
    const String defaultGood = "专业知识和教学技能出众，授课生动有趣。";
    const String defaultBad = "没有什么需要改进的地方，老师非常优秀。";
    
    StringBuffer answerBuffer = StringBuffer();
    
    for (var q in questions) {
      String val = "";
      if (q.type == 0) {
        val = defaultOption;
      } else if (q.type == 1) {
        if (q.title.contains("优点")) {
          val = defaultGood;
        } else {
          val = defaultBad;
        }
      }
      
      // Format: ID + 11 commas + Val + 10 pipes
      // f"{q_id}{',' * 11}{val}{'|' * 10}"
      answerBuffer.write("${q.id},,,,,,,,,,,$val||||||||||");
    }
    
    String finalAnswer = answerBuffer.toString();
    
    // 3. Submit
    // Note: Python script mentions "URL encode only the answer string manually"
    // Dio FormUrlEncodedContent will encode all values.
    // If we pass key="answer", value="99,,,,A|||"
    // Dio will encode comma to %2C and pipe to %7C
    // Result: answer=99%2C%2C%2C%2CA%7C%7C%7C
    // This matches what Python does with urllib.parse.quote(answer_str)
    
    Response saveRes = await _client.dio.post(
      Config.evaluationHandler,
      data: {
        "action": "save",
        "answer": finalAnswer, 
        "Id": courseId
      },
      options: Options(
         contentType: Headers.formUrlEncodedContentType
      )
    );
    
    String resText = saveRes.data.toString();
    if (resText == "1" || resText.toLowerCase().contains("true") || resText.toLowerCase().contains("success")) {
      return;
    } else {
      throw Exception("提交失败: $resText");
    }
  }

  // Get paper content - returning raw string/json for now as we don't have model
  Future<dynamic> getPaper(String id) async {
      Response response = await _client.dio.post(
        "${Config.evaluationHandler}?action=getPaper", 
        data: {"Id": id}, 
        options: Options(
            contentType: Headers.formUrlEncodedContentType
        )
      );
      return response.data;
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
