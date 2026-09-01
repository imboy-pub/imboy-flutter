// strict E2EE 下语音消息气泡渲染验证（白盒加密发送 + 本地回显）。
//
// 历史：本测试原经第二个客户端 WS 直发明文 voice 帧造数据；strict 部署
// （e2ee_mode=required）下明文 C2C 被 fail-closed 拒收（不建会话不落库），
// 原语义已失效（静默 skip）。现改为与本轮 c2c_e2ee_send_render 同构的
// 白盒模式：app 内经 chatProvider.addMessage（真加密链路）+
// chatService.insertMessage（页面层 UI 插入）发送 voice 消息，
// 验证其在聊天页渲染为 AudioMessageBuilder（语音气泡）。
//
// 注：payload.source 用 s3:// 前缀（本地测试数据），会被 getSingleFile 的
// scheme 白名单拦截（SSRF 防护，设计行为，见 imboy_cache_manager.dart:141），
// 气泡进入错误态——但不影响验证目标：voice 消息渲染为
// AudioMessageBuilder（语音气泡）而非「不支持的消息类型」。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show AudioMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flyer_chat_audio_message/flyer_chat_audio_message.dart'
    show FlyerChatAudioMessage;
import 'package:imboy/component/chat/message_audio_builder.dart'
    show AudioMessageBuilder;
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:xid/xid.dart';

import '../flows/api_test_client.dart';
import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('strict 模式白盒加密发送 voice 消息渲染为语音气泡', (tester) async {
    installPluginErrorFilter();
    await ensureAppLaunched(tester, maxSeconds: 10);
    if (!await checkPreconditions(tester)) return;
    await settle(tester, maxSeconds: 2);

    // 1. strict 策略就绪确认
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
        '当前部署非 strict E2EE（current=${EncryptionModeService.current}）',
      );
      return;
    }

    // 2. 对端账号登录（只取 uid，消息由本端白盒加密发送）
    final base = FlowApiConfig.apiBaseUrl.isNotEmpty
        ? FlowApiConfig.apiBaseUrl
        : 'http://127.0.0.1:9800';
    final peer = FlowApiClient(baseUrl: base, deviceId: 'voice-peer');
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

    // 3. 打开与对端的 ChatPage
    final ctx = tester.element(find.byType(Scaffold).first);
    unawaited(
      Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatPage(
            type: 'C2C',
            peerId: peerUid,
            peerTitle: 'voice-render-peer',
            peerAvatar: '',
            peerSign: '',
          ),
        ),
      ),
    );
    await settle(tester, maxSeconds: 6);
    await takeScreenshot(tester, 'voice_conv_list_empty');
    if (!tester.any(find.byType(ChatPage))) {
      markTestSkipped('ChatPage 未打开，跳过');
      return;
    }
    await takeScreenshot(tester, 'voice_01_chat_page');
    flowLog('步骤3: ChatPage 已打开');

    // 4. 白盒两步发送 voice 消息（与 ChatPage 语音发送同构）
    final chatCtx = tester.element(find.byType(ChatPage).first);
    final container = ProviderScope.containerOf(chatCtx);
    final notifier = container.read(chatProvider.notifier);
    final now = DateTime.now().millisecondsSinceEpoch;
    final messageId = Xid().toString();
    final message = AudioMessage(
      authorId: selfUid,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
      id: messageId,
      // 本地测试假 uri：气泡进入错误态，不影响「渲染为语音气泡」验证目标
      source: 's3://local-test/voice_demo_$now.ogg',
      text: '',
      size: 1024,
      duration: const Duration(milliseconds: 1500),
      metadata: {'peer_id': peerUid},
    );
    final ok = await notifier.addMessage(
      selfUid,
      peerUid,
      '',
      'voice-render-peer',
      'C2C',
      message,
    );
    expect(ok, isTrue, reason: 'strict 模式加密发送 voice 应成功');
    await notifier.chatService?.insertMessage(
      message,
      index: notifier.chatService?.messages.length ?? 0,
    );
    flowLog('步骤4: voice 已白盒发送 msgId=$messageId');

    // 5. 轮询断言：voice 消息渲染为语音气泡（本地回显走 core 类型分发
    // FlyerChatAudioMessage；接收路径经 ChatMessageItem 分发为
    // AudioMessageBuilder——两条路径任一命中即达标）
    var found = false;
    bool hasVoiceBubble(WidgetTester t) => t.any(
      find.byWidgetPredicate(
        (w) => w is FlyerChatAudioMessage || w is AudioMessageBuilder,
        skipOffstage: false,
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      // skipOffstage: false —— 消息在 ListView 底部，可能处于视口外
      // （懒加载未构建），默认 finder 只查 onstage 节点会漏判
      if (hasVoiceBubble(tester)) {
        found = true;
        flowLog('步骤5: 第${i + 1}轮发现语音气泡组件');
        break;
      }
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
    }
    flowLog('步骤5: 轮询结束 found=$found');
    await settle(tester, maxSeconds: 2);
    await takeScreenshot(tester, 'voice_02_bubble_render');

    expect(found, isTrue, reason: '会话页应渲染出语音气泡 AudioMessageBuilder');
    flowLog('测试完成');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
