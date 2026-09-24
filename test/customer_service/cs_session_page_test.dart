/// CSM-03（§12.5.1 / A05）— 坐席会话页降级行为 widget 测试
///
/// 把上卡状态机的降级语义落成**可验收的页面行为**（真 pump
/// [CsSessionPage]，fake HTTP 桩）：
///
/// 1. 正常态：detail(active) + 历史 → 消息渲染、输入可用；
/// 2. 发送遇 403（suspend / seat disabled / assignment ended / removed
///    的统一表现）→ 页面出现 explainKey 对应只读条 + 输入禁用；
/// 3. 关闭成功 → 输入禁用 + 评分等待横幅（坐席端只展示评分状态）。
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/service/storage.dart';

const sessionId = '7266418340025468940';

/// 按注册顺序返回响应的桩（fragment 首个命中；响应按序消费，耗尽停留
/// 最后一个；未命中 → 200 空 envelope）。[rawRoutes] 命中时返回原始字节
/// （附件 content 代理是对象字节本体，非 JSON envelope）。
class _SeqAdapter implements HttpClientAdapter {
  final List<(String fragment, List<(int, Map<String, dynamic>)>)> routes;
  final List<(String fragment, Uint8List bytes)> rawRoutes;
  final Map<String, int> _cursor = {};
  int requestCount = 0;

  _SeqAdapter(this.routes, {this.rawRoutes = const []});

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

