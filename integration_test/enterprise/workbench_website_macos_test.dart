import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/component/helper/safe_launcher.dart';
import 'package:imboy/modules/enterprise_oa/presentation/enterprise_workbench_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('macOS 工作台显示资料和官网入口，真实系统插件可以打开官网', (tester) async {
    expect(Platform.isMacOS, isTrue);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EnterpriseWorkbenchPage(
            entries: [],
            accountKey: 'synthetic-account',
            organizationId: '1',
            resourceEntries: [CupertinoListTile(title: Text('资料'))],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('资料'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workbench-official-website')),
      findsOneWidget,
    );
    // 直接核验真实平台返回值；不以无错误提示冒充浏览器打开成功。
    expect(
      await SafeLauncher.safeLaunchUrl(Uri.parse('https://imboy.pub/')),
      isTrue,
    );
  });
}
