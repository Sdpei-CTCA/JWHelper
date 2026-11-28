import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/app/cache/offline_cache_keys.dart';
import 'package:JWHelper/app/state/data_provider.dart';
import 'package:JWHelper/features/auth/presentation/auth_provider.dart';
import 'package:JWHelper/features/schedule/domain/schedule_item.dart';
import 'package:JWHelper/features/schedule/presentation/schedule_screen.dart';
import 'package:JWHelper/shared/theme/wallpaper_provider.dart';

String _recentStartDay() {
  final d = DateTime.now().subtract(const Duration(days: 7));
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

Future<({
  DataProvider dataProvider,
  ValueNotifier<bool> isGridNotifier,
  ValueNotifier<int> selectedWeekNotifier,
  ValueNotifier<bool> editingNotifier,
})> _pumpScheduleScreen(
  WidgetTester tester, {
  required bool isGrid,
  required bool termUnavailable,
}) async {
  const username = 'test_user';
  // 放入一条仅在第 1 周且不在今天（明天）的课程：
  // startDay 在 7 天前使当前周为第 2 周，从而网格第 2 周与列表“今天”均无课。
  final tomorrowDayIndex = DateTime.now().weekday % 7;
  final seededItems = termUnavailable
      ? const <ScheduleItem>[]
      : [
          ScheduleItem(
            name: '首周导论',
            teacher: '张老师',
            classroom: '101',
            dayIndex: tomorrowDayIndex,
            startUnit: 1,
            endUnit: 2,
            weekStart: 1,
            weekEnd: 1,
          ),
        ];
  final prefsMap = <String, Object>{
    OfflineCacheKeys.schedule(username):
        jsonEncode(seededItems.map((e) => e.toJson()).toList()),
    OfflineCacheKeys.scheduleTime(username):
        DateTime.now().millisecondsSinceEpoch,
    if (!termUnavailable)
      OfflineCacheKeys.scheduleStartDay(username): _recentStartDay(),
  };
  SharedPreferences.setMockInitialValues(prefsMap);

  final dataProvider = DataProvider();
  dataProvider.setUsernameDirectly(username);
  await dataProvider.loadScheduleFromCache();

  final isGridNotifier = ValueNotifier<bool>(isGrid);
  final selectedWeekNotifier = ValueNotifier<int>(1);
  final editingNotifier = ValueNotifier<bool>(false);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<DataProvider>.value(value: dataProvider),
        ChangeNotifierProvider<WallpaperProvider>(
          create: (_) => WallpaperProvider(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ScheduleScreen(
            isGridViewNotifier: isGridNotifier,
            selectedWeekNotifier: selectedWeekNotifier,
            editingNotifier: editingNotifier,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return (
    dataProvider: dataProvider,
    isGridNotifier: isGridNotifier,
    selectedWeekNotifier: selectedWeekNotifier,
    editingNotifier: editingNotifier,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('grid mode with no classes enters edit mode on long press',
      (tester) async {
    final env = await _pumpScheduleScreen(
      tester,
      isGrid: true,
      termUnavailable: false,
    );
    addTearDown(() {
      env.isGridNotifier.dispose();
      env.selectedWeekNotifier.dispose();
      env.editingNotifier.dispose();
    });

    expect(env.editingNotifier.value, isFalse);
    expect(find.byIcon(Icons.add), findsNothing);

    await tester.longPress(find.byType(PageView));
    await tester.pumpAndSettle();

    expect(env.editingNotifier.value, isTrue);
    expect(find.byIcon(Icons.add), findsWidgets);
  });

  testWidgets('list mode empty day enters edit mode on long press',
      (tester) async {
    final env = await _pumpScheduleScreen(
      tester,
      isGrid: false,
      termUnavailable: false,
    );
    addTearDown(() {
      env.isGridNotifier.dispose();
      env.selectedWeekNotifier.dispose();
      env.editingNotifier.dispose();
    });

    expect(env.editingNotifier.value, isFalse);
    expect(find.text('今天没有课哦 ~'), findsOneWidget);
    expect(find.text('长按空白处可编辑或添加课程'), findsOneWidget);

    await tester.longPress(find.text('今天没有课哦 ~'));
    await tester.pumpAndSettle();

    expect(env.editingNotifier.value, isTrue);
    expect(find.text('添加上午课程'), findsOneWidget);
  });

  testWidgets(
      'termUnavailable empty schedule enters edit mode on background long press',
      (tester) async {
    final env = await _pumpScheduleScreen(
      tester,
      isGrid: false,
      termUnavailable: true,
    );
    addTearDown(() {
      env.isGridNotifier.dispose();
      env.selectedWeekNotifier.dispose();
      env.editingNotifier.dispose();
    });

    expect(env.dataProvider.isScheduleTermUnavailable, isTrue);
    expect(env.editingNotifier.value, isFalse);
    expect(find.text('长按空白处可进入编辑模式手动添加课程'), findsOneWidget);

    await tester.longPress(find.byIcon(Icons.event_busy_outlined));
    await tester.pumpAndSettle();

    expect(env.editingNotifier.value, isTrue);
    expect(find.text('添加上午课程'), findsOneWidget);
  });
}
