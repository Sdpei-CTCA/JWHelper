import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:JWHelper/core/constants/config.dart';
import 'package:JWHelper/features/navigation/data/menu_navigation_service.dart';
import 'package:JWHelper/features/navigation/domain/menu_build_response.dart';
import 'package:JWHelper/features/navigation/domain/menu_item.dart';
import 'package:JWHelper/infrastructure/network/client.dart';

class JwMenuNavigationService implements MenuNavigationService {
  final ApiClient _client;

  JwMenuNavigationService({ApiClient? client}) : _client = client ?? ApiClient();

  @override
  Future<List<MenuItem>> buildMenu(MenuBuildRequest request) async {
    final response = await fetchFullMenu(request);
    return response.itemsForParent(request.parentId);
  }

  @override
  Future<MenuBuildResponse> fetchFullMenu(MenuBuildRequest request) async {
    await _client.init();

    final random = Random().nextDouble();
    final response = await _client.dio.post(
      '${Config.menuHandlerUrl}?method=BuildMenu&rondom=$random',
      data: {'pid': request.parentId.toString()},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': Config.mainUrl,
        },
      ),
    );

    final body = response.data?.toString().trim() ?? '';
    final dynamic decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Unexpected BuildMenu response: $body');
    }

    return MenuBuildResponse.fromJson(decoded);
  }
}
