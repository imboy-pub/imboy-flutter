/// RUN: three-plan-integration-20260918T124045Z-6af21b0d | Card: R-UXAPP-01
/// RUN: customer-service-web-csww-20260920T051447Z | Card: APP-M01（org 作用域 + 组织选择器改造）
/// RUN: customer-service-web-csww-20260920T051447Z | Card: APP-M02（矩阵扩展到坐席会话页）
///
/// Customer Service 代表页面的 UI/UX 力学矩阵测试：
///
/// 1. CsQueueView（待接队列，单独 pump 于 Scaffold 内；org 作用域）
/// 2. CsWorkspacePage（坐席工作台：seat-contexts 驱动组织选择器 +
///    TabBar 待接/处理中/已关闭 + FittedBox Tab 修复）
/// 3. CsSessionPage（坐席会话页：消息气泡 + 输入行 + 评分/只读横幅；
///    APP-M02 扩展）
///
/// 每页矩阵（单 testWidgets 内合并多泵）：
/// - viewport sweep：320x568 / 390x844 / 430x932 @1.0 light
///   → takeException isNull + 主内容在可滚动结构内；
/// - textScale sweep：390x844 @1.3 / @2.0 light → takeException isNull；
/// - dark：390x844 @1.0 dark → takeException isNull + 关键文本仍可见；
/// - semantics：主操作「接单」按钮 / Tab 文本 / 组织选择器存在（机械 find）。
/// - danger confirm：会话关闭确认链路由
///   test/customer_service/cs_session_page_test.dart 覆盖，此处不重复。
///
/// i18n：CS 页面走 slang `context.t.customerService`，host 挂
/// TranslationProvider（zh 默认语言族）。harness 见 test/ux_matrix/。
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/modules/customer_service/presentation/cs_queue_view.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_page.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_page.dart';
import 'package:imboy/service/storage.dart';

import '../../ux_matrix/ux_harness.dart';

const String kOrgId = '7266418340025468901';
const String kOrgName = '示例组织';
const String kSessionId = '7266418340025468940';
const String kConversationId = '7266418340025468950';
const String kIdentityId = '7266418340025468902';
const String kWorkspaceId = '7266418340025468951';

Future<void> _installSessionIdentity() async {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  // Unsigned runtime fixture; never an issued credential.
  final token = [
    part({'alg': 'none'}),
    part({'exp': 4102444800}),
    base64Url.encode(utf8.encode('synthetic-cs-ux')).replaceAll('=', ''),
  ].join('.');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async {
          if (call.method == 'readAll') return <String, String>{};
          if (call.method == 'read' &&
              (call.arguments as Map)['key'] == 'secure_token') {
            return token;
          }
          return null;
        },
      );
  await StorageService.to.setString(Keys.currentUid, '7266418340025468999');
}

/// 会话页桩（APP-M02）：detail（权威 active）+ 历史（入站/出站各一）。
/// SSE 端点未桩（未命中 → 200 空 payload）：事件流解析空帧后按 retry
/// 退避，矩阵各拍 < 2s 重连间隔，不产生额外请求。
RouteStubAdapter _sessionStub() => RouteStubAdapter([
  (
    '/sessions/$kSessionId',
    [
      (
        200,
        uxEnvelope(
          payload: {
            'session_id': kSessionId,
            'organization_id': kOrgId,
            'conversation_id': kConversationId,
            'status': 'active',
            'version': 5,
            'business_identity_id': kIdentityId,
          },
        ),
      ),
    ],
  ),
  (
    '/conversations/$kConversationId/messages',
    [
      (
        200,
        uxEnvelope(
          payload: [
            {
              'id': '7266418340025468961',
              'conversation_id': kConversationId,
              'organization_id': kOrgId,
              'sender_type': 'contact',
              'sender_contact_id': '7266418340025468941',
              'sender_business_identity_id': null,
              'content': '订单还没收到',
              'delivered': true,
            },
            {
              'id': '7266418340025468962',
              'conversation_id': kConversationId,
              'organization_id': kOrgId,
              'sender_type': 'business_identity',
              'sender_contact_id': null,
              'sender_business_identity_id': kIdentityId,
              'sender_business_identity_name': '客服小易',
              'content': '您好，正在为您加急核实',
              'delivered': true,
            },
          ].reversed.toList(),
        ),
      ),
    ],
  ),
]);

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
  'business_identity_id': '7266418340025468902',
};

