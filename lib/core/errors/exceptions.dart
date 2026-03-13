class EvaluationRequiredException implements Exception {
  final String message;
  EvaluationRequiredException([this.message = "需要进行教学评价"]);
  @override
  String toString() => message;
}
