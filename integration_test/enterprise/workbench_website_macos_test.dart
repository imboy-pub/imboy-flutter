import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/i18n/strings.g.dart';
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
    const launchChannel =
        'dev.flutter.pigeon.url_launcher_macos.UrlLauncherApi.launchUrl';
    final messenger = tester.binding.defaultBinaryMessenger;
    final nativeReply = Completer<void>();
    final urls = <Object?>[];
    // 只观察调用：请求和返回值原样交给真实 macOS 插件，不伪造成功。
    messenger.setMockMessageHandler(launchChannel, (message) async {
      urls.add(
        (const StandardMessageCodec().decodeMessage(message) as List).single,
      );
      final reply = await messenger.delegate.send(launchChannel, message);
      if (!nativeReply.isCompleted) nativeReply.complete();
      return reply;
    });
    addTearDown(() => messenger.setMockMessageHandler(launchChannel, null));
    await tester.tap(find.byKey(const ValueKey('workbench-official-website')));
    await tester.runAsync(
      () => nativeReply.future.timeout(const Duration(seconds: 20)),
    );
    await tester.pumpAndSettle();
    expect(urls, ['https://imboy.pub/']);
    expect(
      find.byKey(const ValueKey('workbench-official-website')),
      findsOneWidget,
    );
    // 页面收到 false 或异常时会显示错误；原生响应已完成后核验该分支。
    expect(find.text(t.common.cannotOpenWebpage), findsNothing);
  });
}
