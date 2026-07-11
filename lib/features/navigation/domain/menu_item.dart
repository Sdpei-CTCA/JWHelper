/// 教务 [IndexMenuHandler.ashx] BuildMenu 返回的单个菜单节点。
///
/// JSON 字段：`id`, `pid`, `name`, `href`, `imageUrl`, `orderMenu`, `children`。
class MenuItem {
  final int id;
  final int pid;
  final String name;
  final String? href;
  final String imageUrl;
  final int orderMenu;
  final List<MenuItem> children;

  const MenuItem({
    required this.id,
    required this.pid,
    required this.name,
    required this.imageUrl,
    required this.orderMenu,
    this.href,
    this.children = const [],
  });

  bool get hasChildren => children.isNotEmpty;
  bool get isLeaf => href != null && href!.isNotEmpty;

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final childrenRaw = json['children'] as List<dynamic>? ?? const [];
    return MenuItem(
      id: json['id'] as int,
      pid: json['pid'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      href: _parseHref(json['href']),
      imageUrl: json['imageUrl'] as String? ?? '',
      orderMenu: json['orderMenu'] as int? ?? 0,
      children: childrenRaw
          .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pid': pid,
        'name': name,
        'href': href,
        'imageUrl': imageUrl,
        'orderMenu': orderMenu,
        'children': children.map((e) => e.toJson()).toList(),
      };

  static String? _parseHref(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();
    if (value.isEmpty) return null;
    return value;
  }
}
