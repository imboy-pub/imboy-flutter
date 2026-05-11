/// QrSseSession 单测（PR-4γ RED→GREEN→REFACTOR）。
///
/// FakeSseClient 用 StreamController 驱动 frames/errors，避免真启 EventSource。
/// fake_async 控制 watcher Timer.periodic，不用真 sleep。
library;

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/passport/qr_login_response_rules.dart';
import 'package:imboy/page/passport/qr_sse_session.dart';
import 'package:imboy/page/passport/sse_client.dart';

// ---------------------------------------------------------------------------
// FakeSseClient: 测试驱动
// ---------------------------------------------------------------------------

class FakeSseClient implements SseClient {
  final StreamController<String> _framesCtrl = StreamController<String>.broadcast();
  final StreamController<Object> _errorsCtrl = StreamController<Object>.broadcast();
  bool _isOpen = false;
  bool _closed = false;
  int connectCalls = 0;
  String? lastUrl;
  bool failOnConnect = false;

  @override
  bool get isOpen => _isOpen;

  @override
  Stream<String> get frames => _framesCtrl.stream;

  @override
  Stream<Object> get errors => _errorsCtrl.stream;

  @override
  Future<void> connect(String url) async {
    connectCalls++;
    lastUrl = url;
    if (failOnConnect) {
      throw const SocketExceptionStub('connect failed');
    }
    _isOpen = true;
  }

  @override
  Future<void> close() async {
    _closed = true;
    _isOpen = false;
  }

  bool get closed => _closed;

  // 测试驱动
  void emitFrame(String raw) => _framesCtrl.add(raw);
  void emitError(Object err) => _errorsCtrl.add(err);
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub(this.msg);
  final String msg;
  @override
  String toString() => msg;
}

// ---------------------------------------------------------------------------
// 测试套件
// ---------------------------------------------------------------------------

