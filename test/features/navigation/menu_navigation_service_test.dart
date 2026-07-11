import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/features/navigation/data/menu_navigation_service.dart';

void main() {
  group('StubMenuNavigationService', () {
    const service = StubMenuNavigationService();

    test('buildMenu throws UnimplementedError', () {
      expect(
        () => service.buildMenu(const MenuBuildRequest(parentId: 0)),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}
