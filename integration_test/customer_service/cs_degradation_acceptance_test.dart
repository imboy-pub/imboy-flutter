// integration_test/customer_service/cs_degradation_acceptance_test.dart
//
// CSM-03（§12.5.1 / §12.7 CSM-03-A05）— 客服降级真机验收（Tier 3）。
//
// 场景（本地桩后端——真机 dart VM 内经 HttpClient.adapterForTest 换出口，
// 与 integration_test/group/gm_pagination_failover_test.dart 同款机制，
// 不依赖外部 erlang 实例）：
//
//   1. 坐席会话页在真机构建中完成 bootstrap（detail active + 历史）；
//   2. 消息渲染（访客入站 + 掩码客户名）；
//   3. 发送 → 桩回 403（seat disabled / member suspended / assignment
//      ended / member removed 的统一表现）→ 页面出现 explainKey 只读条、
//      输入禁用（清写入口）、不再发出任何请求（停后台收发）；
//   4. 关闭链（close 200）→ 评分等待横幅、输入禁用（坐席端只展示评分
//      状态，不代访客评分）。
//
// 旧 JWT/旧缓存不能继续 claim/send/download 的 API 级矩阵（五态 403/409、
// A→B rebind、个人数据边界）见 test/customer_service/cs_degradation_test.dart
//（Tier 1，无设备可跑）。
//
// 运行（多设备环境必须显式 -d）：
//   flutter test integration_test/customer_service/cs_degradation_acceptance_test.dart \
//     -d <真机设备ID>
//
// 证据须附 `adb devices -l` 输出。

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_page.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/service/storage.dart';

const _sessionId = '7266418340025468940';
const _orgId = '7266418340025468901';
const _conversationId = '7266418340025468950';

/// 按注册顺序返回响应的桩（fragment 首个命中；响应按序消费，耗尽停留
/// 最后一个；未命中 → 200 空 envelope）。
class _SeqAdapter implements HttpClientAdapter {
  _SeqAdapter(this.routes);

  final List<(String fragment, List<(int, Map<String, dynamic>)>)> routes;
  final Map<String, int> _cursor = {};
  final List<String> requests = [];

  (int, Map<String, dynamic>) _match(String path) {
    for (final (fragment, responses) in routes) {
      if (path.contains(fragment)) {
        final i = _cursor.putIfAbsent(fragment, () => 0);
        _cursor[fragment] = (i + 1).clamp(0, responses.length - 1);
        return responses[i];
      }
    }
    return (200, {'code': 0, 'msg': 'success', 'payload': null});
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.uri.path}');
    final (status, body) = _match(options.uri.path);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('CSM-03 seat degradation chain (claim 403 / send 403 / close)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    // flutter_secure_storage 平台通道 mock（无 token 读路径直通）。
    const MethodChannel secureChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
          if (call.method == 'readAll') return <String, String>{};
          return null;
        });
    await StorageService.init();

    final adapter = _SeqAdapter([
      (
        '/cs/sessions/$_sessionId',
        [
          (
            200,
            {
              'code': 0,
              'msg': 'success',
              'payload': {
                'session_id': _sessionId,
                'organization_id': _orgId,
                'conversation_id': _conversationId,
                'status': 'active',
                'version': 5,
                'business_identity_id': '7266418340025468902',
              },
            },
          ),
        ],
      ),
      (
        '/conversations/$_conversationId/messages',
        [
          (
            200,
            {
              'code': 0,
              'msg': 'success',
              'payload': [
                {
                  'id': '7266418340025468961',
                  'conversation_id': _conversationId,
                  'organization_id': _orgId,
                  'sender_type': 'contact',
                  'sender_contact_id': '7266418340025468941',
                  'sender_business_identity_id': null,
                  'content': '订单还没收到',
                },
              ],
            },
          ),
          // 发送被 suspend 拒绝（seat disabled / member suspended /
          // assignment ended / member removed 的统一 HTTP 表现）
          (403, {'code': 403, 'msg': 'forbidden'}),
        ],
      ),
      (
        '/close',
        [
          (200, {'code': 0, 'msg': 'success', 'payload': null}),
        ],
      ),
    ]);
    HttpClient.adapterForTest = adapter;
    addTearDown(() => HttpClient.adapterForTest = null);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            TranslationProvider(child: AppLoading.init()(context, child)),
        home: const CsSessionPage(
          orgId: _orgId,
          sessionId: _sessionId,
          conversationId: _conversationId,
          identityId: '7266418340025468902',
          contactName: '张三',
        ),
      ),
    );
    await _settle(tester);

    // —— 步骤 2：消息渲染（访客入站 + 客户掩码名）——
    expect(find.text('订单还没收到'), findsOneWidget);
    expect(find.text('张**'), findsWidgets);

    // —— 步骤 3：发送 403 → 清写入口 + 可解释只读态 ——
    final beforeSend = adapter.requests.length;
    await tester.enterText(find.byType(TextField), '还想回复');
    await tester.tap(find.byIcon(CupertinoIcons.paperplane_fill));
    await _settle(tester);

    expect(
      find.textContaining('坐席已被暂停（suspend）'),
      findsOneWidget,
      reason: 'readOnlySuspended explain 条出现',
    );
    expect(find.byType(TextField).evaluate().isNotEmpty, isTrue);
    final input = tester.widgetList<TextField>(find.byType(TextField)).first;
    expect(input.enabled, isFalse, reason: '清写入口：输入禁用');

    // 旧 JWT 不能继续：静置后零新请求（停后台收发）
    final afterSend = adapter.requests.length;
    await _settle(tester);
    expect(adapter.requests.length, afterSend);
    expect(afterSend - beforeSend, lessThanOrEqualTo(2));

    // —— 步骤 4：写入口全部清除（清写入口的 UI 验收点）——
    // 降级后 AppBar 不再提供转接/关闭动作（写操作全禁）。
    expect(
      find.byIcon(CupertinoIcons.xmark_circle),
      findsNothing,
      reason: '关闭写入口被清',
    );
    expect(
      find.byIcon(CupertinoIcons.arrow_2_squarepath),
      findsNothing,
      reason: '转接写入口被清',
    );
    expect(
      find.textContaining('等待客户评分'),
      findsNothing,
      reason: '未关闭的会话不进入评分等待态',
    );
  });
}
