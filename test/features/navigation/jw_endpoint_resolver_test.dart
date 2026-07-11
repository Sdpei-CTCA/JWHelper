import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/core/constants/config.dart';
import 'package:JWHelper/features/navigation/data/jw_endpoint_resolver.dart';
import 'package:JWHelper/features/navigation/data/menu_navigation_service.dart';
import 'package:JWHelper/features/navigation/data/menu_registry.dart';
import 'package:JWHelper/features/navigation/domain/app_feature.dart';
import 'package:JWHelper/features/navigation/domain/feature_path_catalog.dart';
import 'package:JWHelper/features/navigation/domain/menu_build_response.dart';
import 'package:JWHelper/features/navigation/domain/menu_item.dart';

class _FakeMenuNavigationService implements MenuNavigationService {
  final MenuBuildResponse response;

  _FakeMenuNavigationService(this.response);

  @override
  Future<List<MenuItem>> buildMenu(MenuBuildRequest request) async {
    return response.itemsForParent(request.parentId);
  }

  @override
  Future<MenuBuildResponse> fetchFullMenu(MenuBuildRequest request) async {
    return response;
  }
}

void main() {
  group('FeaturePathCatalog', () {
    test('default page urls match Config constants', () {
      expect(
        FeaturePathCatalog.defaultPageUrl(AppFeature.grades),
        Config.gradesUrl,
      );
      expect(
        FeaturePathCatalog.defaultPageUrl(AppFeature.progress),
        Config.progressUrl,
      );
      expect(
        FeaturePathCatalog.defaultPageUrl(AppFeature.exam),
        '${Config.baseUrl}/Student/StudentExamArrangeTable.aspx',
      );
      expect(
        FeaturePathCatalog.defaultPageUrl(AppFeature.evaluation),
        Config.evaluationUrl,
      );
    });

    test('derives handler path from aspx page path', () {
      expect(
        FeaturePathCatalog.handlerPathFromPagePath(
          '/Student/MyProgramProgress.aspx',
        ),
        '/Student/MyProgramProgressHandler.ashx',
      );
    });
  });

  group('JwEndpointResolver', () {
    late MenuRegistry registry;
    late JwEndpointResolver resolver;

    setUp(() async {
      final raw = await File(
        'test/features/navigation/fixtures/build_menu_pid0.json',
      ).readAsString();
      final response =
          MenuBuildResponse.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      registry = MenuRegistry(menuService: _FakeMenuNavigationService(response));
      await registry.refresh();
      resolver = JwEndpointResolver(registry: registry);
    });

    tearDown(() {
      registry.clear();
    });

    test('uses menu href when available', () {
      expect(
        resolver.pageUrl(AppFeature.grades),
        '${Config.baseUrl}/Student/MyMark.aspx',
      );
    });

    test('falls back to Config when registry empty', () {
      registry.clear();
      expect(resolver.pageUrl(AppFeature.grades), Config.gradesUrl);
      expect(
        resolver.handlerUrl(AppFeature.progress),
        '${Config.baseUrl}/Student/MyProgramProgressHandler.ashx',
      );
    });
  });
}
