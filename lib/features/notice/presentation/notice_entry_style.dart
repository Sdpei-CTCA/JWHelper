import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 通知入口的形态：只有铃铛，或「铃铛 + 公告」的胶囊。
enum NoticeEntryMode { icon, capsule }

/// 胶囊的底色：主题色描边浅底，或主题色实心。
enum NoticeEntryFill { tint, solid }

/// 首页标题栏「通知公告」入口的样式偏好。
///
/// 放在独立的 Provider 里而不是塞进 WallpaperProvider：它跟壁纸、主题色无关，
/// 只是入口控件长什么样，单独存两个键更清楚。
class NoticeEntryStyleProvider extends ChangeNotifier {
  static const String _modeKey = 'notice_entry_mode';
  static const String _fillKey = 'notice_entry_fill';

  NoticeEntryMode _mode = NoticeEntryMode.capsule;
  NoticeEntryFill _fill = NoticeEntryFill.tint;
  bool _loaded = false;

  NoticeEntryMode get mode => _mode;
  NoticeEntryFill get fill => _fill;
  bool get isLoaded => _loaded;

  NoticeEntryStyleProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = _parseMode(prefs.getString(_modeKey));
    _fill = _parseFill(prefs.getString(_fillKey));
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(NoticeEntryMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  Future<void> setFill(NoticeEntryFill fill) async {
    if (_fill == fill) return;
    _fill = fill;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fillKey, fill.name);
  }

  static NoticeEntryMode _parseMode(String? value) {
    return NoticeEntryMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NoticeEntryMode.capsule,
    );
  }

  static NoticeEntryFill _parseFill(String? value) {
    return NoticeEntryFill.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NoticeEntryFill.tint,
    );
  }
}
