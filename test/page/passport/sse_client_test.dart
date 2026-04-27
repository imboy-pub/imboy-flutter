/// SseClient 抽象 + IO stub 契约测试（PR-4β）。
///
/// 测试运行在非 Web 平台（VM），因此走 `sse_client_io.dart` stub 路径。
/// Web 实现 `sse_client_web.dart` 用 dart:js_interop，需 dart2js / dartdevc，
/// 不在 `flutter test` VM 测试范围；交由 PR-4γ 集成测试覆盖。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/passport/sse_client.dart';

void main() {
  group('createSseClient (IO stub on test VM)', () {
    test('返回非空 SseClient 实例', () {
      final client = createSseClient();
      expect(client, isA<SseClient>());
    });

    test('isOpen 初始为 false', () {
      final client = createSseClient();
      expect(client.isOpen, isFalse);
    });

    test('frames 是空流（非 Web 平台无 EventSource）', () async {
      final client = createSseClient();
      // 监听 100ms 应该没收到任何 frame
      final received = <String>[];
      final sub = client.frames.listen(received.add);
      await Future.delayed(const Duration(milliseconds: 100));
      await sub.cancel();
      expect(received, isEmpty);
    });

    test('errors 是空流（IO stub 不会触发 error 事件）', () async {
      final client = createSseClient();
      final received = <Object>[];
      final sub = client.errors.listen(received.add);
      await Future.delayed(const Duration(milliseconds: 100));
      await sub.cancel();
      expect(received, isEmpty);
    });

    test('connect() 抛 UnsupportedError（非 Web 平台禁用）', () async {
      final client = createSseClient();
      await expectLater(
        client.connect('http://example.com/sse'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('close() 静默 ok（idempotent）', () async {
      final client = createSseClient();
      await client.close();
      await client.close(); // 二次 close 不抛
    });

    test('close() 后 isOpen 仍为 false', () async {
      final client = createSseClient();
      await client.close();
      expect(client.isOpen, isFalse);
    });
  });

  // -----------------------------------------------------------------------
  // 抽象契约：任何实现都应满足以下不变式
  // -----------------------------------------------------------------------
  group('SseClient abstract contract', () {
    test('frames 必须是 broadcast stream（多订阅安全）', () async {
      // 必要条件：让 PR-4γ Notifier 能多次 listen 不抛
      final client = createSseClient();
      final s1 = client.frames.listen((_) {});
      final s2 = client.frames.listen((_) {});
      await s1.cancel();
      await s2.cancel();
    });

    test('errors 必须是 broadcast stream', () async {
      final client = createSseClient();
      final s1 = client.errors.listen((_) {});
      final s2 = client.errors.listen((_) {});
      await s1.cancel();
      await s2.cancel();
    });
  });
}
