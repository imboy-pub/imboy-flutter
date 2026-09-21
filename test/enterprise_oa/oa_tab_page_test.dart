/// EPGZ-06 W1 — OA Tab 容器页面骨架 widget 测试（plan §7.2）
///
/// 验收点：七态各自的稳定 UI（标题/提示/动作按钮）与骨架动作迁移
/// （retry / restartSso 驱动状态机回到 loading）。W1 不接真 WebView
/// 与共享 router——ready 态渲染占位槽即证明挂载点存在。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_oa/public.dart';

Widget host(OaTabPage page) => MaterialApp(home: page);

OaTabPage buildAt(OaTabStatus status) {
  return OaTabPage(machine: OaTabStateMachine(initial: status));
}

void main() {
  testWidgets('loading 态：进度指示 + 连接文案', (tester) async {
    await tester.pumpWidget(host(buildAt(OaTabStatus.loading)));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(t.enterpriseOa.statusLoading), findsOneWidget);
    expect(find.text(t.enterpriseOa.actionRetry), findsNothing);
  });

  testWidgets('ready 态：WebView 槽位占位（W3 接线点存在）', (tester) async {
    await tester.pumpWidget(host(buildAt(OaTabStatus.ready)));
    await tester.pumpAndSettle();

    expect(find.text(t.enterpriseOa.webviewSlotHint), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('error 态：标题/提示/重试按钮，点击后回 loading', (tester) async {
    var retryCount = 0;
    await tester.pumpWidget(
      host(
        OaTabPage(
          machine: OaTabStateMachine(initial: OaTabStatus.error),
          onRetry: () => retryCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(t.enterpriseOa.statusErrorTitle), findsOneWidget);
    expect(find.text(t.enterpriseOa.statusErrorHint), findsOneWidget);
    expect(find.text(t.enterpriseOa.actionRetry), findsOneWidget);

    await tester.tap(find.text(t.enterpriseOa.actionRetry));
    // 固定 pump：loading 态的 CircularProgressIndicator 会持续调度帧，
    // pumpAndSettle 会超时；AnimatedSwitcher 时长 200ms。
    await tester.pump(const Duration(milliseconds: 300));

    expect(retryCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('sessionExpired 态：提示重新单点登录', (tester) async {
    await tester.pumpWidget(host(buildAt(OaTabStatus.sessionExpired)));
    await tester.pumpAndSettle();

    expect(find.text(t.enterpriseOa.statusExpiredTitle), findsOneWidget);
    expect(find.text(t.enterpriseOa.statusExpiredHint), findsOneWidget);
    expect(find.text(t.enterpriseOa.actionRestartSso), findsOneWidget);
  });

  testWidgets('loggedOut 态：提示重新单点登录，点击后回 loading', (tester) async {
    var ssoCount = 0;
    await tester.pumpWidget(
      host(
        OaTabPage(
          machine: OaTabStateMachine(initial: OaTabStatus.loggedOut),
          onRestartSso: () => ssoCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(t.enterpriseOa.statusLoggedOutTitle), findsOneWidget);

    await tester.tap(find.text(t.enterpriseOa.actionRestartSso));
    // 固定 pump（loading spinner 不会 settle）。
    await tester.pump(const Duration(milliseconds: 300));

    expect(ssoCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('originMismatch 态：拦截提示附被拦 host（不含 query 等敏感参数）', (tester) async {
    final machine = OaTabStateMachine(initial: OaTabStatus.loading)
      ..markReady()
      ..markOriginMismatch(
        attemptedUrl: 'https://evil.com/phish?token=SHOULD_NOT_SHOW',
        allowedOrigin: 'https://oa.example.com',
      );
    await tester.pumpWidget(host(OaTabPage(machine: machine)));
    await tester.pumpAndSettle();

    expect(find.text(t.enterpriseOa.statusMismatchTitle), findsOneWidget);
    // hint 与被拦 host 是两个独立 Text（后者为附注行）。
    expect(find.text(t.enterpriseOa.statusMismatchHint), findsOneWidget);
    // 仅展示 host，不展示 query/token。
    expect(
      find.text(t.enterpriseOa.statusMismatchBlockedHost(host: 'evil.com')),
      findsOneWidget,
    );
    expect(find.textContaining('SHOULD_NOT_SHOW'), findsNothing);
    expect(find.textContaining('evil.com/phish'), findsNothing);
  });

  testWidgets('oa401 态：提示重新单点登录', (tester) async {
    await tester.pumpWidget(host(buildAt(OaTabStatus.oaUnauthorized)));
    await tester.pumpAndSettle();

    expect(find.text(t.enterpriseOa.statusOa401Title), findsOneWidget);
    expect(find.text(t.enterpriseOa.statusOa401Hint), findsOneWidget);
    expect(find.text(t.enterpriseOa.actionRestartSso), findsOneWidget);
  });

  testWidgets('页面标题为 OA', (tester) async {
    await tester.pumpWidget(host(buildAt(OaTabStatus.loading)));
    await tester.pump();
    expect(find.text(t.enterpriseOa.title), findsOneWidget);
  });
}
