import 'package:flutter/foundation.dart';
import 'package:JWHelper/features/navigation/data/jw_menu_navigation_service.dart';
import 'package:JWHelper/features/navigation/data/menu_navigation_service.dart';
import 'package:JWHelper/features/navigation/domain/menu_build_response.dart';
import 'package:JWHelper/features/navigation/domain/app_feature.dart';
import 'package:JWHelper/features/navigation/domain/feature_path_catalog.dart';
import 'package:JWHelper/features/navigation/domain/menu_item.dart';

/// 登录后缓存的 BuildMenu 结果；拉取失败时保持为空，由 [JwEndpointResolver] 回退 Config。
class MenuRegistry {
  MenuRegistry({MenuNavigationService? menuService})
      : _menuService = menuService ?? JwMenuNavigationService();

  static final MenuRegistry instance = MenuRegistry();

  final MenuNavigationService _menuService;
  MenuBuildResponse? _cached;

  MenuBuildResponse? get cached => _cached;
  bool get hasCache => _cached != null;

  Future<void> refresh() async {
    try {
      _cached =
          await _menuService.fetchFullMenu(const MenuBuildRequest(parentId: 0));
    } catch (e, stack) {
      debugPrint('MenuRegistry.refresh failed: $e');
      debugPrint('$stack');
    }
  }

  void clear() {
    _cached = null;
  }

  /// 在菜单树中查找与 [feature] 对应的首个页面 [href]（相对路径）。
  String? pagePathFor(AppFeature feature) {
    final response = _cached;
    if (response == null) return null;

    String? matched;
    void visit(MenuItem item) {
      if (matched != null) return;
      final href = item.href;
      if (href != null &&
          FeaturePathCatalog.hrefMatchesFeature(href, feature)) {
        matched = href.startsWith('/') ? href : '/$href';
      }
      for (final child in item.children) {
        visit(child);
      }
    }

    for (final item in response.menu) {
      visit(item);
    }
    return matched;
  }
}
