/// 教务 API 在 Session 失效时可能返回纯文本 `logintimeout`（HTTP 200）。
bool isLoginTimeoutBody(dynamic data) {
  if (data is! String) return false;
  return data.trim().toLowerCase() == 'logintimeout';
}

bool shouldCheckLoginTimeout(Uri uri) {
  final path = uri.path.toLowerCase();
  return !path.contains('loginhandler.ashx');
}
