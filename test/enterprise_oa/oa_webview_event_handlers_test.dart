/// EPGZ-06 W3 — WebView 事件 → 状态机裁决测试（脱离平台通道直驱）
///
/// 覆盖 [OaWebViewEventHandlers]：
/// - onNavigationRequest 走 ExactOriginNavigationHandler（allow/mismatch/cancel）
///   且 mismatch 记录拦截事实；
/// - onPageFinished → ready + 一次性 onFirstPageLoaded；
/// - 主帧加载失败 → error（仅 loading 态）；
/// - 主帧 HTTP 401 → oaUnauthorized（ready）；loading 态回退 error
///   （W1 冻结语义：oa401 只能从 ready 进入）；非 401 不动状态机。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:imboy/modules/enterprise_oa/domain/oa_tab_state.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_webview_policy.dart';
import 'package:imboy/modules/enterprise_oa/presentation/oa_webview_container.dart';

const String allowedOrigin = 'https://oa.example.com';

OaWebViewEventHandlers handlers({
  required OaTabStateMachine machine,
  void Function()? onFirstPageLoaded,
}) {
  return OaWebViewEventHandlers(
    machine: machine,
    navigationHandler: const ExactOriginNavigationHandler(
      allowedOrigin: allowedOrigin,
    ),
    onFirstPageLoaded: onFirstPageLoaded,
  );
}

void main() {
  group('decideNavigation — exact-origin 接线', () {
    test('允许 origin 内导航 → navigate', () {
      final machine = OaTabStateMachine();
      final decision = handlers(machine: machine)
          .decideNavigation('https://oa.example.com/app/home?x=1');
      expect(decision, NavigationDecision.navigate);
      expect(machine.status, OaTabStatus.loading);
    });

    test('域名跳转 → prevent + originMismatch + 拦截事实', () {
      final machine = OaTabStateMachine();
      final decision = handlers(machine: machine)
          .decideNavigation('https://evil.com/phish?token=SECRET');
      expect(decision, NavigationDecision.prevent);
      expect(machine.status, OaTabStatus.originMismatch);
      expect(machine.mismatchFact?.attemptedUrl, contains('evil.com'));
      expect(machine.mismatchFact?.allowedOrigin, allowedOrigin);
    });

    test('子域仿冒 → prevent + originMismatch', () {
      final machine = OaTabStateMachine();
      final decision = handlers(machine: machine)
          .decideNavigation('https://oa.example.com.evil.com/');
      expect(decision, NavigationDecision.prevent);
      expect(machine.status, OaTabStatus.originMismatch);
    });

    test('非 http(s) scheme（javascript:）→ prevent（非 mismatch）', () {
      final machine = OaTabStateMachine();
      final decision = handlers(machine: machine)
          .decideNavigation('javascript:alert(1)');
      expect(decision, NavigationDecision.prevent);
      expect(machine.status, OaTabStatus.loading);
    });

    test('端口不匹配 → prevent + originMismatch', () {
      final machine = OaTabStateMachine();
      expect(
        handlers(machine: machine)
            .decideNavigation('https://oa.example.com:8443/app'),
        NavigationDecision.prevent,
      );
      expect(machine.status, OaTabStatus.originMismatch);
    });

    test('ready 态的 mismatch 拦截同样成立（页内跳转防护）', () {
      final machine = OaTabStateMachine()..markReady();
      handlers(machine: machine).decideNavigation('https://evil.com/');
      expect(machine.status, OaTabStatus.originMismatch);
      expect(machine.mismatchFact, isNotNull);
    });
  });

  group('onPageFinished — ready + 一次性首载信号', () {
    test('loading → ready，onFirstPageLoaded 恰好一次', () {
      int loaded = 0;
      final machine = OaTabStateMachine();
      final h = handlers(machine: machine, onFirstPageLoaded: () => loaded++);
      h.onPageFinished('https://oa.example.com/landing?code=x&state=y');
      expect(machine.status, OaTabStatus.ready);
      h.onPageFinished('https://oa.example.com/app');
      h.onPageFinished('https://oa.example.com/app/home');
      expect(loaded, 1);
    });

    test('非 loading 态 finish 不推翻状态机（fail-closed）', () {
      final machine = OaTabStateMachine(initial: OaTabStatus.error);
      handlers(machine: machine).onPageFinished('https://oa.example.com/');
      expect(machine.status, OaTabStatus.error);
    });
  });

  group('onMainFrameLoadFailed — 主帧加载失败 → error', () {
    test('loading 态 → error', () {
      final machine = OaTabStateMachine();
      handlers(machine: machine).onMainFrameLoadFailed();
      expect(machine.status, OaTabStatus.error);
      expect(machine.canRetry, isTrue);
    });

    test('ready 态保持（页内导航失败由 WebView 错误页自呈现）', () {
      final machine = OaTabStateMachine()..markReady();
      handlers(machine: machine).onMainFrameLoadFailed();
      expect(machine.status, OaTabStatus.ready);
    });
  });

  group('onMainFrameHttpStatus — OA 401', () {
    test('ready 态 401 → oaUnauthorized', () {
      final machine = OaTabStateMachine()..markReady();
      handlers(machine: machine).onMainFrameHttpStatus(401);
      expect(machine.status, OaTabStatus.oaUnauthorized);
      expect(machine.requiresSsoRestart, isTrue);
    });

    test('loading 态 401 → 回退 error（W1 冻结：oa401 仅 ready 可入）', () {
      final machine = OaTabStateMachine();
      handlers(machine: machine).onMainFrameHttpStatus(401);
      expect(machine.status, OaTabStatus.error);
    });

    test('非 401 状态码不动状态机（OA 页面自处理）', () {
      final machine = OaTabStateMachine();
      handlers(machine: machine).onMainFrameHttpStatus(500);
      handlers(machine: machine).onMainFrameHttpStatus(302);
      expect(machine.status, OaTabStatus.loading);
    });
  });
}
