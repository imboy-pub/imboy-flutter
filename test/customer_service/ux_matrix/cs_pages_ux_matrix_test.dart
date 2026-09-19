/// RUN: three-plan-integration-20260918T124045Z-6af21b0d | Card: R-UXAPP-01
///
/// Customer Service 2 个代表页面的 UI/UX 力学矩阵测试：
///
/// 1. CsQueueView（排队队列，单独 pump 于 Scaffold 内）
/// 2. CsWorkspacePage（坐席工作台：TabBar 待接/处理中/已关闭 + 队列页）
///
/// 每页矩阵（单 testWidgets 内合并多泵）：
/// - viewport sweep：320x568 / 390x844 / 430x932 @1.0 light
///   → takeException isNull + 主内容在可滚动结构内；
/// - textScale sweep：390x844 @1.3 / @2.0 light → takeException isNull；
/// - dark：390x844 @1.0 dark → takeException isNull + 关键文本仍可见；
/// - semantics：主操作「接单」按钮 / Tab 文本存在（机械 find）。
/// - danger confirm：两页无删除/退出/关闭类动作 → N/A（会话关闭确认
///   入口在 CsSessionPage 深层，已由 test/customer_service/cs_session_page_test.dart
///   覆盖 close 确认链路，不重复）。
///
/// i18n：CS 页面走 slang `context.t.customerService`，host 挂
/// TranslationProvider（zh 默认语言族）。harness 见 test/ux_matrix/。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/customer_service/presentation/cs_queue_view.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_page.dart';

import '../../ux_matrix/ux_harness.dart';

const String kOrgId = '7266418340025468901';

Map<String, dynamic> _queueItem(String id, String maskedName) => {
  'id': id,
  'contact_id': '7266418340025468941',
  'contact': {'masked_name': maskedName},
  'queued_at': '',
  'version': 3,
  'status': 'queued',
  'source': 'widget',
  'last_message': {'id': '7266418340025468961'},
  'organization_id': kOrgId,
  'conversation_id': '7266418340025468950',
};

Map<String, dynamic> _queuePayload() => uxEnvelope(
  payload: {
    'sessions': [
      _queueItem('7266418340025468951', '王**'),
      _queueItem('7266418340025468952', '李**'),
    ],
    'next_after_id': null,
    'total': 2,
    'total_by_status': {'queued': 2},
  },
);

/// queue 路由桩（queuePage 与可能的刷新共用同一响应，cursor 停留最后）。
RouteStubAdapter _queueStub() => RouteStubAdapter([
  ('/cs/sessions/queue', [(200, _queuePayload())]),
]);

/// matrix：viewport sweep + textScale sweep + dark，逐泵 takeException。
Future<void> _runMatrix(
  WidgetTester tester,
  Widget page,
  String pageLabel, {
  required Finder darkVisibleText,
}) async {
  for (final viewport in kUxViewportSweep) {
    final combo = UxCombo(viewport);
    await pumpUxCombo(tester, page, combo);
    final ex = tester.takeException();
    expect(
      ex,
      isNull,
      reason: 'viewport 破绽 @ ${uxComboLabel(pageLabel, combo)}: $ex',
    );
    if (viewport == kUxSmallViewport) {
      expect(
        uxHasScrollable(tester),
        isTrue,
        reason: '$pageLabel 主内容未落在可滚动结构内（320x568）',
      );
    }
  }

  for (final scale in const [1.3, 2.0]) {
    final combo = UxCombo(kUxMediumViewport, textScale: scale);
    await pumpUxCombo(tester, page, combo);
    final ex = tester.takeException();
    expect(
      ex,
      isNull,
      reason: 'textScale overflow @ ${uxComboLabel(pageLabel, combo)}: $ex',
    );
  }

  final darkCombo = UxCombo(kUxMediumViewport, brightness: Brightness.dark);
  await pumpUxCombo(tester, page, darkCombo);
  final ex = tester.takeException();
  expect(
    ex,
    isNull,
    reason: 'dark 布局破绽 @ ${uxComboLabel(pageLabel, darkCombo)}: $ex',
  );
  expect(
    darkVisibleText,
    findsOneWidget,
    reason: 'dark 模式关键文本不可见 @ ${uxComboLabel(pageLabel, darkCombo)}',
  );
}

void main() {
  setUp(() async {
    await initUxHarness();
  });

  tearDown(teardownUxHarness);

  testWidgets('CsQueueView：viewport/textScale/dark 矩阵（无 danger 入口 → N/A）', (
    tester,
  ) async {
    uxInstallStub(_queueStub());

    // CsQueueView 无自带 Scaffold：宿主提供，便于独立 pump。
    await _runMatrix(
      tester,
      const Scaffold(body: CsQueueView()),
      'cs_queue',
      darkVisibleText: find.text('王**'),
    );

    // semantics（机械 find）：主操作「接单」按钮每行存在且带 Text。
    expect(
      find.widgetWithText(FilledButton, '接单'),
      findsWidgets,
      reason: '每行主操作「接单」按钮可见',
    );
    // 排队等待标签（waitingSince 空 → 「刚刚」）随行展示。
    expect(find.text('刚刚'), findsWidgets);
  });

  testWidgets('CsWorkspacePage：矩阵 + TabBar 结构（无 danger 入口 → N/A）', (
    tester,
  ) async {
    uxInstallStub(_queueStub());

    await _runMatrix(
      tester,
      const CsWorkspacePage(),
      'cs_workspace',
      darkVisibleText: find.text('客服工作台'),
    );

    // semantics（机械 find）：三个 Tab 文本 + 徽标计数来自服务端键（2）。
    expect(find.text('待接'), findsOneWidget);
    expect(find.text('处理中'), findsOneWidget);
    expect(find.text('已关闭'), findsOneWidget);
    expect(
      find.text('2'),
      findsWidgets,
      reason: '徽标计数只取服务端键 total_by_status.queued',
    );
    // 队列页为 TabBarView 当前页：接单按钮可达。
    expect(find.widgetWithText(FilledButton, '接单'), findsWidgets);
  });
}
