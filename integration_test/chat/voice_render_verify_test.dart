// integration_test/chat/voice_render_verify_test.dart
//
// voice 消息渲染真机验证（#100）：
//   - 发送侧走 WS v2 JSON（msg_type=voice），不经 protobuf，直达
//     服务端 content_type_to_enum(<<"voice">>) -> 'AUDIO' 修复链路
//   - 接收侧验证 MessageTypeNormalizer audio→voice 归一后
//     渲染为 AudioMessageBuilder（语音气泡），而非「不支持的消息类型」
//
// 运行（真机，禁止模拟器）：
//   flutter test integration_test/chat/voice_render_verify_test.dart \
//     -d <device_id> \
//     --dart-define=APP_ENV=local_home \
//     --dart-define=API_BASE_URL=http://192.168.2.62:9800 \
//     --dart-define=TEST_PHONE=demo_voice_recv \
//     --dart-define=TEST_PASSWORD=admin888

import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:imboy/component/chat/message_audio_builder.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';

import '../flows/app_launcher.dart';
import '../flows/api_test_client.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('voice 消息渲染为语音气泡（WS JSON 发送链路）', (tester) async {
    // 1. 启动 app 并以 demo_voice_recv 登录（TEST_PHONE / TEST_PASSWORD）
    await ensureAppLaunched(tester, maxSeconds: 5);
    // 全新安装冷启动较慢，先等欢迎页/登录页/主界面任一入口就绪
    if (!await waitForEntryState(tester)) {
      markTestSkipped('App 入口状态超时，跳过');
    }
    flowLog('步骤1: 入口就绪，autoLoginOrSkip 开始');
    await autoLoginOrSkip(tester);
    flowLog('步骤1: autoLoginOrSkip 完成');
    await settle(tester, maxSeconds: 2);

    // 2. 第二个客户端（demo_voice_send）登录，准备 WS 发送
    final base = FlowApiConfig.apiBaseUrl.isNotEmpty
        ? FlowApiConfig.apiBaseUrl
        : 'http://192.168.2.62:9800';
    final sender = FlowApiClient(
      baseUrl: base,
      deviceId: 'voice-verify-sender',
    );
    final loginRes = await sender.login(
      account: 'demo_voice_send',
      password: 'admin888',
      type: 'account',
      // demo 账号为新格式（hmac_sha512 存储），仅接受明文
      plainPassword: true,
    );
    if (loginRes['code'] != 0) {
      markTestSkipped('demo_voice_send 登录失败: ${loginRes['msg']}，跳过');
      return;
    }
    final sendUid = sender.currentUid ?? '';
    flowLog('发送端登录成功 uid=$sendUid');

    // 3. WS 连接（imboy.v2 子协议）并发一条 voice
    // demo_voice_recv 固定 uid（本地测试账号，历史会话实证）
    const recvUid = '106019888539371520';
    final wsUrl =
        '${base.replaceFirst('http', 'ws')}/api/v1/ws'
        '?token=${sender.accessToken}&did=voice-verify-sender&cos=android';
    final ws = await WebSocket.connect(
      wsUrl,
      headers: {'Sec-WebSocket-Protocol': 'imboy.v2'},
    );
    flowLog('WS 已连接');

    final now = DateTime.now().millisecondsSinceEpoch;
    final msgId = 'voice${now.toRadixString(36)}';
    ws.add(
      jsonEncode({
        'id': msgId,
        'type': 'C2C',
        'from': sendUid,
        'to': recvUid,
        'msg_type': 'voice',
        'action': '',
        'e2ee': null,
        'payload': {
          'uri': 's3://local-test/voice_demo.ogg',
          'duration_ms': 1500,
          'size': 1024,
          'client_send_ts': now,
        },
        'created_at': now,
      }),
    );
    flowLog('voice 已发送 msgId=$msgId');

    // 4. 进会话列表 → 打开与 demo_voice_send 的会话
    flowLog('步骤4: 进入会话列表');
    await settle(tester, maxSeconds: 3);
    final convTabOk = await _openConversationTab(tester);
    flowLog('步骤4: _openConversationTab=$convTabOk');
    if (!convTabOk) {
      markTestSkipped('无法进入会话列表，跳过');
      return;
    }
    await settle(tester, maxSeconds: 3);
    flowLog('步骤4: 已 settle 会话列表');

    // 会话列表找 demo_voice_send；找不到先重试一次（等会话刷新）
    Finder? convItem;
    for (var i = 0; i < 3 && convItem == null; i++) {
      convItem = _findConversation(tester);
      flowLog('步骤4: 查找会话 第${i + 1}轮=${convItem != null}');
      if (convItem == null) {
        await Future<void>.delayed(const Duration(seconds: 2));
        await settle(tester, maxSeconds: 2);
      }
    }
    if (convItem == null) {
      await takeScreenshot(tester, 'voice_conv_list_empty');
      markTestSkipped('会话列表未找到 demo_voice_send 会话，跳过');
      return;
    }
    final tapOk = await safeTap(tester, convItem);
    flowLog('步骤4: 点击会话=$tapOk');
    await settle(tester, maxSeconds: 3);
    await takeScreenshot(tester, 'voice_01_chat_page');
    flowLog('步骤4: 已进入聊天页');

    // 5. 轮询断言：历史或实时推送的 voice 消息渲染为语音气泡
    // 注：payload.uri 用 s3:// 前缀（本地测试数据），会被 getSingleFile 的
    // scheme 白名单拦截（SSRF 防护，设计行为，见 imboy_cache_manager.dart:141），
    // 气泡进入错误态 —— 但这不影响验证目标：voice 消息渲染为
    // AudioMessageBuilder（语音气泡）而非「不支持的消息类型」。
    var found = false;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      // skipOffstage: false —— 新消息在 ListView 底部，可能处于视口外
      // （懒加载未构建），默认 finder 只查 onstage 节点会漏判
      if (tester.any(find.byType(AudioMessageBuilder, skipOffstage: false))) {
        found = true;
        flowLog('步骤5: 第${i + 1}轮发现 AudioMessageBuilder');
        break;
      }
      // 每 5 轮向下滚动列表，把底部新消息滚入视口触发构建
      if (i % 5 == 4) {
        try {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -400),
          );
        } catch (_) {
          // 无 Scrollable 时忽略（如聊天页未加载完成）
        }
        await tester.pump(const Duration(milliseconds: 300));
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    flowLog('步骤5: 轮询结束 found=$found');
    await settle(tester, maxSeconds: 2);
    await takeScreenshot(tester, 'voice_02_bubble_render');

    expect(found, isTrue, reason: '会话页应渲染出语音气泡 AudioMessageBuilder');
    ws.close();
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 6)));
}

Finder? _findConversation(WidgetTester tester) {
  // 会话列表项是 ConversationItem（ValueKey(model.id)），无固定 Key；
  // 显示 title 是 displayTitle（昵称或账号），textContaining 优先，兜底取第一项
  final byName = find.textContaining('demo_voice_send');
  if (tester.any(byName)) return byName.first;
  final byItem = find.byType(ConversationItem);
  if (tester.any(byItem)) return byItem.first;
  return null;
}

bool _isOnConvList(WidgetTester t) =>
    t.any(find.byKey(const Key('conversation_search_input'))) &&
    t.any(find.byType(ConversationItem));

Future<bool> _openConversationTab(WidgetTester t) async {
  if (_isOnConvList(t)) return true;
  final ok = await tapAny(t, [
    find.byKey(const Key('tab_conversations')),
    find.byIcon(CupertinoIcons.chat_bubble),
    find.byIcon(CupertinoIcons.chat_bubble_fill),
    find.text('消息'),
    find.text('会话'),
  ]);
  await settle(t, maxSeconds: 2);
  return ok || _isOnConvList(t);
}
