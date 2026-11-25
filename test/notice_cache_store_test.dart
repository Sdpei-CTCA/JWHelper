import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/features/notice/data/notice_cache_store.dart';
import 'package:JWHelper/features/notice/domain/notice_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('列表缓存可以原样读回，已读状态不落盘', () async {
    final store = NoticeCacheStore();
    final items = [
      NoticeItem(
        id: 'https://pubinfo.sdpei.edu.cn/2026/1120/c1a2/page.htm',
        title: '关于开展实验室安全检查的通知',
        url: 'https://pubinfo.sdpei.edu.cn/2026/1120/c1a2/page.htm',
        publishedAt: DateTime(2026, 11, 20),
        department: '教务处',
        isRead: true,
      ),
      const NoticeItem(
        id: 'https://pubinfo.sdpei.edu.cn/2026/1118/c3a4/page.htm',
        title: '关于开展冬季安全教育主题班会的通知',
        url: 'https://pubinfo.sdpei.edu.cn/2026/1118/c3a4/page.htm',
      ),
    ];

    await store.saveList('20230001', items);
    final restored = await store.readList('20230001');

    expect(restored.length, 2);
    expect(restored.first.title, '关于开展实验室安全检查的通知');
    expect(restored.first.publishedAt, DateTime(2026, 11, 20));
    expect(restored.first.department, '教务处');
    // 已读是按账号单独存的集合，缓存里不重复保存
    expect(restored.first.isRead, isFalse);
    expect(restored.last.publishedAt, isNull);
  });

  test('已读集合按账号隔离', () async {
    final store = NoticeCacheStore();
    await store.saveReadIds('20230001', {'a', 'b'});

    expect(await store.readReadIds('20230001'), {'a', 'b'});
    expect(await store.readReadIds('20230002'), isEmpty);
  });

  test('换账号后列表互不可见', () async {
    final store = NoticeCacheStore();
    await store.saveList('20230001', const [
      NoticeItem(id: 'a', title: '标题一', url: 'https://x/a'),
    ]);

    expect((await store.readList('20230001')).length, 1);
    expect(await store.readList('20230002'), isEmpty);
  });

  test('损坏的缓存不会抛异常，按空列表处理', () async {
    SharedPreferences.setMockInitialValues({
      'notice_list_v1_20230001': 'not-json',
    });
    final store = NoticeCacheStore();
    expect(await store.readList('20230001'), isEmpty);
  });

  test('提醒开关默认开启，可关闭后保持', () async {
    final store = NoticeCacheStore();
    expect(await store.readReminderEnabled(), isTrue);

    await store.saveReminderEnabled(false);
    expect(await store.readReminderEnabled(), isFalse);
  });
}
