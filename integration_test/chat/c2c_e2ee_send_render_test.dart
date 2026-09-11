// strict E2EE 加密 C2C 全链发送验证（真后端 + 真 WS + 真 UI）：
//
// 与 e2ee_c2c_outbound_frame_test 的区别：那份是离线白盒（预置 Olm 会话、
// 不连后端、不进 UI），只验证帧格式；本测试走生产全链——
//   ① 白盒 ChatNetworkService.sendMessage：真策略门（strict）→ 真设备密钥
//      bootstrap → 拉对端设备密钥建 OLM 出站会话 → 真 WS 提交；
//   ② 本地后端路由落库后，对端账号经 /api/v1/msg/history 拉取，
//      断言 payload 无明文且 e2ee 信封存在（密文落库语义）；
//   ③ UI：push 真实 ChatPage，经 chatProvider.addMessage 发第二条，
//      断言气泡本地回显渲染，且对端历史同样可见（发送链 UI 入口）。
//
// 数据自造：不依赖环境存量会话；对端消息均为本测试产生。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xid/xid.dart';

import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../flows/api_test_client.dart';
import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('strict 模式加密 C2C 全链：白盒发送→对端拉密文→ChatPage 回显', (tester) async {
    installPluginErrorFilter();
    await ensureAppLaunched(tester, maxSeconds: 10);
    if (!await checkPreconditions(tester)) return;
    await settle(tester, maxSeconds: 2);

    // 1. 等加密策略就绪：非 strict 部署下本测试无意义
    var policyReady = false;
    for (var i = 0; i < 10 && !policyReady; i++) {
      policyReady = EncryptionModeService.isInitialized;
      if (!policyReady) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    if (!policyReady) {
      markTestSkipped('加密策略未就绪（EncryptionModeService 未初始化）');
      return;
    }
    if (EncryptionModeService.current != EncryptionMode.strictE2ee) {
      markTestSkipped(
        '当前部署非 strict E2EE（current=${EncryptionModeService.current}），'
        '本测试只验证 strict 语义',
      );
      return;
    }

    // 2. 对端账号登录（明文契约：新格式 hmac_sha512 账号）
    final base = FlowApiConfig.apiBaseUrl.isNotEmpty
        ? FlowApiConfig.apiBaseUrl
        : 'http://127.0.0.1:9800';
    final peer = FlowApiClient(baseUrl: base, deviceId: 'c2csend-peer');
    final loginRes = await peer.login(
      account: const String.fromEnvironment(
        'C2C_PEER_ACCOUNT',
        defaultValue: 'at20260830210132b@at.local',
      ),
      password: 'admin888',
      type: 'email',
      plainPassword: true,
    );
    if (loginRes['code'] != 0) {
      markTestSkipped('对端账号登录失败: ${loginRes['msg']}，跳过');
      return;
    }
    final peerUid = peer.currentUid ?? '';
    final selfUid = UserRepoLocal.to.currentUid;
    flowLog('对端登录成功 uid=$peerUid，本端 uid=$selfUid');
    if (peerUid.isEmpty || selfUid.isEmpty || peerUid == selfUid) {
      markTestSkipped('账号状态异常（uid 为空或两端同号），跳过');
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    // ===== 2.5 claim 授权门铺底：OTK claim 要求「双方好友或同群」
    //（imboy 778a18ca P1 安全修复），合成对端账号与本端默认无关，
    // 不铺底 claim 必被 claim_not_authorized 拒（且 OTP 零消耗，
    // 批次177 实证：报错形如 E2EE v2.0 加密失败 errType=_Exception）。
    // 客户端必须复用 App 主会话 token（channel_message_like 同款）：
    // 以本端账号独立 login 会触发「另一设备登录」互踢把 App 挤下线
    //（批次177 run3 实证：铺底后全链 401 设备已被移除）。
    // 重复运行时 add 的「已是好友」类报错可容忍。
    final selfApi = FlowApiClient(baseUrl: base, deviceId: 'c2csend-self');
    selfApi.accessToken = await UserRepoLocal.to.accessToken;
    if (selfApi.accessToken == null || selfApi.accessToken!.isEmpty) {
      markTestSkipped('无法取得 App 主会话 token，无法铺好友链');
      return;
    }
    final addRes = await selfApi.post(
      '/api/v1/friend/add',
      data: {
        'to': peerUid,
        'payload': <String, dynamic>{
          'from': <String, dynamic>{'source': 'search'},
        },
        'created_at': now,
      },
    );
    final confirmRes = await peer.post(
      '/api/v1/friend/confirm',
      data: {'from': selfUid, 'to': peerUid, 'payload': <String, dynamic>{}},
    );
    flowLog(
      '好友链铺底: add=${addRes['code']}(${addRes['msg']}) '
      'confirm=${confirmRes['code']}(${confirmRes['msg']})',
    );

    // ===== 3. 白盒发送第一条：生产 sendMessage 全链 =====
    final text1 = 'e2ee-link-$now';
    final msgId1 = 'c2csend1${now.toRadixString(36)}';
    final ok1 = await const ChatNetworkService().sendMessage({
      'id': msgId1,
      'type': 'C2C',
      'from': selfUid,
      'to': peerUid,
      'msg_type': 'text',
      'action': '',
      'payload': <String, dynamic>{'msg_type': 'text', 'text': text1},
    });
    expect(ok1, isTrue, reason: 'strict 模式加密发送应成功；false = 策略门拒发/加密失败/WS 提交失败');
    flowLog('白盒 sendMessage 已提交 msgId=$msgId1');
    await takeScreenshot(tester, 'e2eesend_01_whitelist_send_ok');

    // ===== 4. 对端经 history API 拉取：密文落库语义 =====
    final found1 = await _waitForHistoryMessage(peer, selfUid, msgId1);
    expect(found1, isNotNull, reason: '45 秒内对端历史未出现该消息——WS→后端路由→落库链路断裂');
    _expectEncryptedArchive(found1!, text1, '第一条(白盒发送)');
    await takeScreenshot(tester, 'e2eesend_02_peer_history_cipher');

    // ===== 5. UI：push 真实 ChatPage，经 provider 发第二条 =====
    final ctx = tester.element(find.byType(Scaffold).first);
    unawaited(
      Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatPage(
            type: 'C2C',
            peerId: peerUid,
            peerTitle: 'e2ee-send-peer',
            peerAvatar: '',
            peerSign: '',
          ),
        ),
      ),
    );
    await settle(tester, maxSeconds: 6);
    expect(find.byType(ChatPage), findsOneWidget, reason: 'ChatPage 应已打开');

    final chatCtx = tester.element(find.byType(ChatPage).first);
    final container = ProviderScope.containerOf(chatCtx);
    final notifier = container.read(chatProvider.notifier);
    final text2 = 'e2ee-render-$now';
    final msgId2 = Xid().toString();
    // 与 ChatPage._sendTextMessage 同构：provider 发送（加密+WS）之后
    // 由页面层把消息插入 ChatService 列表驱动渲染。
    final message2 = TextMessage(
      authorId: selfUid,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
      id: msgId2,
      text: text2,
      metadata: {'peer_id': peerUid},
    );
    final ok2 = await notifier.addMessage(
      selfUid,
      peerUid,
      '',
      'e2ee-send-peer',
      'C2C',
      message2,
    );
    expect(ok2, isTrue, reason: 'ChatPage 内 provider 发送应成功（加密 + WS 提交）');
    await notifier.chatService?.insertMessage(
      message2,
      index: notifier.chatService?.messages.length ?? 0,
    );
    await settle(tester, maxSeconds: 4);

    // 层级 1：消息进入 UI 真相源（SqliteChatService.messages，即聊天页
    // 渲染列表的唯一来源；ChatState.messages 只是滞后同步的接缝镜像）
    final uiMessages = notifier.chatService?.messages ?? const [];
    expect(
      uiMessages.any((m) => m.id == msgId2),
      isTrue,
      reason: '发送的第二条消息应进入 ChatService.messages（UI 渲染真相源）',
    );
    await takeScreenshot(tester, 'e2eesend_03_ui_truth_source');

    // 层级 2：气泡实际渲染。flutter_chat_ui 的文本走 RichText 族，
    // find.textContaining 需显式 findRichText。
    expect(
      find.textContaining(text2, findRichText: true),
      findsWidgets,
      reason: '发送的第二条消息应在 ChatPage 本地回显渲染',
    );
    flowLog('ChatPage 回显断言通过 text2=$text2');
    await takeScreenshot(tester, 'e2eesend_04_bubble_render');

    // ===== 6. 对端历史亦可见第二条（UI 入口发送同样落库） =====
    final found2 = await _waitForHistoryMessage(peer, selfUid, msgId2);
    expect(found2, isNotNull, reason: '对端历史未出现第二条消息——UI 入口发送的落库链路断裂');
    _expectEncryptedArchive(found2!, text2, '第二条(ChatPage 发送)');
    await takeScreenshot(tester, 'e2eesend_05_peer_history_second');

    // 清理：退出 ChatPage，保持会话栈干净
    final nav = Navigator.of(chatCtx);
    nav.pop();
    await settle(tester, maxSeconds: 2);
    flowLog('测试完成');
  });
}

