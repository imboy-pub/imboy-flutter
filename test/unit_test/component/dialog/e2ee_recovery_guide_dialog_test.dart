import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/dialog/e2ee_recovery_guide_dialog.dart';
import 'package:imboy/i18n/strings.g.dart';

/// E2EE 恢复引导对话框 / 横幅 widget 测试。
///
/// 覆盖三处行为契约：
/// 1. [E2EERecoveryBanner] 渲染文案并在点 × 时回调 onDismiss；
/// 2. [showE2EERecoveryGuide] newDevice 场景显示标题/双按钮，点「稍后」关闭；
/// 3. decryptFailed 场景显示对应标题。
///
/// 说明：「去恢复」与横幅主体点击会触发 go_router `context.push`，需路由环境，
/// 故本测试只验证「稍后」关闭路径与内容渲染，不触发导航分支。
void main() {
  Widget wrapGuide(E2EERecoveryScene scene) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showE2EERecoveryGuide(context, scene: scene),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  testWidgets('E2EERecoveryBanner 渲染文案并触发关闭回调', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: E2EERecoveryBanner(onDismiss: () => dismissed = true),
        ),
      ),
    );

    expect(find.text(t.chat.e2eeRecoveryBannerText), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(dismissed, isTrue);
  });

  testWidgets('newDevice 引导显示标题与双按钮，点「稍后」关闭', (tester) async {
    await tester.pumpWidget(wrapGuide(E2EERecoveryScene.newDevice));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(t.chat.e2eeRecoveryNewDeviceTitle), findsOneWidget);
    expect(find.text(t.chat.e2eeRecoveryLater), findsOneWidget);
    expect(find.text(t.chat.e2eeRecoveryGoRecover), findsOneWidget);

    await tester.tap(find.text(t.chat.e2eeRecoveryLater));
    await tester.pumpAndSettle();

    expect(find.text(t.chat.e2eeRecoveryNewDeviceTitle), findsNothing);
  });

  testWidgets('decryptFailed 引导显示对应标题', (tester) async {
    await tester.pumpWidget(wrapGuide(E2EERecoveryScene.decryptFailed));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(t.chat.e2eeRecoveryDecryptFailedTitle), findsOneWidget);
    expect(find.text(t.chat.e2eeRecoveryGoRecover), findsOneWidget);
  });
}
