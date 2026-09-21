import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/infrastructure/notifications/notification_service.dart';

void main() {
  group('上课提醒通知', () {
    test('正文保留课程信息并带上点击跳转提示', () {
      final body = NotificationService.buildClassReminderBody(
        courseName: '视唱与节奏训练',
        classroom: '济-教学2号楼2506',
      );

      expect(body, contains('视唱与节奏训练'));
      expect(body, contains('济-教学2号楼2506'));
      expect(body, contains('还有10分钟'));
      expect(body, contains('点击可进入考勤签到'));
    });

    test('payload 常量可被导航层识别为考勤页', () {
      expect(NotificationService.attendancePayload, 'attendance');
    });
  });
}