/// 轮询对端 C2C 历史，直到 [msgId] 出现（≤45s，3s 间隔）。
/// history 返回非 0（如 archive 未就绪）时继续重试，留给超时报错。
Future<Map<String, dynamic>?> _waitForHistoryMessage(
  FlowApiClient peer,
  String selfUid,
  String msgId,
) async {
  for (var i = 0; i < 15; i++) {
    await Future<void>.delayed(const Duration(seconds: 3));
    try {
      final resp = await peer.get(
        '/api/v1/msg/history',
        queryParameters: {
          'chat_type': 'c2c',
          'peer_id': selfUid,
          'after_seq': '0',
          'limit': '50',
        },
      );
      if (resp['code'] != 0) {
        flowLog('history 第${i + 1}轮非 0: ${resp['msg']}');
        continue;
      }
      final messages =
          (resp['payload']?['messages'] as List?) ?? const <dynamic>[];
      flowLog('history 第${i + 1}轮 ${messages.length} 条');
      for (final m in messages) {
        final Map<String, dynamic>? row;
        if (m is Map<String, dynamic>) {
          row = m;
        } else if (m is Map<dynamic, dynamic>) {
          row = Map<String, dynamic>.from(m);
        } else {
          row = null;
        }
        if (row != null && '${row['msg_id']}' == msgId) {
          return row;
        }
      }
    } catch (e) {
      flowLog('history 第${i + 1}轮异常: $e');
    }
  }
  return null;
}

/// 密文落库语义断言：payload 不得含明文，e2ee 信封必须存在。
/// 后端 history 接口把 e2ee 信封作为 JSON 字符串透传（非对象）。
void _expectEncryptedArchive(
  Map<String, dynamic> msg,
  String plaintext,
  String label,
) {
  final payload = '${msg['payload'] ?? ''}';
  expect(
    payload.contains(plaintext),
    isFalse,
    reason: '$label：历史接口 payload 不得含明文（密文落库语义被破坏）',
  );
  final raw = msg['e2ee'];
  final Map<dynamic, dynamic> envelope;
  if (raw is Map) {
    envelope = raw;
  } else {
    envelope = jsonDecode('$raw') as Map<dynamic, dynamic>;
  }
  expect(
    envelope['devices'],
    isA<Map<dynamic, dynamic>>(),
    reason: '$label：e2ee 信封应为 per-device fan-out（devices 缺失）',
  );
  expect(envelope['protocol'], 'olm', reason: '$label：strict C2C 应走 OLM 协议');
  flowLog('$label 密文落库断言通过 (payload=${payload.length}字符, 信封 protocol=olm)');
}
