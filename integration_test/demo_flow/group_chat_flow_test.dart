// P0 Demo Flow：已有 C2G 会话 → 群聊页面（只读）。

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';
import 'demo_flow_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'P0 群聊入口可访问（不发送消息）',
    (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);
      await dismissRecoveryGuideIfVisible(tester);

      if (!await openConversationTab(tester)) {
        markTestSkipped('无法进入会话列表');
        return;
      }
      final item = await waitForConversationType(tester, 'C2G');
      if (item == null) {
        markTestSkipped('当前账号没有可识别的已有 C2G 会话');
        return;
      }

      await safeTap(tester, item.first);
      for (int i = 0; i < 30 && !tester.any(find.byType(ChatPage)); i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.byType(ChatPage), findsOneWidget);
      flowLog('P0 群聊 Demo Flow：ChatPage 已打开，未输入或发送消息');
      drainKnownFrameworkExceptions(tester);
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
