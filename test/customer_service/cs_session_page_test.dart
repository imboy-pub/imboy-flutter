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
import 'dart:ui' show ViewFocusEvent, ViewFocusState, ViewFocusDirection;

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
import 'package:imboy/config/const.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

// Synthetic unsigned fixture assembled in memory, never an issued credential.
String _syntheticToken() {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final header = part({'alg': 'none'});
  final payload = part({'exp': 4102444800});
  final signature = base64Url
      .encode(utf8.encode('synthetic'))
      .replaceAll('=', '');
  return '$header.$payload.$signature';
}

const sessionId = '7266418340025468940';

/// 按注册顺序返回响应的桩（fragment 首个命中；响应按序消费，耗尽停留
/// 最后一个；未命中 → 200 空 envelope）。[rawRoutes] 命中时返回原始字节
/// （附件 content 代理是对象字节本体，非 JSON envelope）。
class _SeqAdapter implements HttpClientAdapter {
  final List<(String fragment, List<(int, Map<String, dynamic>)>)> routes;
  final List<(String fragment, Uint8List bytes)> rawRoutes;
  final Map<String, int> _cursor = {};
  int requestCount = 0;
  final requests = <RequestOptions>[];
  Future<ResponseBody>? heldSend;
  int? cursorWriteStatus;

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
    requests.add(options);
    if (options.method == 'POST' &&
        options.path.endsWith('/read-cursor') &&
        cursorWriteStatus != null) {
      return ResponseBody.fromString(
        jsonEncode({'code': 403, 'msg': 'synthetic refused'}),
        cursorWriteStatus!,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.method == 'POST' &&
        options.path.endsWith('/messages') &&
        heldSend != null) {
      return heldSend!;
    }
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

Future<void> _pumpPage(
  WidgetTester tester,
  _SeqAdapter adapter, {
  CsSessionPage? page,
}) async {
  HttpClient.adapterForTest = adapter;
  addTearDown(() => HttpClient.adapterForTest = null);
  await tester.pumpWidget(
    // 对齐 run.dart：TranslationProvider 挂在 MaterialApp.builder 内
    //（InheritedWidget 需在导航子树内），AppLoading host 挂 EasyLoading。
    MaterialApp(
      builder: (context, child) =>
          TranslationProvider(child: AppLoading.init()(context, child)),
      home:
          page ??
          const CsSessionPage(
            orgId: '7266418340025468901',
            sessionId: sessionId,
            conversationId: '7266418340025468950',
            identityId: '7266418340025468902',
            contactName: '张三',
            workspaceId: '7266418340025468921',
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

_SeqAdapter _previewAdapter(String change) {
  final previewHistory = {
    'code': 0,
    'payload': [
      {
        ...((_historyOk['payload'] as List).first as Map<String, dynamic>),
        'assets': [
          {
            'id': '7266418340025468971',
            'mime': 'text/plain',
            'file_name': 'owned.txt',
            'status': 'active',
          },
        ],
      },
    ],
  };
  final readState = {
    'code': 0,
    'payload': {
      'session_id': sessionId,
      'last_read_message_id': '1',
      'unread_count': 1,
    },
  };
  return _SeqAdapter(
    [
      ('/read-cursor', [(200, readState)]),
      ('/messages', [(200, previewHistory)]),
      (
        '/sessions/$sessionId',
        [
          (200, _detailOk),
          if (change == 'revoke')
            (403, {'code': 403, 'msg': 'synthetic revoked'}),
        ],
      ),
    ],
    rawRoutes: [
      (
        '/assets/7266418340025468971/content',
        Uint8List.fromList(utf8.encode('SYNTHETIC_OWNED_PREVIEW')),
      ),
    ],
  );
}

void main() {
  test('initial host focus is single-view only; explicit events dominate', () {
    bool focus(bool? event, List<int> views, {bool resumed = true}) =>
        csHostViewFocused(
          eventFocused: event,
          currentViewId: 1,
          viewIds: views,
          resumed: resumed,
        );
    expect(focus(null, [1]), isTrue);
    expect(focus(null, [1, 2]), isFalse);
    expect(focus(null, [2]), isFalse);
    expect(focus(null, [1], resumed: false), isFalse);
    expect(focus(false, [1]), isFalse);
    expect(focus(true, [1, 2]), isTrue);
  });
  testWidgets('single-view initial reading ACKs without a focus event', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final adapter = _SeqAdapter([
      ('/messages', [(200, _historyOk)]),
      ('/sessions/$sessionId', [(200, _detailOk)]),
    ]);
    await _pumpPage(tester, adapter);
    expect(
      adapter.requests.any(
        (r) => r.method == 'POST' && r.path.endsWith('/read-cursor'),
      ),
      isTrue,
    );
  });

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // bootstrap 链路会读 flutter_secure_storage（平台通道）：无 mock 时
    // fakeAsync 下 MethodChannel 永不完成，页面 bootstrap 挂起。mock 为
    // 使用合成未过期 token 与下方合成 UID，保持真实会话代际守卫。
    const secureChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
          if (call.method == 'readAll') return <String, String>{};
          if (call.method == 'read' &&
              (call.arguments as Map)['key'] == 'secure_token') {
            return _syntheticToken();
          }
          return null;
        });
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, '7266418340025468999');
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
  testWidgets(
    'account logout notification withdraws previously displayed body',
    (tester) async {
      final adapter = _SeqAdapter([
        ('/sessions/$sessionId', [(200, _detailOk)]),
        ('/messages', [(200, _historyOk)]),
      ]);
      await _pumpPage(tester, adapter);
      expect(find.text('订单还没收到'), findsOneWidget);
      await tester.runAsync(() async {
        await StorageService.to.remove(Keys.currentUid);
        await UserRepoLocal.to.changeInfo({});
      });
      await tester.pump();
      expect(find.text('订单还没收到'), findsNothing);
    },
  );
  for (final status in ['active', 'closed', 'rated']) {
    testWidgets('host-focused $status reading ACKs without editing input', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final detail = {
        ..._detailOk,
        'payload': {..._detailOk['payload'] as Map, 'status': status},
      };
      final adapter = _SeqAdapter([
        ('/messages', [(200, _historyOk)]),
        ('/sessions/$sessionId', [(200, detail)]),
      ]);
      await _pumpPage(tester, adapter);
      Iterable<RequestOptions> writes() => adapter.requests.where(
        (r) => r.path.endsWith('/read-cursor') && r.method == 'POST',
      );
      expect(writes(), isEmpty);
      tester.binding.handleViewFocusChanged(
        ViewFocusEvent(
          viewId: tester.view.viewId,
          state: ViewFocusState.focused,
          direction: ViewFocusDirection.undefined,
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settleRealAsync(tester);
      expect(writes().length, 1);
    });
  }
  testWidgets('host unfocus and covered route prevent visible ACK', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    final adapter = _SeqAdapter([
      ('/messages', [(200, _historyOk)]),
      ('/sessions/$sessionId', [(200, _detailOk)]),
    ]);
    await _pumpPage(tester, adapter);
    final page = tester.element(find.byType(CsSessionPage));
    tester.binding.handleViewFocusChanged(
      ViewFocusEvent(
        viewId: tester.view.viewId,
        state: ViewFocusState.unfocused,
        direction: ViewFocusDirection.undefined,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settleRealAsync(tester);
    bool noWrites() => !adapter.requests.any(
      (r) => r.path.endsWith('/read-cursor') && r.method == 'POST',
    );
    expect(noWrites(), isTrue);
    tester.binding.handleViewFocusChanged(
      ViewFocusEvent(
        viewId: tester.view.viewId + 1,
        state: ViewFocusState.focused,
        direction: ViewFocusDirection.undefined,
      ),
    );
    await _settleRealAsync(tester);
    expect(noWrites(), isTrue);
    unawaited(
      showDialog<void>(
        context: page,
        builder: (_) => const AlertDialog(content: Text('covered route')),
      ),
    );
    await tester.pumpAndSettle();
    tester.binding.handleViewFocusChanged(
      ViewFocusEvent(
        viewId: tester.view.viewId,
        state: ViewFocusState.focused,
        direction: ViewFocusDirection.undefined,
      ),
    );
    await _settleRealAsync(tester);
    expect(noWrites(), isTrue);
  });
  testWidgets('late send from route A cannot clear route B input', (
    tester,
  ) async {
    const otherSession = '7266418340025468942';
    const otherConversation = '7266418340025468952';
    final otherDetail = {
      ..._detailOk,
      'payload': {
        ...(_detailOk['payload'] as Map<String, dynamic>),
        'session_id': otherSession,
        'conversation_id': otherConversation,
      },
    };
    final adapter = _SeqAdapter([
      ('/sessions/$otherSession', [(200, otherDetail)]),
      (
        '/conversations/$otherConversation/messages',
        [
          (200, {'code': 0, 'payload': <Map<String, dynamic>>[]}),
        ],
      ),
      ('/sessions/$sessionId', [(200, _detailOk)]),
      ('/messages', [(200, _historyOk)]),
    ]);
    final response = Completer<ResponseBody>();
    adapter.heldSend = response.future;
    await _pumpPage(tester, adapter);
    await tester.enterText(find.byType(TextField).first, 'A text');
    await tester.tap(find.byIcon(CupertinoIcons.paperplane_fill));
    await _settleRealAsync(tester);
    await _pumpPage(
      tester,
      adapter,
      page: const CsSessionPage(
        orgId: '7266418340025468901',
        sessionId: otherSession,
        conversationId: otherConversation,
        identityId: '7266418340025468902',
        workspaceId: '7266418340025468921',
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'B draft');
    response.complete(
      ResponseBody.fromString(
        jsonEncode({
          'code': 0,
          'payload': {
            'id': '7266418340025468962',
            'conversation_id': '7266418340025468950',
            'organization_id': '7266418340025468901',
            'sender_type': 'business_identity',
            'body': 'A text',
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    await _settleRealAsync(tester);
    expect(_inputField(tester).controller!.text, 'B draft');
    expect(find.text('A text'), findsNothing);
  });
  testWidgets(
    'viewport ACK 403 immediately withdraws rendered body without SSE',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      final adapter = _SeqAdapter([
        ('/messages', [(200, _historyOk)]),
        ('/sessions/$sessionId', [(200, _detailOk)]),
      ]);
      adapter.cursorWriteStatus = 403;
      await _pumpPage(tester, adapter);
      expect(find.text('订单还没收到'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settleRealAsync(tester);
      expect(
        adapter.requests.any(
          (r) => r.method == 'POST' && r.path.endsWith('/read-cursor'),
        ),
        isTrue,
      );
      expect(find.text('订单还没收到'), findsNothing);
    },
  );
  for (final change in ['logout', 'route', 'revoke', 'unmount']) {
    testWidgets('owned preview is withdrawn on $change', (tester) async {
      final adapter = _previewAdapter(change);
      await _pumpPage(tester, adapter);
      await tester.tap(find.text('owned.txt'));
      await _settleRealAsync(tester);
      expect(find.text('SYNTHETIC_OWNED_PREVIEW'), findsOneWidget);
      if (change == 'logout') {
        await tester.runAsync(() async {
          await StorageService.to.remove(Keys.currentUid);
          await UserRepoLocal.to.changeInfo({});
        });
      } else if (change == 'route') {
        await _pumpPage(
          tester,
          adapter,
          page: const CsSessionPage(
            orgId: '7266418340025468901',
            sessionId: '7266418340025468942',
            conversationId: '7266418340025468952',
            workspaceId: '7266418340025468921',
            identityId: '7266418340025468902',
          ),
        );
      } else if (change == 'revoke') {
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await _settleRealAsync(tester);
      } else {
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      }
      await tester.pump();
      await tester.pump();
      expect(find.text('SYNTHETIC_OWNED_PREVIEW'), findsNothing);
    });
  }

  testWidgets('route scope change isolates unsent input immediately', (
    tester,
  ) async {
    final adapter = _SeqAdapter([
      ('/messages', [(200, _historyOk)]),
      ('/sessions/$sessionId', [(200, _detailOk)]),
    ]);
    await _pumpPage(tester, adapter);
    await tester.enterText(find.byType(TextField).first, 'A unsent draft');
    await _pumpPage(
      tester,
      adapter,
      page: const CsSessionPage(
        orgId: '7266418340025468901',
        sessionId: '7266418340025468942',
        conversationId: '7266418340025468952',
        workspaceId: '7266418340025468921',
        identityId: '7266418340025468902',
      ),
    );
    expect(_inputField(tester).controller!.text, isEmpty);
  });
}