Map<String, dynamic> _contextsPayload() => uxEnvelope(
  payload: {
    'contexts': [
      {
        'organization_id': kOrgId,
        'organization_name': kOrgName,
        'workspaces': [
          {'id': '7266418340025468921', 'name': '默认工作区'},
        ],
        'business_identity_id': '7266418340025468902',
        'seat_enabled': true,
        'capabilities': ['conversation.read', 'conversation.write'],
      },
    ],
    'user_id': '7266418340025468800',
  },
);

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

/// active/closed 空页（工作台 Tab 懒加载即取数；空 payload 宽容解析）。
Map<String, dynamic> _seatSessionsPayload() => uxEnvelope(
  payload: {
    'sessions': <Map<String, dynamic>>[],
    'next_after_id': null,
    'total': 0,
    'total_by_status': <String, dynamic>{},
  },
);

/// org 作用域桩（T-2 权威路径）：seat-contexts + queue + seats/sessions。
/// 记录请求 path（机械钉 org 作用域，不触共享 harness）。
class _RecordingCsStub extends RouteStubAdapter {
  _RecordingCsStub(super.routes);

  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    return super.fetch(options, requestStream, cancelFuture);
  }
}

_RecordingCsStub _csStub() => _RecordingCsStub([
  ('/seat-contexts', [(200, _contextsPayload())]),
  ('/sessions/queue', [(200, _queuePayload())]),
  ('/seats/sessions', [(200, _seatSessionsPayload())]),
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
    uxInstallStub(_csStub());

    // CsQueueView 无自带 Scaffold：宿主提供，便于独立 pump。
    await _runMatrix(
      tester,
      const Scaffold(body: CsQueueView(orgId: kOrgId)),
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

  testWidgets('CsWorkspacePage：组织选择器 + 矩阵 + TabBar 结构（无 danger 入口 → N/A）', (
    tester,
  ) async {
    final stub = _csStub();
    uxInstallStub(stub);

    await _runMatrix(
      tester,
      const CsWorkspacePage(),
      'cs_workspace',
      darkVisibleText: find.text(kOrgName),
    );

    // APP-M01-A01（机械 find）：组织选择器由 seat-contexts 列表驱动。
    expect(
      find.text(kOrgName),
      findsWidgets,
      reason: '组织选择器显示 seat-contexts 返回的组织名',
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

    // org 作用域机械钉：请求命中 T-2 权威路径（org 显式在路径）。
    expect(
      stub.paths.contains('/api/v1/cs/me/seat-contexts'),
      isTrue,
      reason: '工作台上下文来自 seat-contexts（主体作用域端点）',
    );
    expect(
      stub.paths.contains('/api/v1/cs/organizations/$kOrgId/sessions/queue'),
      isTrue,
      reason: '队列取数走 org 作用域路径',
    );
  });

  testWidgets('CsSessionPage：消息气泡 + 输入行矩阵（APP-M02 扩展；无 danger 入口 → N/A）', (
    tester,
  ) async {
    await _installSessionIdentity();
    uxInstallStub(_sessionStub());

    await _runMatrix(
      tester,
      const CsSessionPage(
        orgId: kOrgId,
        sessionId: kSessionId,
        conversationId: kConversationId,
        identityId: kIdentityId,
        workspaceId: kWorkspaceId,
        contactName: '张三',
      ),
      'cs_session',
      darkVisibleText: find.text('订单还没收到'),
    );

    // semantics（机械 find）：入站气泡（客户在左）与掩码名可见。
    expect(find.text('订单还没收到'), findsOneWidget);
    expect(find.textContaining('张**'), findsWidgets);
  });
}
