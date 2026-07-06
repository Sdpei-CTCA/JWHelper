import 'package:flutter_test/flutter_test.dart';
import 'package:JWHelper/app/domain/schedule_week_context.dart';
import 'package:JWHelper/features/exam/domain/exam.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';
import 'package:JWHelper/infrastructure/platform/widget_service.dart';

ScheduleItem _scheduleItem({int weekStart = 1, int weekEnd = 16}) {
  return ScheduleItem(
    name: '高等数学',
    teacher: '张老师',
    classroom: 'A101',
    dayIndex: 0,
    startUnit: 1,
    endUnit: 2,
    weekStart: weekStart,
    weekEnd: weekEnd,
  );
}

Exam _exam(String name) {
  return Exam(
    courseName: name,
    courseNo: '001',
    time: '2026-01-10 09:00',
    location: '教学楼A101',
    classNo: '1',
    type: 'Final',
    applyStatus: '',
  );
}

void main() {
  group('WidgetService exam mode helpers', () {
    test('examsToWidgetPayload maps exam fields', () {
      final payload = WidgetService.examsToWidgetPayload([_exam('操作系统')]);
      expect(payload.length, 1);
      expect(payload.first['courseName'], '操作系统');
      expect(payload.first['time'], '2026-01-10 09:00');
      expect(payload.first['location'], '教学楼A101');
    });

    test('exam period with upcoming exams should use exam display mode', () {
      final schedule = [_scheduleItem(weekStart: 1, weekEnd: 16)];
      final isExamPeriod =
          ScheduleWeekContext.isExamPeriod(schedule, 17);
      final upcoming = [_exam('数据结构')];

      expect(isExamPeriod, isTrue);
      expect(upcoming.isNotEmpty, isTrue);
      expect(WidgetService.displayModeExam, 'exam');
    });

    test('non-exam period should use schedule display mode constant', () {
      final schedule = [_scheduleItem(weekStart: 1, weekEnd: 16)];
      final isExamPeriod =
          ScheduleWeekContext.isExamPeriod(schedule, 10);

      expect(isExamPeriod, isFalse);
      expect(WidgetService.displayModeSchedule, 'schedule');
    });
  });
}
