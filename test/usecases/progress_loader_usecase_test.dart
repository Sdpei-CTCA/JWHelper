import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/app/usecases/progress_loader_usecase.dart';
import 'package:JWHelper/features/progress/data/progress_service.dart';
import 'package:JWHelper/features/progress/domain/progress_item.dart';

class FakeProgressService extends ProgressService {
  FakeProgressService(this._groups, this._info);

  final List<ProgressGroup> _groups;
  final List<ProgressInfo> _info;
  int callCount = 0;

  @override
  Future<Map<String, dynamic>> getProgressData() async {
    callCount++;
    return {'groups': _groups, 'info': _info};
  }
}

void main() {
  const username = 'test_user';

  final cachedGroup = ProgressGroup(
    id: '1',
    name: 'Cached Group',
    required: 10,
    earned: 5,
  );

  final networkGroup = ProgressGroup(
    id: '2',
    name: 'Network Group',
    required: 12,
    earned: 8,
  );

  final cachedInfo = [ProgressInfo(label: 'GPA', value: '3.0')];
  final networkInfo = [ProgressInfo(label: 'GPA', value: '3.5')];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> seedCache(
    List<ProgressGroup> groups,
    List<ProgressInfo> info,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'groups': groups.map((g) => g.toJson()).toList(),
      'info': info.map((i) => i.toJson()).toList(),
    };
    await prefs.setString(
      ProgressLoaderUsecase.cacheKey(username),
      jsonEncode(data),
    );
    await prefs.setInt(
      ProgressLoaderUsecase.cacheTimeKey(username),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  test('forceRefresh=true skips disk cache and fetches from network', () async {
    await seedCache([cachedGroup], cachedInfo);
    final service = FakeProgressService([networkGroup], networkInfo);

    final result = await ProgressLoaderUsecase.execute(
      service: service,
      username: username,
      forceRefresh: true,
    );

    expect(service.callCount, 1);
    expect(result.groups, hasLength(1));
    expect(result.groups.first.name, 'Network Group');
    expect(result.info.first.value, '3.5');
  });

  test('forceRefresh=true with empty network does not fallback to disk cache',
      () async {
    await seedCache([cachedGroup], cachedInfo);
    final service = FakeProgressService([], []);

    final result = await ProgressLoaderUsecase.execute(
      service: service,
      username: username,
      forceRefresh: true,
    );

    expect(service.callCount, 1);
    expect(result.groups, isEmpty);
    expect(result.info, isEmpty);
  });

  test('forceRefresh=false reads disk cache within 30 days', () async {
    await seedCache([cachedGroup], cachedInfo);
    final service = FakeProgressService([networkGroup], networkInfo);

    final result = await ProgressLoaderUsecase.execute(
      service: service,
      username: username,
      forceRefresh: false,
    );

    expect(service.callCount, 0);
    expect(result.groups.first.name, 'Cached Group');
    expect(result.info.first.value, '3.0');
  });
}
