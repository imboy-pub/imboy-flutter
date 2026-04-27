/// VisibilityObserver 抽象 + IO stub 契约测试（PR-5β-1）。
///
/// 测试运行在 VM（非 Web 平台），走 IO stub 路径。
/// Web 实现 `visibility_observer_web.dart` 用 dart:js_interop，
/// 由 PR-5β-2 widget 集成测试 + 浏览器手工验证覆盖。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/passport/visibility_observer.dart';

void main() {
  group('createVisibilityObserver (IO stub on test VM)', () {
    test('返回非空 VisibilityObserver 实例', () {
      final obs = createVisibilityObserver();
      expect(obs, isA<VisibilityObserver>());
    });

    test('isVisible 永远为 true（移动端无后台 tab 概念）', () {
      final obs = createVisibilityObserver();
      expect(obs.isVisible, isTrue);
    });

    test('visibilityChanges 是空流（IO 平台不触发事件）', () async {
      final obs = createVisibilityObserver();
      final received = <bool>[];
      final sub = obs.visibilityChanges.listen(received.add);
      await Future.delayed(const Duration(milliseconds: 100));
      await sub.cancel();
      expect(received, isEmpty);
    });

    test('close() 静默 ok（idempotent）', () async {
      final obs = createVisibilityObserver();
      await obs.close();
      await obs.close(); // 二次 close 不抛
    });

    test('close() 后 isVisible 仍为 true（IO stub 状态稳定）', () async {
      final obs = createVisibilityObserver();
      await obs.close();
      expect(obs.isVisible, isTrue);
    });
  });

  group('VisibilityObserver abstract contract', () {
    test('visibilityChanges 必须是 broadcast stream（多订阅安全）', () async {
      // 必要条件：让 PR-5β-2 widget 可多次 listen 不抛
      final obs = createVisibilityObserver();
      final s1 = obs.visibilityChanges.listen((_) {});
      final s2 = obs.visibilityChanges.listen((_) {});
      await s1.cancel();
      await s2.cancel();
    });
  });
}
