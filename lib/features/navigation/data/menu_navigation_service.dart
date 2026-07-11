import 'package:JWHelper/features/navigation/domain/menu_build_response.dart';
import 'package:JWHelper/features/navigation/domain/menu_item.dart';

/// 构建菜单请求参数，对应：
/// `POST IndexMenuHandler.ashx?method=BuildMenu&rondom={random}`
/// Body: `pid={parentId}`
class MenuBuildRequest {
  /// 父菜单 ID，根菜单为 `0`（对应 curl 中的 `pid=0`）。
  final int parentId;

  const MenuBuildRequest({this.parentId = 0});
}

/// 教务主导航菜单 API。
///
/// 请求：`POST IndexMenuHandler.ashx?method=BuildMenu&rondom={random}`，Body `pid={parentId}`。
/// 响应：`{ "menu": [...], "userName": "..." }`，见 [MenuBuildResponse]。
abstract class MenuNavigationService {
  /// 拉取指定父节点下的子菜单树。
  Future<List<MenuItem>> buildMenu(MenuBuildRequest request);

  /// 拉取完整 BuildMenu 响应（含 `userName`）。
  Future<MenuBuildResponse> fetchFullMenu(MenuBuildRequest request);
}

extension MenuNavigationServiceX on MenuNavigationService {
  /// 拉取完整菜单树（从根 `pid=0` 起，具体展开策略待实现）。
  Future<List<MenuItem>> buildRootMenu() =>
      buildMenu(const MenuBuildRequest(parentId: 0));
}

/// 占位实现，供依赖注入与后续替换；调用时抛出 [UnimplementedError]。
class StubMenuNavigationService implements MenuNavigationService {
  const StubMenuNavigationService();

  @override
  Future<List<MenuItem>> buildMenu(MenuBuildRequest request) {
    throw UnimplementedError(
      'MenuNavigationService.buildMenu(parentId: ${request.parentId}) '
      'is not implemented yet',
    );
  }

  @override
  Future<MenuBuildResponse> fetchFullMenu(MenuBuildRequest request) {
    throw UnimplementedError(
      'MenuNavigationService.fetchFullMenu(parentId: ${request.parentId}) '
      'is not implemented yet',
    );
  }
}
