/// EPGZ-06 W3 — OA Tab SSO 协调流 widget 测试（fake launcher/webview）
///
/// 覆盖 [OaTabPage] 的 W3 集成行为：
/// - 启动自动签发 → loading（签发中）→ code 到达 → loading（倒计时）
///   → 首帧加载完成 → ready + 倒计时停止；
/// - 60s 倒计时归零 → sessionExpired（不重试同 code）→ 重新签发
///   （新 nonce、launcher 再次调用）；
/// - issue 失败（401/404）→ 状态机映射（sessionExpired / error）；
/// - 纵深防御：回显 redirect 离开允许 origin → originMismatch；
/// - W1 兼容：无 config 直构 → 不发起 SSO（占位槽形态不变）。
///
/// WebView 经 [webViewBuilder] 注入 fake（不触平台通道）；真实
/// NavigationDelegate 接线由 oa_webview_event_handlers_test 直测。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_sso_issue.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_tab_state.dart';
import 'package:imboy/modules/enterprise_oa/enterprise_oa_runtime_config.dart';
import 'package:imboy/modules/enterprise_oa/presentation/oa_tab_page.dart';

/// 测试用运行时配置（合法 gzCustomer 形态，绕过 dart-define）。
EnterpriseOaRuntimeConfig testConfig({String? redirectUri}) {
  return EnterpriseOaRuntimeConfig.fromMap(<String, dynamic>{
    'IMBOY_WL_FLAVOR': 'gzCustomer',
    'IMBOY_WL_OA_ORIGIN': 'https://oa.example.com',
    'IMBOY_WL_OA_LABEL': '办公',
    'IMBOY_WL_OA_ENTRY_ENABLED': 'true',
    'IMBOY_WL_OA_APPLICATION_KEY': 'ak_gz_customer_01',
    'IMBOY_WL_OA_REDIRECT_URI':
        redirectUri ?? 'https://oa.example.com/sso/landing',
  });
}

class _FakeLauncher implements OaSsoIssueLauncher {
  _FakeLauncher(this.results);

  /// 逐次弹出的结果（不足时重复最后一个）。
  final List<OaSsoIssueResult> results;
  final List<({String applicationKey, String redirectUri, String nonce})>
  calls = [];

  @override
  Future<OaSsoIssueResult> launch({
    required String applicationKey,
    required String redirectUri,
    required String nonce,
  }) async {
    calls.add((
      applicationKey: applicationKey,
      redirectUri: redirectUri,
      nonce: nonce,
    ));
    return calls.length <= results.length
        ? results[calls.length - 1]
        : results.last;
  }
}

class _DelayedLauncher implements OaSsoIssueLauncher {
  final pending = Completer<OaSsoIssueResult>();
  int calls = 0;
  @override
  Future<OaSsoIssueResult> launch({
    required String applicationKey,
    required String redirectUri,
    required String nonce,
  }) {
    calls++;
    return pending.future;
  }
}

_OaSsoCodeIssuedRef _issued({String? redirectUri}) {
  return _OaSsoCodeIssuedRef(redirectUri: redirectUri);
}

class _OaSsoCodeIssuedRef {
  _OaSsoCodeIssuedRef({this.redirectUri});
  final String? redirectUri;
  OaSsoCodeIssued build() => OaSsoCodeIssued(
    code: 'oa_sso_test_code',
    redirectUri: redirectUri ?? 'https://oa.example.com/sso/landing',
    expiresInSeconds: 60,
  );
}

/// 帧驱动 fake webview：真实容器同形接线（onPageFinished 模拟——
/// loading → ready + 首载信号）。
class _FakeWebView extends StatefulWidget {
  const _FakeWebView(this.props, {this.autoFinish = true});

  final bool autoFinish;

  final OaWebViewSlotProps props;

  @override
  State<_FakeWebView> createState() => _FakeWebViewState();
}

