/// EPGZ-06 W1 — OA Tab 容器状态机单测（plan §7.2）
///
/// 覆盖七态全迁移边 + 非法迁移 fail-closed（状态不变、返回 false）：
/// loading / ready / error / sessionExpired / loggedOut /
/// originMismatch / oaUnauthorized，及 retry / restartSso 恢复路径。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/enterprise_oa/public.dart';

void main() {
  group('OaTabStateMachine 主干迁移', () {
    test('loading → ready → loggedOut → restartSso → loading', () {
      final m = OaTabStateMachine();
      expect(m.status, OaTabStatus.loading);
      expect(m.isReady, isFalse);

      expect(m.markReady(), isTrue);
      expect(m.status, OaTabStatus.ready);
      expect(m.isReady, isTrue);

      expect(m.markLoggedOut(), isTrue);
      expect(m.status, OaTabStatus.loggedOut);
      expect(m.requiresSsoRestart, isTrue);

      expect(m.restartSso(), isTrue);
      expect(m.status, OaTabStatus.loading);
    });

    test('loading → error → retry → loading → ready', () {
      final m = OaTabStateMachine()..markError();
      expect(m.status, OaTabStatus.error);
      expect(m.canRetry, isTrue);
      expect(m.requiresSsoRestart, isFalse);

      expect(m.retry(), isTrue);
      expect(m.status, OaTabStatus.loading);
      expect(m.markReady(), isTrue);
    });

    test('ready → oa401 → restartSso → loading', () {
      final m = OaTabStateMachine()
        ..markReady()
        ..markOaUnauthorized();
      expect(m.status, OaTabStatus.oaUnauthorized);
      expect(m.requiresSsoRestart, isTrue);

      expect(m.restartSso(), isTrue);
      expect(m.status, OaTabStatus.loading);
    });

    test('sessionExpired 可从 loading 或 ready 进入（code 兑换晚于加载）', () {
      final fromLoading = OaTabStateMachine()..markSessionExpired();
      expect(fromLoading.status, OaTabStatus.sessionExpired);

      final fromReady = OaTabStateMachine()
        ..markReady()
        ..markSessionExpired();
      expect(fromReady.status, OaTabStatus.sessionExpired);
    });
  });

  group('originMismatch 分支', () {
    test('ready 态拦截记录事实，最新事实覆盖展示', () {
      final m = OaTabStateMachine()..markReady();
      expect(
        m.markOriginMismatch(
          attemptedUrl: 'https://evil.com/phish',
          allowedOrigin: 'https://oa.example.com',
        ),
        isTrue,
      );
      expect(m.status, OaTabStatus.originMismatch);
      expect(m.mismatchFact?.attemptedUrl, 'https://evil.com/phish');
      expect(m.mismatchFact?.allowedOrigin, 'https://oa.example.com');

      // 重复拦截：状态不变，事实更新为最新一次。
      expect(
        m.markOriginMismatch(
          attemptedUrl: 'https://evil2.com/x',
          allowedOrigin: 'https://oa.example.com',
        ),
        isTrue,
      );
      expect(m.mismatchFact?.attemptedUrl, 'https://evil2.com/x');

      // retry / restartSso 都可恢复，且清空事实。
      expect(m.retry(), isTrue);
      expect(m.status, OaTabStatus.loading);
      expect(m.mismatchFact, isNull);
    });

    test('loading 中重定向同样进入 mismatch（页面尚未 ready 也可能被劫持）', () {
      final m = OaTabStateMachine();
      expect(
        m.markOriginMismatch(
          attemptedUrl: 'https://evil.com',
          allowedOrigin: 'https://oa.example.com',
        ),
        isTrue,
      );
      expect(m.status, OaTabStatus.originMismatch);
    });

    test('mismatch 态也允许 restartSso（用户可直接重走 SSO）', () {
      final m = OaTabStateMachine()
        ..markOriginMismatch(
          attemptedUrl: 'https://evil.com',
          allowedOrigin: 'https://oa.example.com',
        )
        ..restartSso();
      expect(m.status, OaTabStatus.loading);
    });
  });

  group('非法迁移 fail-closed（状态不变 + 返回 false）', () {
    test('ready 之后不可重复 markReady / markError', () {
      final m = OaTabStateMachine()..markReady();
      expect(m.markReady(), isFalse);
      expect(m.markError(), isFalse);
      expect(m.status, OaTabStatus.ready);
    });

    test('terminal 态只经 restartSso 复活，不可直接 markReady', () {
      for (final initial in const [
        OaTabStatus.sessionExpired,
        OaTabStatus.loggedOut,
        OaTabStatus.oaUnauthorized,
      ]) {
        final m = OaTabStateMachine(initial: initial);
        expect(m.markReady(), isFalse, reason: '$initial');
        expect(m.markError(), isFalse, reason: '$initial');
        expect(m.retry(), isFalse, reason: '$initial');
        expect(m.status, initial, reason: '$initial');
      }
    });

    test('loggedOut 只能从 ready 进入；oa401 只能从 ready 进入', () {
      final mLoading = OaTabStateMachine();
      expect(mLoading.markLoggedOut(), isFalse);
      expect(mLoading.markOaUnauthorized(), isFalse);
      expect(mLoading.status, OaTabStatus.loading);

      final mError = OaTabStateMachine()..markError();
      expect(mError.markLoggedOut(), isFalse);
      expect(mError.markOaUnauthorized(), isFalse);
    });

    test('ready / loading 态不可 restartSso（无失效可言）', () {
      final mReady = OaTabStateMachine()..markReady();
      expect(mReady.restartSso(), isFalse);
      expect(mReady.status, OaTabStatus.ready);
    });

    test('error 态允许 restartSso（网络错也可选择直接重登）', () {
      final m = OaTabStateMachine()..markError();
      expect(m.restartSso(), isTrue);
      expect(m.status, OaTabStatus.loading);
    });
  });

  group('wireName 稳定（对齐后端/日志合同）', () {
    test('七态线名与 plan §7.2 命名一致', () {
      expect(OaTabStatus.loading.wireName, 'loading');
      expect(OaTabStatus.ready.wireName, 'ready');
      expect(OaTabStatus.error.wireName, 'error');
      expect(OaTabStatus.sessionExpired.wireName, 'sessionExpired');
      expect(OaTabStatus.loggedOut.wireName, 'loggedOut');
      expect(OaTabStatus.originMismatch.wireName, 'originMismatch');
      expect(OaTabStatus.oaUnauthorized.wireName, 'oaUnauthorized');
    });
  });
}
