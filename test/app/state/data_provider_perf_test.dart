import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/app/cache/offline_cache_keys.dart';
import 'package:JWHelper/app/state/data_provider.dart';
import 'package:JWHelper/features/grades/domain/grade.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const username = '20230001';

  String recentStartDay() {
    final d = DateTime.now().subtract(const Duration(days: 7));
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  final courseA = ScheduleItem(
    name: '运动生理学',
    teacher: '王老师',
    classroom: '教学楼101',
    dayIndex: 0,
    startUnit: 3,
    endUnit: 4,
    weekStart: 1,
    weekEnd: 16,
  );

  final courseB = ScheduleItem(
    name: '体育心理学',
    teacher: '李老师',
    classroom: '教学楼202',
    dayIndex: 0,
    startUnit: 1,
    endUnit: 2,
    weekStart: 1,
    weekEnd: 16,
  );

  final grade1 = Grade(
    semester: '2024-2025-1',
    courseName: '运动生理学',
    credit: '3.0',
    score: '90',
    gpa: '4.0',
  );

  final grade2 = Grade(
    semester: '2024-2025-2',
    courseName: '体育心理学',
    credit: '2.0',
    score: '88',
    gpa: '3.8',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('scheduleGroupedByDay memoizes reference and invalidates on edits/clear',
      () async {
    SharedPreferences.setMockInitialValues({
      OfflineCacheKeys.schedule(username):
          jsonEncode([courseA.toJson(), courseB.toJson()]),
      OfflineCacheKeys.scheduleTime(username):
          DateTime.now().millisecondsSinceEpoch,
      OfflineCacheKeys.scheduleStartDay(username): recentStartDay(),
    });

    final provider = DataProvider();
    provider.setUsernameDirectly(username);
    await provider.loadScheduleFromCache();

    expect(provider.scheduleLoaded, isTrue);
    expect(provider.scheduleLoading, isFalse);

    final firstRead = provider.scheduleGroupedByDay;
    final secondRead = provider.scheduleGroupedByDay;
    expect(identical(firstRead, secondRead), isTrue);
    // Items in the same day are sorted by startUnit ascending.
    expect(firstRead[0]?.map((e) => e.startUnit).toList(), [1, 3]);

    // Adding a custom course invalidates the cached grouping.
    final customCourse = ScheduleItem(
      name: '选修课',
      teacher: '赵老师',
      classroom: '303',
      dayIndex: 2,
      startUnit: 5,
      endUnit: 6,
      weekStart: 1,
      weekEnd: 8,
    );
    await provider.addCustomCourse(customCourse);

    final afterEdit = provider.scheduleGroupedByDay;
    expect(identical(firstRead, afterEdit), isFalse);
    expect(afterEdit[2], hasLength(1));

    // Clearing all resets and invalidates the cache.
    provider.clearAll();
    final afterClear = provider.scheduleGroupedByDay;
    expect(identical(afterEdit, afterClear), isFalse);
    expect(afterClear, isEmpty);
  });

  test('semesterList memoizes reference and invalidates on clearAll', () async {
    SharedPreferences.setMockInitialValues({
      OfflineCacheKeys.grades(username):
          jsonEncode([grade1.toJson(), grade2.toJson()]),
      OfflineCacheKeys.gradesTime(username):
          DateTime.now().millisecondsSinceEpoch,
    });

    final provider = DataProvider();
    provider.setUsernameDirectly(username);
    await provider.loadGradesFromCache();

    expect(provider.gradesLoaded, isTrue);
    expect(provider.gradesLoading, isFalse);

    final firstSemesters = provider.semesterList;
    final secondSemesters = provider.semesterList;
    expect(identical(firstSemesters, secondSemesters), isTrue);
    expect(firstSemesters, ['2024-2025-2', '2024-2025-1']);

    provider.clearAll();
    final afterClear = provider.semesterList;
    expect(identical(firstSemesters, afterClear), isFalse);
    expect(afterClear, isEmpty);
  });

  test('setCampus persists preference without triggering schedule reload',
      () async {
    SharedPreferences.setMockInitialValues({
      OfflineCacheKeys.schedule(username): jsonEncode([courseA.toJson()]),
      OfflineCacheKeys.scheduleTime(username):
          DateTime.now().millisecondsSinceEpoch,
      OfflineCacheKeys.scheduleStartDay(username): recentStartDay(),
    });

    final provider = DataProvider();
    provider.setUsernameDirectly(username);
    await provider.loadScheduleFromCache();
    expect(provider.scheduleLoaded, isTrue);

    var sawScheduleLoading = false;
    provider.addListener(() {
      if (provider.scheduleLoading) {
        sawScheduleLoading = true;
      }
    });

    await provider.setCampus('日照');

    expect(provider.campus, '日照');
    expect(sawScheduleLoading, isFalse);
    expect(provider.scheduleLoaded, isTrue);
    expect(provider.schedule, hasLength(1));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('campus_$username'), '日照');
    expect(prefs.getString('campus'), '日照');
  });
}
