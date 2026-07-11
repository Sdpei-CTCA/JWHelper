import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/features/navigation/domain/menu_build_response.dart';
import 'package:JWHelper/features/navigation/domain/menu_item.dart';

void main() {
  group('MenuBuildResponse', () {
    late Map<String, dynamic> fixture;

    setUp(() async {
      final raw = await File('test/features/navigation/fixtures/build_menu_pid0.json')
          .readAsString();
      fixture = jsonDecode(raw) as Map<String, dynamic>;
    });

    test('fromJson parses menu and userName', () {
      final response = MenuBuildResponse.fromJson(fixture);

      expect(response.userName, '测试同学');
      expect(response.menu, hasLength(4));
      expect(response.menu.first.id, 748);
      expect(response.menu.first.name, '我的学业');
    });

    test('MenuItem parses nested children and href', () {
      final root = MenuItem.fromJson(fixture['menu'][0] as Map<String, dynamic>);

      expect(root.pid, 0);
      expect(root.href, isNull);
      expect(root.hasChildren, isTrue);
      expect(root.children.first.id, 849);
      expect(root.children.first.children.first.name, '成绩');
      expect(root.children.first.children.first.href, '/Student/MyMark.aspx');
      expect(root.children.first.children.first.isLeaf, isTrue);
    });

    test('itemsForParent returns direct children sorted by orderMenu', () {
      final response = MenuBuildResponse.fromJson(fixture);

      final roots = response.itemsForParent(0);
      expect(roots, hasLength(2));
      expect(roots.map((e) => e.id), [748, 767]);

      final academicChildren = response.itemsForParent(748);
      expect(academicChildren, hasLength(1));
      expect(academicChildren.single.id, 849);
    });
  });
}
