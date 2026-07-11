import 'package:JWHelper/features/navigation/domain/menu_item.dart';

/// BuildMenu 接口完整响应：`{ "menu": [...], "userName": "..." }`。
class MenuBuildResponse {
  final List<MenuItem> menu;
  final String? userName;

  const MenuBuildResponse({
    required this.menu,
    this.userName,
  });

  factory MenuBuildResponse.fromJson(Map<String, dynamic> json) {
    final rawMenu = json['menu'] as List<dynamic>? ?? const [];
    return MenuBuildResponse(
      menu: rawMenu
          .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      userName: json['userName'] as String?,
    );
  }

  /// 从扁平 `menu` 列表中筛出指定父节点下的直接子项。
  List<MenuItem> itemsForParent(int parentId) {
    final items = menu.where((item) => item.pid == parentId).toList()
      ..sort((a, b) => a.orderMenu.compareTo(b.orderMenu));
    return items;
  }
}