void main() {
  group('QrSseSession.start', () {
    test('调用 client.connect 一次，并传入正确 url', () async {
      final client = FakeSseClient();
      final session = QrSseSession(
        client: client,
        onEvent: (_) {},
        onFallback: () {},
      );
      await session.start('http://api.example.com/sse?session_token=abc');
      expect(client.connectCalls, 1);
      expect(client.lastUrl, 'http://api.example.com/sse?session_token=abc');
      await session.stop();
    });

    test('收到 data: frame → onEvent 收到对应 QrStatusEvent', () async {
      final client = FakeSseClient();
      final received = <QrStatusEvent>[];
      final session = QrSseSession(
        client: client,
        onEvent: received.add,
        onFallback: () {},
      );
      await session.start('http://x');
      client.emitFrame('data: {"status":"scanned"}');
      await Future<dynamic>.delayed(Duration.zero);
      expect(received, hasLength(1));
      expect(received.first, isA<QrStatusScanned>());
      await session.stop();
    });

    test('多帧顺序：scanned 然后 confirmed → onEvent 接收 2 个事件保序', () async {
      final client = FakeSseClient();
      final received = <QrStatusEvent>[];
      final session = QrSseSession(
        client: client,
        onEvent: received.add,
        onFallback: () {},
      );
      await session.start('http://x');
      client.emitFrame('data: {"status":"scanned"}');
      client.emitFrame('data: {"status":"confirmed","token":"jwt_xyz"}');
      await Future<dynamic>.delayed(Duration.zero);
      expect(received, hasLength(2));
      expect(received[0], isA<QrStatusScanned>());
      expect(received[1], isA<QrStatusConfirmed>());
      expect((received[1] as QrStatusConfirmed).token, 'jwt_xyz');
      await session.stop();
    });

    test('connect 抛异常 → 不 crash，watcher 后续触发 fallback', () {
      fakeAsync((async) {
        final client = FakeSseClient()..failOnConnect = true;
        var fallbackCalled = false;
        final session = QrSseSession(
          client: client,
          onEvent: (_) {},
          onFallback: () => fallbackCalled = true,
        );
        // start 不抛
        session.start('http://x');
        async.flushMicrotasks();
        // attemptFailed=true → 立即 fallback（gracePeriod 不会拦截 attemptFailed）
        async.elapse(const Duration(seconds: 1));
        expect(fallbackCalled, isTrue);
        session.stop();
      });
    });

    test('errors 流触发 → 立即 fallback（attemptFailed 优先于 gracePeriod）', () {
      fakeAsync((async) {
        final client = FakeSseClient();
        var fallbackCalled = false;
        final session = QrSseSession(
          client: client,
          onEvent: (_) {},
          onFallback: () => fallbackCalled = true,
        );
        session.start('http://x');
        async.flushMicrotasks();
        client.emitError('network down');
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        expect(fallbackCalled, isTrue);
        session.stop();
      });
    });

    test('未连且超 gracePeriod 秒未收到 frame → fallback', () {
      fakeAsync((async) {
        final client = FakeSseClient();
        // 模拟 connect 永远 pending（不 await）
        var fallbackCalled = false;
        final session = QrSseSession(
          client: client,
          onEvent: (_) {},
          onFallback: () => fallbackCalled = true,
        );
        session.start('http://x', gracePeriodSeconds: 3);
        async.flushMicrotasks();
        // connect 完成 → isOpen=true → 不应 fallback
        // 但 FakeSseClient.connect 默认 setSync isOpen，需手动重置 isOpen=false
        client._isOpen = false;
        async.elapse(const Duration(seconds: 2));
        expect(fallbackCalled, isFalse, reason: 'gracePeriod 内不降级');
        async.elapse(const Duration(seconds: 2));
        expect(fallbackCalled, isTrue, reason: '超出 gracePeriod 应降级');
        session.stop();
      });
    });

    test('已连接（isOpen=true）+ 长时间无 frame → 不降级', () {
      fakeAsync((async) {
        final client = FakeSseClient();
        var fallbackCalled = false;
        final session = QrSseSession(
          client: client,
          onEvent: (_) {},
          onFallback: () => fallbackCalled = true,
        );
        session.start('http://x', gracePeriodSeconds: 3);
        async.flushMicrotasks();
        // isOpen=true 后即使长时间静默也不应 fallback（waiting 阶段正常）
        async.elapse(const Duration(seconds: 60));
        expect(fallbackCalled, isFalse);
        session.stop();
      });
    });

    test('收到 frame 重置 silent 计数（防 fallback 误触）', () {
      fakeAsync((async) {
        final client = FakeSseClient();
        var fallbackCalled = false;
        final session = QrSseSession(
          client: client,
          onEvent: (_) {},
          onFallback: () => fallbackCalled = true,
        );
        session.start('http://x', gracePeriodSeconds: 3);
        async.flushMicrotasks();
        client._isOpen = false;
        async.elapse(const Duration(seconds: 2));
        client.emitFrame('data: {"status":"waiting"}');
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        expect(fallbackCalled, isFalse, reason: 'frame 应重置 silent 计数');
      });
    });

    test('fallback 触发后只回调一次（即使 watcher 继续 tick）', () {
      fakeAsync((async) {
        final client = FakeSseClient()..failOnConnect = true;
        var fallbackCount = 0;
        final session = QrSseSession(
          client: client,
          onEvent: (_) {},
          onFallback: () => fallbackCount++,
        );
        session.start('http://x');
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));
        expect(fallbackCount, 1, reason: 'fallback 应防重入');
        session.stop();
      });
    });
  });

  group('QrSseSession.onResume (visibilitychange 后台 tab 切回)', () {
    test('start 后 onResume 重置 silent 计数防误判 fallback', () {
      fakeAsync((async) {
        final client = FakeSseClient();
        var fallbackCalled = false;
        final session = QrSseSession(
          client: client,
          onEvent: (_) {},
          onFallback: () => fallbackCalled = true,
        );
        session.start('http://x', gracePeriodSeconds: 3);
        async.flushMicrotasks();
        // 模拟浏览器后台 tab：watcher 仍在 tick 但用户切走
        client._isOpen = false;
        async.elapse(const Duration(seconds: 2));
        // 用户切回前台前调 onResume（widget visibilitychange callback）
        session.onResume();
        // 重置后再过 2 秒（共 4 秒 > gracePeriod 3 秒）— 但因为 reset 不应触发
        async.elapse(const Duration(seconds: 2));
        expect(fallbackCalled, isFalse,
            reason: 'onResume 重置后 silent 计数应从 0 重新累积');
        // 再过 2 秒（reset 后累计 4 秒 > 3）才应触发
        async.elapse(const Duration(seconds: 2));
        expect(fallbackCalled, isTrue);
        session.stop();
      });
    });

    test('start 前调用 onResume 安全无副作用（不抛）', () {
      final client = FakeSseClient();
      final session = QrSseSession(
        client: client,
        onEvent: (_) {},
        onFallback: () {},
      );
      // 未 start 直接 onResume
      expect(() => session.onResume(), returnsNormally);
    });

    test('stop 后 onResume 不影响已停止状态', () async {
      final client = FakeSseClient();
      final session = QrSseSession(
        client: client,
        onEvent: (_) {},
        onFallback: () {},
      );
      await session.start('http://x');
      await session.stop();
      // stop 后 onResume 应安全（不重启 watcher / 不触发回调）
      expect(() => session.onResume(), returnsNormally);
    });

    test('多次 onResume 幂等', () {
      fakeAsync((async) {
        final client = FakeSseClient();
        var fallbackCount = 0;
        final session = QrSseSession(
          client: client,
          onEvent: (_) {},
          onFallback: () => fallbackCount++,
        );
        session.start('http://x', gracePeriodSeconds: 3);
        async.flushMicrotasks();
        client._isOpen = false;
        // 连续 5 次 onResume
        for (var i = 0; i < 5; i++) {
          async.elapse(const Duration(seconds: 1));
          session.onResume();
        }
        // 经过 5 秒但每秒 reset，累计 silent < 3
        expect(fallbackCount, 0);
        // 停止 reset，等 4 秒应触发 fallback（一次）
        async.elapse(const Duration(seconds: 4));
        expect(fallbackCount, 1);
        session.stop();
      });
    });
  });

  group('QrSseSession.stop', () {
    test('stop 调用 client.close + cancel subs，多次调用安全', () async {
      final client = FakeSseClient();
      final session = QrSseSession(
        client: client,
        onEvent: (_) {},
        onFallback: () {},
      );
      await session.start('http://x');
      await session.stop();
      expect(client.closed, isTrue);
      // 二次 stop 不抛
      await session.stop();
    });

    test('stop 后 frame 不再触发 onEvent（防止泄漏回调）', () async {
      final client = FakeSseClient();
      final received = <QrStatusEvent>[];
      final session = QrSseSession(
        client: client,
        onEvent: received.add,
        onFallback: () {},
      );
      await session.start('http://x');
      await session.stop();
      client.emitFrame('data: {"status":"scanned"}');
      await Future<dynamic>.delayed(Duration.zero);
      expect(received, isEmpty);
    });
  });
}
