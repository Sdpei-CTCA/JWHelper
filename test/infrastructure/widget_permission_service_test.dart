import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/infrastructure/platform/widget_permission_service.dart';

void main() {
  test('platformGuideText mentions HyperOS split permissions on Android guide', () {
    final guide = WidgetPermissionService.platformGuideText();
    expect(guide.contains('小组件') || guide.contains('不支持'), isTrue);
  });

  test('detectableReady requires alarm and notification only', () {
    const status = WidgetPermissionStatus(
      canScheduleExactAlarms: true,
      exactAlarmRequired: true,
      notificationGranted: true,
      notificationRequired: true,
      isXiaomiFamily: true,
      sdkInt: 34,
    );

    expect(status.detectableReady, isTrue);
  });
}
