class EvaluationRequiredException implements Exception {
  final String message;
  EvaluationRequiredException([this.message = "需要进行教学评价"]);
  @override
  String toString() => message;
}

class LoginSessionExpiredException implements Exception {
  final String message;
  LoginSessionExpiredException([this.message = "登录已过期，请重新登录"]);
  @override
  String toString() => message;
}
