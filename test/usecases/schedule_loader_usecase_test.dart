import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/app/usecases/schedule_loader_usecase.dart';
import 'package:JWHelper/features/schedule/data/schedule_service.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';

class FakeScheduleService extends ScheduleService {
  FakeScheduleService(this._items, {this.startDay});

  final List<ScheduleItem> _items;
  final String? startDay;
  int callCount = 0;

  @override
  Future<Map<String, dynamic>> getSchedule() async {
    callCount++;
    return {'items': _items, 'startDay': startDay};
  }
}

void main() {
  const username = 'test_user';

  final cachedItem = ScheduleItem(
    name: 'Cached Course',
    teacher: 'Teacher A',
    classroom: '101',
    dayIndex: 0,
    startUnit: 1,
    endUnit: 2,
  );

  final networkItem = ScheduleItem(
    name: 'Network Course',
    teacher: 'Teacher B',
    classroom: '202',
    dayIndex: 1,
    startUnit: 3,
    endUnit: 4,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> seedCache(ScheduleItem item, {String? startDay}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'schedule_cache_$username',
      jsonEncode([item.toJson()]),
    );
    await prefs.setInt(
      'schedule_cache_time_$username',
      DateTime.now().millisecondsSinceEpoch,
    );
    if (startDay != null) {
      await prefs.setString('schedule_start_day_$username', startDay);
    }
  }

  test('forceRefresh=true skips disk cache and fetches from network', () async {
    await seedCache(cachedItem, startDay: '2024-09-01');
    final service = FakeScheduleService([networkItem], startDay: '2025-02-01');

    final result = await ScheduleLoaderUsecase.execute(
      service: service,
      username: username,
      forceRefresh: true,
    );

    expect(service.callCount, 1);
    expect(result.schedule, hasLength(1));
    expect(result.schedule.first.name, 'Network Course');
    expect(result.startDay, '2025-02-01');
  });

  test('forceRefresh=true with empty network does not fallback to disk cache',
      () async {
    await seedCache(cachedItem);
    final service = FakeScheduleService([]);

    final result = await ScheduleLoaderUsecase.execute(
      service: service,
      username: username,
      forceRefresh: true,
    );

    expect(service.callCount, 1);
    expect(result.schedule, isEmpty);
  });

  test('forceRefresh=false reads disk cache within 30 days', () async {
    await seedCache(cachedItem, startDay: '2024-09-01');
    final service = FakeScheduleService([networkItem]);

    final result = await ScheduleLoaderUsecase.execute(
      service: service,
      username: username,
      forceRefresh: false,
    );

    expect(service.callCount, 0);
    expect(result.schedule.first.name, 'Cached Course');
    expect(result.startDay, '2024-09-01');
  });

  test('empty disk cache ignores stale start day', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'schedule_cache_$username',
      '[]',
    );
    await prefs.setInt(
      'schedule_cache_time_$username',
      DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setString('schedule_start_day_$username', '2024-09-01');

    final service = FakeScheduleService([networkItem]);

    final result = await ScheduleLoaderUsecase.execute(
      service: service,
      username: username,
      forceRefresh: false,
    );

    expect(service.callCount, 0);
    expect(result.schedule, isEmpty);
    expect(result.startDay, isNull);
  });
}
