import 'package:JWHelper/core/constants/config.dart';
import 'package:JWHelper/features/navigation/domain/app_feature.dart';

/// 各功能默认页面路径（与 [Config] 保持一致，作菜单缺失时的兜底）。
class FeaturePathCatalog {
  FeaturePathCatalog._();

  static const Map<AppFeature, String> pagePathByFeature = {
    AppFeature.grades: '/Student/MyMark.aspx',
    AppFeature.progress: '/Student/MyProgramProgress.aspx',
    AppFeature.exam: '/Student/StudentExamArrangeTable.aspx',
    AppFeature.evaluation:
        '/Student/TeachingEvaluation/TeachingEvaluation.aspx',
  };

  static String defaultPagePath(AppFeature feature) {
    return pagePathByFeature[feature]!;
  }

  static String defaultPageUrl(AppFeature feature) {
    return absoluteUrl(defaultPagePath(feature));
  }

  /// `Foo.aspx` → `FooHandler.ashx`（进度、考试等 Handler 沿用现有约定）。
  static String? handlerPathFromPagePath(String pagePath) {
    if (!pagePath.endsWith('.aspx')) return null;
    return pagePath.replaceAll(RegExp(r'\.aspx$'), 'Handler.ashx');
  }

  static String handlerUrlFromPagePath(String pagePath) {
    final handlerPath = handlerPathFromPagePath(pagePath);
    if (handlerPath == null) {
      throw ArgumentError('Cannot derive handler from page path: $pagePath');
    }
    return absoluteUrl(handlerPath);
  }

  static String absoluteUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final normalized = path.startsWith('/') ? path : '/$path';
    return '${Config.baseUrl}$normalized';
  }

  static String pagePathFromUrl(String url) {
    final uri = Uri.parse(url);
    return uri.path;
  }

  static bool hrefMatchesFeature(String href, AppFeature feature) {
    final target = defaultPagePath(feature);
    final normalized = href.trim();
    if (normalized.isEmpty) return false;
    return normalized == target || normalized.endsWith(target);
  }
}
