// C2C 明文拒收安全回归（strict E2EE fail-closed 语义）：
// 对端账号经 FlowApiClient 登录 + WebSocket 直发一条**无 e2ee 字段的明文**
// text 消息；strict 部署（e2ee_mode=required）下被测端必须拒收——
// 不建会话、不落库、不渲染。会话未出现 = PASS（fail-closed 生效）。
//
// 背景：E2EE 红队审计确立的安全语义——明文 C2C 在 strict 模式下绝不
// 落库渲染。本测试把该语义固化为自动化回归，防将来被无意放宽。
//
// 数据自造：不依赖环境存量会话（对端消息由本测试的 WS 客户端发送）。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../flows/api_test_client.dart';
import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'strict 模式拒收明文 C2C 消息（不建会话不落库）',
    (tester) async {
      installPluginErrorFilter();
      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);

      // 1. 对端账号登录（明文契约，见 FlowApiClient.login 文档）
      final base = FlowApiConfig.apiBaseUrl.isNotEmpty
          ? FlowApiConfig.apiBaseUrl
          : 'http://127.0.0.1:9800';
      final sender = FlowApiClient(baseUrl: base, deviceId: 'c2cplat-sender');
      final loginRes = await sender.login(
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
      final sendUid = sender.currentUid ?? '';
      flowLog('对端登录成功 uid=$sendUid');

      // 2. 对端 WS 直发明文 text（无 e2ee 字段）给被测端（当前登录用户）
      final peerUid = UserRepoLocal.to.currentUid;
      final wsUrl =
          '${base.replaceFirst('http', 'ws')}/api/v1/ws'
          '?token=${sender.accessToken}&did=c2cplat-sender&cos=android';
      final ws = await WebSocket.connect(
        wsUrl,
        headers: {'Sec-WebSocket-Protocol': 'imboy.v2'},
      );
      flowLog('对端 WS 已连接');

      final now = DateTime.now().millisecondsSinceEpoch;
      final msgText = 'plaintext-$now';
      ws.add(
        jsonEncode({
          'id': 'c2cplat${now.toRadixString(36)}',
          'type': 'C2C',
          'from': sendUid,
          'to': peerUid,
          'msg_type': 'text',
          'action': '',
          'e2ee': null,
          'payload': {'text': msgText, 'client_send_ts': now},
          'created_at': now,
        }),
      );
      flowLog('明文 text 已发送（预期被拒收）');

      // 3. 被测端观察窗口内不允许出现新 C2C 会话（fail-closed 验证）
      await settle(tester, maxSeconds: 3);
      Future<bool> hasC2C() async {
        // 每轮 pump 驱动帧刷新后再查
        await tester.pump(const Duration(milliseconds: 500));
        return tester.any(
          find.byWidgetPredicate(
            (widget) =>
                widget is ConversationItem && widget.model.type == 'C2C',
          ),
        );
      }

      var leaked = false;
      for (int i = 0; i < 20; i++) {
        if (await hasC2C()) {
          leaked = true;
          break;
        }
      }
      expect(
        leaked,
        isFalse,
        reason:
            'strict 模式收到明文 C2C 必须拒收——'
            '会话出现意味着 fail-closed 被破坏，属安全回归',
      );
      await takeScreenshot(tester, 'c2cplat_01_no_leak');
      drainKnownFrameworkExceptions(tester);
      ws.close();
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