class _FakeWebViewState extends State<_FakeWebView> {
  static int mounts = 0;
  static int disposals = 0;
  @override
  void initState() {
    super.initState();
    mounts++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.autoFinish) return;
      // 模拟 onPageFinished：loading → ready + 首载信号 + 状态回流。
      if (widget.props.machine.markReady()) {
        widget.props.onFirstPageLoaded();
      }
      widget.props.onStateChanged();
    });
  }

  @override
  void dispose() {
    disposals++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    'FAKE_WEBVIEW ${widget.props.initialUrl}',
    key: const ValueKey('fake_webview'),
  );
}

Widget host(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('loading to ready keeps the single-use SSO WebView mounted', (
    tester,
  ) async {
    _FakeWebViewState.mounts = 0;
    _FakeWebViewState.disposals = 0;
    final machine = OaTabStateMachine();
    final launcher = _FakeLauncher([_issued().build()]);
    await tester.pumpWidget(
      host(
        OaTabPage(
          config: testConfig(),
          machine: machine,
          ssoLauncher: launcher,
          webViewBuilder: _FakeWebView.new,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(machine.status, OaTabStatus.ready);
    expect(launcher.calls, hasLength(1));
    expect(_FakeWebViewState.mounts, 1);
    expect(_FakeWebViewState.disposals, 0);
    await tester.pumpWidget(host(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(_FakeWebViewState.disposals, 1);
  });

  testWidgets('切换远端 Tab 后 OA 保活，不重新签发', (tester) async {
    final launcher = _FakeLauncher([_issued().build()]);
    final controller = PageController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        PageView(
          controller: controller,
          children: [
            OaTabPage(
              config: testConfig(),
              ssoLauncher: launcher,
              webViewBuilder: _FakeWebView.new,
            ),
            const Text('second'),
            const Text('third'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpToPage(2);
    await tester.pumpAndSettle();
    controller.jumpToPage(0);
    await tester.pumpAndSettle();
    expect(launcher.calls, hasLength(1));
    expect(find.byKey(const ValueKey('fake_webview')), findsOneWidget);
  });
  for (final changeAccount in [false, true]) {
    testWidgets('切换${changeAccount ? '账号' : '企业'}丢弃旧签发结果', (tester) async {
      final launcher = _DelayedLauncher();
      final machine = OaTabStateMachine();
      Widget page(String account, String organization) => host(
        OaTabPage(
          key: const ValueKey('scoped-oa'),
          config: testConfig(),
          machine: machine,
          accountKey: account,
          organizationId: organization,
          ssoLauncher: launcher,
          webViewBuilder: _FakeWebView.new,
        ),
      );
      await tester.pumpWidget(page('account-a', 'org-a'));
      await tester.pump();
      expect(launcher.calls, 1);
      await tester.pumpWidget(
        page(
          changeAccount ? 'account-b' : 'account-a',
          changeAccount ? 'org-a' : 'org-b',
        ),
      );
      launcher.pending.complete(_issued().build());
      await tester.pump();
      await tester.pump(const Duration(seconds: 70));
      expect(machine.status, OaTabStatus.loggedOut);
      expect(find.byKey(const ValueKey('fake_webview')), findsNothing);
      expect(launcher.calls, 1);
    });
  }

  testWidgets('关闭旧企业页面后旧回调不能恢复内容', (tester) async {
    final machine = OaTabStateMachine();
    final launcher = _FakeLauncher([_issued().build()]);
    OaWebViewSlotProps? oldProps;
    Widget page(String organization) => host(
      OaTabPage(
        key: const ValueKey('scoped-oa'),
        config: testConfig(),
        machine: machine,
        accountKey: 'account-a',
        organizationId: organization,
        ssoLauncher: launcher,
        webViewBuilder: (props) {
          oldProps = props;
          return _FakeWebView(props);
        },
      ),
    );
    await tester.pumpWidget(page('org-a'));
    await tester.pumpAndSettle();
    expect(machine.status, OaTabStatus.ready);
    expect(oldProps, isNotNull);
    await tester.pumpWidget(page(''));
    oldProps!.onFirstPageLoaded();
    oldProps!.onStateChanged();
    expect(machine.markReady(), isFalse);
    await tester.pumpAndSettle();
    expect(machine.status, OaTabStatus.loggedOut);
    expect(find.byKey(const ValueKey('fake_webview')), findsNothing);
  });

  testWidgets('明确缺失企业时不签发 OA code', (tester) async {
    final launcher = _FakeLauncher([_issued().build()]);
    await tester.pumpWidget(
      host(
        OaTabPage(
          config: testConfig(),
          accountKey: 'account-a',
          organizationId: '',
          ssoLauncher: launcher,
        ),
      ),
    );
    await tester.pump();
    expect(launcher.calls, isEmpty);
  });

  testWidgets('签发异常进入可恢复错误状态', (tester) async {
    final launcher = _DelayedLauncher();
    final machine = OaTabStateMachine();
    await tester.pumpWidget(
      host(
        OaTabPage(
          config: testConfig(),
          machine: machine,
          ssoLauncher: launcher,
        ),
      ),
    );
    await tester.pump();
    launcher.pending.completeError(StateError('synthetic transport failure'));
    await tester.pumpAndSettle();
    expect(machine.status, OaTabStatus.error);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未配置 OA 的直构形态：不发起 SSO（W1 兼容）', (tester) async {
    final launcher = _FakeLauncher([_issued().build()]);
    await tester.pumpWidget(
      host(OaTabPage(machine: OaTabStateMachine(), ssoLauncher: launcher)),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(launcher.calls, isEmpty);
  });

  testWidgets('签发成功链：loading→code 到达→首帧→ready，倒计时停止', (tester) async {
    final launcher = _FakeLauncher([_issued().build()]);
    OaWebViewSlotProps? loadingProps;
    await tester.pumpWidget(
      host(
        OaTabPage(
          config: testConfig(),
          ssoLauncher: launcher,
          nonceGenerator: () => 'nonce-fixed-0123456789',
          webViewBuilder: (props) {
            loadingProps = props;
            return _FakeWebView(props, autoFinish: false);
          },
        ),
      ),
    );

    // 签发在途/完成（microtask 快于帧调度，只断言请求已发出）。
    await tester.pump();
    expect(launcher.calls, hasLength(1));
    expect(launcher.calls.single.nonce, 'nonce-fixed-0123456789');
    expect(launcher.calls.single.applicationKey, 'ak_gz_customer_01');

    // code 到达：loading + 倒计时（60 起步）。
    await tester.pump();
    expect(
      find.text(t.enterpriseOa.ssoCountdown(seconds: '60')),
      findsOneWidget,
    );

    // 真正的 page-finished 回调后移除遮罩，保持原 WebView。
    expect(loadingProps!.machine.markReady(), isTrue);
    loadingProps!.onFirstPageLoaded();
    loadingProps!.onStateChanged();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('fake_webview')), findsOneWidget);

    // 倒计时已停：20s 后无 sessionExpired，倒计时文案消失。
    await tester.pump(const Duration(seconds: 20));
    expect(
      find.textContaining(t.enterpriseOa.statusExpiredTitle),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('fake_webview')), findsOneWidget);
  });

  testWidgets('60s 倒计时归零 → sessionExpired；重新签发用新 nonce', (tester) async {
    final launcher = _FakeLauncher([_issued().build(), _issued().build()]);
    var nonceSeq = 0;
    await tester.pumpWidget(
      host(
        OaTabPage(
          config: testConfig(),
          ssoLauncher: launcher,
          nonceGenerator: () => 'nonce-seq-${nonceSeq++}-0123456789',
          // 惰性 webview：不触发 markReady，保持 loading 直到倒计时归零。
          webViewBuilder: (_) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();

    // 推进到 59s（剩余 1s）。
    await tester.pump(const Duration(seconds: 59));
    expect(
      find.text(t.enterpriseOa.ssoCountdown(seconds: '1')),
      findsOneWidget,
    );

    // 归零 → sessionExpired。
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(t.enterpriseOa.statusExpiredTitle), findsOneWidget);
    expect(find.text(t.enterpriseOa.actionRestartSso), findsOneWidget);

    // 重新单点登录：新签发（第二次调用）+ 新 nonce。
    await tester.tap(find.text(t.enterpriseOa.actionRestartSso));
    await tester.pump(const Duration(milliseconds: 300));
    expect(launcher.calls, hasLength(2));
    expect(launcher.calls[0].nonce, isNot(launcher.calls[1].nonce));
  });

  testWidgets('issue 401 → sessionExpired（重新单点登录动作）', (tester) async {
    final launcher = _FakeLauncher([
      const OaSsoIssueFailed(OaSsoIssueFailureKind.unauthorized),
    ]);
    await tester.pumpWidget(
      host(
        OaTabPage(
          config: testConfig(),
          ssoLauncher: launcher,
          nonceGenerator: () => 'nonce-401-0123456789ab',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(t.enterpriseOa.statusExpiredTitle), findsOneWidget);
    expect(find.text(t.enterpriseOa.actionRestartSso), findsOneWidget);
  });

  testWidgets('issue 404 → error（重试动作）', (tester) async {
    final launcher = _FakeLauncher([
      const OaSsoIssueFailed(OaSsoIssueFailureKind.notFound),
    ]);
    await tester.pumpWidget(
      host(
        OaTabPage(
          config: testConfig(),
          ssoLauncher: launcher,
          nonceGenerator: () => 'nonce-404-0123456789ab',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(t.enterpriseOa.statusErrorTitle), findsOneWidget);
    expect(find.text(t.enterpriseOa.actionRetry), findsOneWidget);
  });

  testWidgets('issue 网络失败 → error；重试在无可用 code 时重新签发', (tester) async {
    final launcher = _FakeLauncher([
      const OaSsoIssueFailed(OaSsoIssueFailureKind.network),
      _issued().build(),
    ]);
    await tester.pumpWidget(
      host(
        OaTabPage(
          config: testConfig(),
          ssoLauncher: launcher,
          nonceGenerator: () => 'nonce-net-0123456789',
          webViewBuilder: (_) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(t.enterpriseOa.statusErrorTitle), findsOneWidget);

    // 重试：无 activeUrl（从未取得 code）→ 重新签发。
    await tester.tap(find.text(t.enterpriseOa.actionRetry));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(launcher.calls, hasLength(2));
  });

  testWidgets('回显 redirect 离开允许 origin → originMismatch（纵深防御）', (tester) async {
    final launcher = _FakeLauncher([
      _issued(redirectUri: 'https://evil.example.com/sso/landing').build(),
    ]);
    await tester.pumpWidget(
      host(
        OaTabPage(
          config: testConfig(),
          ssoLauncher: launcher,
          nonceGenerator: () => 'nonce-drift-0123456789',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(t.enterpriseOa.statusMismatchTitle), findsOneWidget);
    // 附注行只显示 host，不显示完整 URL/query。
    expect(
      find.text(
        t.enterpriseOa.statusMismatchBlockedHost(host: 'evil.example.com'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('launch URL 携带 code 与 state（nonce 原样回传）', (tester) async {
    final launcher = _FakeLauncher([_issued().build()]);
    String? seenUrl;
    await tester.pumpWidget(
      host(
        OaTabPage(
          config: testConfig(),
          ssoLauncher: launcher,
          nonceGenerator: () => 'nonce-state-0123456789',
          webViewBuilder: (OaWebViewSlotProps props) {
            seenUrl = props.initialUrl;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(seenUrl, contains('code=oa_sso_test_code'));
    expect(seenUrl, contains('state=nonce-state-0123456789'));
    expect(seenUrl, startsWith('https://oa.example.com/sso/landing'));
  });
}
