import 'package:JWHelper/features/navigation/data/menu_registry.dart';
import 'package:JWHelper/features/navigation/domain/app_feature.dart';
import 'package:JWHelper/features/navigation/domain/feature_path_catalog.dart';

/// 解析各功能请求 URL：优先菜单 [href]，否则与 [Config] 等价的默认路径。
class JwEndpointResolver {
  JwEndpointResolver({MenuRegistry? registry})
      : _registry = registry ?? MenuRegistry.instance;

  final MenuRegistry _registry;

  String pageUrl(AppFeature feature) {
    final fromMenu = _registry.pagePathFor(feature);
    if (fromMenu != null) {
      return FeaturePathCatalog.absoluteUrl(fromMenu);
    }
    return FeaturePathCatalog.defaultPageUrl(feature);
  }

  String pagePath(AppFeature feature) {
    final fromMenu = _registry.pagePathFor(feature);
    if (fromMenu != null) return fromMenu;
    return FeaturePathCatalog.defaultPagePath(feature);
  }

  String handlerUrl(AppFeature feature) {
    return FeaturePathCatalog.handlerUrlFromPagePath(pagePath(feature));
  }
}
