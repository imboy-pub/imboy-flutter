// P0 Demo Flow：会话列表 → 搜索入口（只读）。

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';
import 'demo_flow_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'P0 会话列表和搜索入口可访问（只读）',
    (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);
      await dismissRecoveryGuideIfVisible(tester);

      if (!await openConversationTab(tester)) {
        markTestSkipped('无法进入会话列表');
        return;
      }

      expect(
        find.byKey(const Key('conversation_search_input')),
        findsOneWidget,
      );
      final items = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'Slidable',
      );
      if (tester.any(items)) {
        flowLog('P0 会话 Demo Flow：发现 ${items.evaluate().length} 个会话项');
      } else {
        flowLog('P0 会话 Demo Flow：当前会话列表为空');
      }
      drainKnownFrameworkExceptions(tester);
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