  Uint8List? _matchRaw(String path) {
    for (final (fragment, bytes) in rawRoutes) {
      if (path.contains(fragment)) return bytes;
    }
    return null;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    final raw = _matchRaw(options.uri.path);
    if (raw != null) {
      return ResponseBody.fromBytes(
        raw,
        200,
        headers: {
          Headers.contentTypeHeader: ['application/octet-stream'],
        },
      );
    }
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

final _detailOk = {
  'code': 0,
  'msg': 'success',
  'payload': {
    'session_id': sessionId,
    'organization_id': '7266418340025468901',
    'conversation_id': '7266418340025468950',
    'status': 'active',
    'version': 5,
    'business_identity_id': '7266418340025468902',
  },
};

final _historyOk = {
  'code': 0,
  'msg': 'success',
  'payload': [
    {
      'id': '7266418340025468961',
      'conversation_id': '7266418340025468950',
      'organization_id': '7266418340025468901',
      'sender_type': 'contact',
      'sender_contact_id': '7266418340025468941',
      'sender_business_identity_id': null,
      'body': '订单还没收到',
      'assets': <Map<String, dynamic>>[],
    },
  ],
};

/// 1x1 透明 PNG（图片缩略渲染的最小真实字节）。
final _tinyPng = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x62,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

Future<void> _pumpPage(WidgetTester tester, _SeqAdapter adapter) async {
  HttpClient.adapterForTest = adapter;
  addTearDown(() => HttpClient.adapterForTest = null);
  await tester.pumpWidget(
    // 对齐 run.dart：TranslationProvider 挂在 MaterialApp.builder 内
    //（InheritedWidget 需在导航子树内），AppLoading host 挂 EasyLoading。
    MaterialApp(
      builder: (context, child) =>
          TranslationProvider(child: AppLoading.init()(context, child)),
      home: const CsSessionPage(
        orgId: '7266418340025468901',
        sessionId: sessionId,
        conversationId: '7266418340025468950',
        identityId: '7266418340025468902',
        contactName: '张三',
      ),
    ),
  );
  await _settleRealAsync(tester);
}

/// bootstrap 里 token/ dio 链路含真实异步（fakeAsync pump 推不动），
/// 用 runAsync 放行真实时间，再 pump 反映状态。
Future<void> _settleRealAsync(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

TextField _inputField(WidgetTester tester) =>
    tester.widgetList<TextField>(find.byType(TextField)).first;

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // bootstrap 链路会读 flutter_secure_storage（平台通道）：无 mock 时
    // fakeAsync 下 MethodChannel 永不完成，页面 bootstrap 挂起。mock 为
    // 「无 token」即可（未登录读路径直通）。
    const secureChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
          if (call.method == 'readAll') return <String, String>{};
          return null;
        });
    await StorageService.init();
  });

  testWidgets('正常态：detail + 历史 → 消息渲染、输入可用', (tester) async {
    final adapter = _SeqAdapter([
      ('/sessions/$sessionId', [(200, _detailOk)]),
      ('/conversations/7266418340025468950/messages', [(200, _historyOk)]),
    ]);

    await _pumpPage(tester, adapter);

    expect(find.text('订单还没收到'), findsOneWidget);
    expect(find.text('张**'), findsWidgets, reason: '客户掩码名');
    expect(_inputField(tester).enabled, isTrue, reason: '可写态输入可用');
    // 无只读条
    expect(find.textContaining('只读'), findsNothing);
  });

  testWidgets('发送遇 403 → explainKey 只读条 + 输入禁用（清写入口）', (tester) async {
    final adapter = _SeqAdapter([
      ('/sessions/$sessionId', [(200, _detailOk)]),
      // 同片段按序消费：第 1 次 = bootstrap GET（历史）；第 2 次 = send
      // POST 被 suspend 拒绝（seat disabled / member suspended /
      // assignment ended / removed 的统一 HTTP 表现）
      (
        '/conversations/7266418340025468950/messages',
        [
          (200, _historyOk),
          (403, {'code': 403, 'msg': 'forbidden'}),
        ],
      ),
    ]);

    await _pumpPage(tester, adapter);
    final before = adapter.requestCount;

    await tester.enterText(find.byType(TextField), '还想回复');
    await tester.tap(find.byIcon(CupertinoIcons.paperplane_fill));
    await _settleRealAsync(tester);

    expect(
      find.textContaining('坐席已被暂停（suspend）'),
      findsOneWidget,
      reason: 'readOnlySuspended explain 条出现',
    );
    expect(
      find.textContaining('只读'),
      findsWidgets,
      reason: 'explainKey 对应只读态文案',
    );
    expect(_inputField(tester).enabled, isFalse, reason: '输入禁用（清写入口）');
    // 降级后页面不再发任何请求（停止后台收发）
    final afterIdle = adapter.requestCount;
    await _settleRealAsync(tester);
    expect(adapter.requestCount, afterIdle);
    expect(
      afterIdle - before,
      lessThanOrEqualTo(2),
      reason: '仅 send+可能的刷新，无轮询风暴',
    );
  });

  testWidgets('关闭成功 → 输入禁用 + 评分等待横幅（不代访客评分）', (tester) async {
    final adapter = _SeqAdapter([
      ('/sessions/$sessionId', [(200, _detailOk)]),
      ('/conversations/7266418340025468950/messages', [(200, _historyOk)]),
      (
        '/close',
        [
          (200, {'code': 0, 'msg': 'success', 'payload': null}),
        ],
      ),
    ]);

    await _pumpPage(tester, adapter);

    // AppBar close 动作 → 确认弹层 → 关闭
    await tester.tap(find.byIcon(CupertinoIcons.xmark_circle));
    await _settleRealAsync(tester);
    await tester.tap(find.widgetWithText(FilledButton, '关闭会话').last);
    await _settleRealAsync(tester);

    expect(
      find.textContaining('等待客户评分'),
      findsOneWidget,
      reason: '关闭后进入评分等待状态展示',
    );
    expect(_inputField(tester).enabled, isFalse, reason: '关闭后输入禁用');
    // 坐席端不代评：页面不出现任何「提交评分」入口
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.textContaining('提交评分'), findsNothing);
  });

  testWidgets('APP-M02-A04：服务端回显经办人非当前坐席 → 转接只读横幅 + 输入禁用', (tester) async {
    final transferredDetail = {
      'code': 0,
      'msg': 'success',
      'payload': {
        'session_id': sessionId,
        'organization_id': '7266418340025468901',
        'conversation_id': '7266418340025468950',
        'status': 'active',
        'version': 9,
        'business_identity_id': '7266418340025468999',
      },
    };
    final adapter = _SeqAdapter([
      ('/sessions/$sessionId', [(200, transferredDetail)]),
      ('/conversations/7266418340025468950/messages', [(200, _historyOk)]),
    ]);

    await _pumpPage(tester, adapter);

    expect(
      find.textContaining('已转交'),
      findsOneWidget,
      reason: 'transferredAway 可解释只读横幅出现',
    );
    expect(_inputField(tester).enabled, isFalse, reason: '转接后旧坐席立即只读');
    // 写入口全禁：转接/关闭动作入口不可见（canWrite=false 隐藏），
    // 附件入口在场但禁用（onPressed=null）。
    expect(find.byIcon(CupertinoIcons.arrow_2_squarepath), findsNothing);
    expect(find.byIcon(CupertinoIcons.xmark_circle), findsNothing);
    final attachButton = tester
        .widgetList<IconButton>(
          find.ancestor(
            of: find.byIcon(CupertinoIcons.paperclip),
            matching: find.byType(IconButton),
          ),
        )
        .first;
    expect(attachButton.onPressed, isNull, reason: '附件写入口禁用');
  });

  testWidgets('CSX-01：历史附件投影分型渲染（图片缩略 + 文件行）', (tester) async {
    final historyWithAssets = {
      'code': 0,
      'msg': 'success',
      'payload': [
        {
          'id': '7266418340025468962',
          'conversation_id': '7266418340025468950',
          'organization_id': '7266418340025468901',
          'sender_type': 'contact',
          'sender_contact_id': '7266418340025468941',
          'sender_business_identity_id': null,
          'body': '',
          'assets': [
            {
              'id': '7266418340025468970',
              'mime': 'image/png',
              'size_bytes': 4096,
              'file_name': '订单截图.png',
              'status': 'active',
            },
            {
              'id': '7266418340025468971',
              'mime': 'application/pdf',
              'size_bytes': 1048576,
              'file_name': '合同.pdf',
              'status': 'active',
            },
          ],
        },
      ],
    };
    final adapter = _SeqAdapter(
      [
        ('/sessions/$sessionId', [(200, _detailOk)]),
        (
          '/conversations/7266418340025468950/messages',
          [(200, historyWithAssets)],
        ),
      ],
      // 授权 content 代理：图片资产返回真实 PNG 字节（渲染面禁止裸 URL，
      // 只有字节入口）。
      rawRoutes: [('assets/7266418340025468970/content', _tinyPng)],
    );

    await _pumpPage(tester, adapter);

    // 文件行：文件名 + 人类可读大小（AppSpacing/token 化最小 renderer）。
    expect(find.text('合同.pdf'), findsOneWidget);
    expect(find.text('1.0MB'), findsOneWidget);
    // 图片缩略：经授权字节 + Image.memory 渲染（真实 PNG 解码成功）。
    expect(find.byType(Image), findsOneWidget);
  });
}
