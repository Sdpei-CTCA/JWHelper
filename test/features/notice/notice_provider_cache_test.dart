import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:JWHelper/features/attendance/data/sso_token_service.dart';
import 'package:JWHelper/features/attendance/presentation/attendance_provider.dart';
import 'package:JWHelper/features/notice/data/notice_source.dart';
import 'package:JWHelper/features/notice/domain/notice_detail.dart';
import 'package:JWHelper/features/notice/domain/notice_item.dart';
import 'package:JWHelper/features/notice/presentation/notice_provider.dart';

class _FakeNoticeSource implements NoticeSource {
  final Map<String, int> imageFetchCounts = {};
  final Map<String, int> detailFetchCounts = {};
  final Map<String, Uint8List?> imageResponses = {};
  final Map<String, Completer<Uint8List?>> pendingImages = {};

  int defaultImageSize = 64;

  @override
  void updateCredentials({
    required String userToken,
    required String ctTicket,
    required String appCtTicket,
  }) {}

  @override
  Future<List<NoticeItem>> fetchList() async => const [];

  @override
  Future<NoticeDetail> fetchDetail(NoticeItem item) async {
    detailFetchCounts[item.id] = (detailFetchCounts[item.id] ?? 0) + 1;
    return NoticeDetail(
      url: item.url,
      title: item.title,
      blocks: [NoticeTextBlock('Body for ${item.id}')],
    );
  }

  @override
  Future<Uint8List?> fetchBytes(String url) async {
    imageFetchCounts[url] = (imageFetchCounts[url] ?? 0) + 1;
    final pending = pendingImages[url];
    if (pending != null) {
      return pending.future;
    }
    if (imageResponses.containsKey(url)) {
      return imageResponses[url];
    }
    return Uint8List(defaultImageSize);
  }
}

class _FakeSsoTokenService extends SsoTokenService {
  @override
  Future<SsoSession?> loginAndFetchToken({
    required String username,
    required String password,
  }) async {
    return const SsoSession(
      userToken: 'token',
      ctTicket: 'ticket',
      appCtTicket: 'app-ticket',
    );
  }
}

NoticeItem _item(int index) => NoticeItem(
      id: 'notice-$index',
      title: 'Notice $index',
      url: 'https://pubinfo.sdpei.edu.cn/notice/$index',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('loadImage deduplicates concurrent in-flight requests', () async {
    final source = _FakeNoticeSource();
    const url = 'https://pubinfo.sdpei.edu.cn/files/a.png';
    final completer = Completer<Uint8List?>();
    source.pendingImages[url] = completer;

    final provider = NoticeProvider(source: source);

    final f1 = provider.loadImage(url);
    final f2 = provider.loadImage(url);
    final payload = Uint8List.fromList([1, 2, 3, 4]);
    completer.complete(payload);

    final results = await Future.wait([f1, f2]);
    expect(source.imageFetchCounts[url], 1);
    expect(results[0], equals(payload));
    expect(results[1], equals(payload));

    // Subsequent call hits the memory cache.
    final cached = await provider.loadImage(url);
    expect(cached, equals(payload));
    expect(source.imageFetchCounts[url], 1);
  });

  test('failed loadImage returning null is not cached and retries cleanly',
      () async {
    final source = _FakeNoticeSource();
    const url = 'https://pubinfo.sdpei.edu.cn/files/flaky.png';
    source.imageResponses[url] = null;

    final provider = NoticeProvider(source: source);
    expect(await provider.loadImage(url), isNull);
    expect(source.imageFetchCounts[url], 1);

    final recovered = Uint8List.fromList([9, 8, 7]);
    source.imageResponses[url] = recovered;

    final second = await provider.loadImage(url);
    expect(second, equals(recovered));
    expect(source.imageFetchCounts[url], 2);

    // Now that it succeeded, it is cached.
    final third = await provider.loadImage(url);
    expect(third, equals(recovered));
    expect(source.imageFetchCounts[url], 2);
  });

  test('image cache enforces LRU entry cap of 24 items', () async {
    final source = _FakeNoticeSource();
    final provider = NoticeProvider(source: source);

    // Fill 24 entries: img-0 .. img-23.
    for (var i = 0; i < 24; i++) {
      await provider.loadImage('https://example.com/img-$i.png');
    }
    // Touch img-0 so img-1 becomes the least recently used entry.
    await provider.loadImage('https://example.com/img-0.png');
    expect(source.imageFetchCounts['https://example.com/img-0.png'], 1);

    // Insert 25th entry: img-1 should be evicted while img-0 stays cached.
    await provider.loadImage('https://example.com/img-24.png');

    await provider.loadImage('https://example.com/img-0.png');
    expect(source.imageFetchCounts['https://example.com/img-0.png'], 1);

    await provider.loadImage('https://example.com/img-1.png');
    expect(source.imageFetchCounts['https://example.com/img-1.png'], 2);
  });

  test('image cache enforces 24MB total byte budget', () async {
    final source = _FakeNoticeSource()
      ..defaultImageSize = 10 * 1024 * 1024; // 10 MB each
    final provider = NoticeProvider(source: source);

    await provider.loadImage('https://example.com/big-1.png');
    await provider.loadImage('https://example.com/big-2.png');
    // 20 MB total: big-1 still fits.
    await provider.loadImage('https://example.com/big-1.png');
    expect(source.imageFetchCounts['https://example.com/big-1.png'], 1);

    // Adding big-3 pushes total to 30 MB -> evicts LRU big-2.
    await provider.loadImage('https://example.com/big-3.png');

    await provider.loadImage('https://example.com/big-1.png');
    expect(source.imageFetchCounts['https://example.com/big-1.png'], 1);

    await provider.loadImage('https://example.com/big-2.png');
    expect(source.imageFetchCounts['https://example.com/big-2.png'], 2);
  });

  test('detail cache enforces LRU entry cap of 20 items', () async {
    final source = _FakeNoticeSource();
    final auth = AttendanceProvider(ssoTokenService: _FakeSsoTokenService());
    await auth.saveCredentials(
      username: '20230001',
      password: 'password',
    );

    final provider = NoticeProvider(source: source);
    provider.attachAuth(auth);
    await provider.initialize();

    for (var i = 0; i < 20; i++) {
      await provider.loadDetail(_item(i));
    }
    // Touch notice-0 so notice-1 becomes LRU.
    await provider.loadDetail(_item(0));
    expect(source.detailFetchCounts['notice-0'], 1);

    // Load 21st detail -> evicts notice-1, keeps notice-0.
    await provider.loadDetail(_item(20));

    await provider.loadDetail(_item(0));
    expect(source.detailFetchCounts['notice-0'], 1);

    await provider.loadDetail(_item(1));
    expect(source.detailFetchCounts['notice-1'], 2);
  });
}
