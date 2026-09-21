import 'package:flutter/foundation.dart';

/// 考勤网页版的操作入口。
///
/// 网页版顶部的按钮被要求放到首页标题栏那一行，而标题栏在 `HomeScreen` 里，
/// 网页版在 tab 页里。两者通过这个对象通信：`CampusWebViewScreen` 挂载时注册
/// 自己的回调，`HomeScreen` 的 AppBar 按钮调用它们。
///
/// 注册/注销会触发通知，这样标题栏能在网页版挂载后立刻显示按钮（未挂载/未进入过
/// 考勤页时不显示，[isReady] 为 false）。
class AttendanceWebActions extends ChangeNotifier {
  VoidCallback? _reload;
  VoidCallback? _relogin;
  VoidCallback? _editAccount;
  VoidCallback? _openInBrowser;

  /// 网页版是否已挂载并注册了回调。
  bool get isReady =>
      _reload != null &&
      _relogin != null &&
      _editAccount != null &&
      _openInBrowser != null;

  void register({
    required VoidCallback reload,
    required VoidCallback relogin,
    required VoidCallback editAccount,
    required VoidCallback openInBrowser,
  }) {
    _reload = reload;
    _relogin = relogin;
    _editAccount = editAccount;
    _openInBrowser = openInBrowser;
    notifyListeners();
  }

  void unregister() {
    if (!isReady) {
      return;
    }
    _reload = null;
    _relogin = null;
    _editAccount = null;
    _openInBrowser = null;
    notifyListeners();
  }

  /// 重新加载网页（保留当前登录态）。
  void reload() => _reload?.call();

  /// 丢弃缓存的统一认证令牌并重新登录。
  void relogin() => _relogin?.call();

  /// 打开智慧考勤账号编辑弹窗。
  void editAccount() => _editAccount?.call();

  /// 用系统浏览器打开同一个页面（相机/长页面的退路）。
  void openInBrowser() => _openInBrowser?.call();
}
