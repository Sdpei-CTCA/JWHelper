class EvaluationItem {
  // We don't know exact fields, but we'll try to support basic ones
  // Usually there's a Course Name, Teacher Name, and an ID used for fetching paper.
  final String? courseName;
  final String? teacherName;
  final String? evaluationId; // This is crucial for 'getPaper' -> 'Id=...'
  
  // Also 'action=getStudentCourse' might return fields like 'kcmc', 'jsxm', 'pjid' etc.
  // We will map dynamically.
  
  EvaluationItem({this.courseName, this.teacherName, this.evaluationId});

  factory EvaluationItem.fromJson(Map<String, dynamic> json) {
    // Mapping based on common assumptions for Chinese JW systems (ZhengFang etc)
    // Adjust if user provides specific JSON
    return EvaluationItem(
      // Python script: "LUName"
      courseName: json['LUName'] ?? json['kcmc'] ?? json['CourseName'] ?? 'Unknown Course',
      // Python script: "Teacher"
      teacherName: json['Teacher'] ?? json['jsxm'] ?? json['TeacherName'] ?? 'Unknown Teacher',
      // Python script: "Id"
      evaluationId: json['Id']?.toString() ?? json['pjid']?.toString() ?? '', 
    );
  }
}

class EvaluationQuestion {
  final String id;
  final int type; // 0: single choice, 1: text
  final String title;
  final List<EvaluationOption> options;

  EvaluationQuestion({
    required this.id, 
    required this.type, 
    required this.title,
    this.options = const [],
  });

  factory EvaluationQuestion.fromJson(Map<String, dynamic> json) {
    var optionsList = <EvaluationOption>[];
    if (json['Options'] != null && json['Options'] is List) {
      optionsList = (json['Options'] as List)
          .map((o) => EvaluationOption.fromJson(o))
          .toList();
    }
    
    return EvaluationQuestion(
      id: json['Id'].toString(),
      type: json['QuestionType'] ?? 0,
      title: json['Title'] ?? '',
      options: optionsList,
    );
  }
}

class EvaluationOption {
  final String code;
  final String content;

  EvaluationOption({required this.code, required this.content});

  factory EvaluationOption.fromJson(Map<String, dynamic> json) {
    return EvaluationOption(
      code: json['Code']?.toString() ?? '',
      content: json['Content']?.toString() ?? '',
    );
  }
}
