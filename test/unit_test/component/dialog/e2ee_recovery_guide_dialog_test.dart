import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/dialog/e2ee_recovery_guide_dialog.dart';
import 'package:imboy/i18n/strings.g.dart';

/// E2EE 恢复引导对话框 / 横幅 widget 测试。
///
/// 覆盖三处行为契约：
/// 1. [E2EERecoveryBanner] 渲染文案并在点 × 时回调 onDismiss；
/// 2. [showE2EERecoveryGuide] newDevice 场景显示标题/双按钮，点「稍后」关闭；
/// 3. decryptFailed 场景显示对应标题。
///
/// 横幅键盘回归使用真实 go_router 路由；裁剪 E2EE 的产品仅验证入口隐藏，
/// 不将该结果当作启用 E2EE 后的键盘行为验证。
void main() {
  setUp(
    () => AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.e2ee: true}),
  );
  tearDown(() => AppFeatureRegistry.replaceSnapshotForTest({}));
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

  testWidgets('关闭 E2EE 时两种恢复弹窗都不出现', (tester) async {
    AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.e2ee: false});
    for (final scene in E2EERecoveryScene.values) {
      await tester.pumpWidget(wrapGuide(scene));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    }
  });

  testWidgets('关闭 E2EE 时横幅不显示也不清除恢复标记', (tester) async {
    AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.e2ee: false});
    var dismissed = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: E2EERecoveryBanner(onDismiss: () => dismissed = true),
          ),
        ),
      ),
    );
    expect(find.text(t.chat.e2eeRecoveryBannerText), findsNothing);
    expect(find.byIcon(CupertinoIcons.lock), findsNothing);
    expect(dismissed, isFalse);
    AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.e2ee: true});
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: E2EERecoveryBanner(onDismiss: () => dismissed = true),
          ),
        ),
      ),
    );
    expect(
      find.text(t.chat.e2eeRecoveryBannerText),
      compiledProductFeatures.contains(FeatureKeys.e2ee)
          ? findsOneWidget
          : findsNothing,
    );
    expect(dismissed, isFalse);
  });

  testWidgets('弹窗打开后关闭开关，恢复按钮不进入隐藏页面', (tester) async {
    await tester.pumpWidget(wrapGuide(E2EERecoveryScene.newDevice));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    if (!compiledProductFeatures.contains(FeatureKeys.e2ee)) {
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
      return;
    }
    AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.e2ee: false});
    await tester.tap(find.text(t.chat.e2eeRecoveryGoRecover));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('E2EERecoveryBanner 渲染文案并触发关闭回调', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: E2EERecoveryBanner(onDismiss: () => dismissed = true),
          ),
        ),
      ),
    );

    if (!compiledProductFeatures.contains(FeatureKeys.e2ee)) {
      expect(find.text(t.chat.e2eeRecoveryBannerText), findsNothing);
      expect(find.byIcon(CupertinoIcons.xmark_circle_fill), findsNothing);
      expect(dismissed, isFalse);
      return;
    }
    expect(find.text(t.chat.e2eeRecoveryBannerText), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
    await tester.pump();

    expect(dismissed, isTrue);
  });

  testWidgets(
    compiledProductFeatures.contains(FeatureKeys.e2ee)
        ? '恢复横幅的命名操作可分别 Tab/Enter，关闭不会触发恢复'
        : '编译裁剪 E2EE 后，Tab/Enter 保持入口隐藏且不触发关闭回调',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var dismissCalls = 0;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: E2EERecoveryBanner(onDismiss: () => dismissCalls++),
            ),
          ),
          GoRoute(
            path: '/e2ee_key_recovery',
            builder: (context, state) =>
                const Scaffold(body: Text('E2EE recovery destination')),
          ),
        ],
      );
      try {
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)),
        );
        await tester.pumpAndSettle();
        final recover = find.bySemanticsLabel(t.chat.e2eeRecoveryBannerText);
        final close = find.bySemanticsLabel(t.common.buttonClose);
        if (!compiledProductFeatures.contains(FeatureKeys.e2ee)) {
          expect(recover, findsNothing);
          expect(close, findsNothing);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(router.state.uri.path, '/');
          expect(dismissCalls, 0);
          expect(tester.takeException(), isNull);
          return;
        }

        expect(recover, findsOneWidget);
        expect(close, findsOneWidget);
        expect(tester.getSemantics(recover).flagsCollection.isButton, isTrue);
        expect(tester.getSemantics(close).flagsCollection.isButton, isTrue);
        expect(
          tester.getSemantics(recover).id,
          isNot(tester.getSemantics(close).id),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          tester.getSemantics(recover).flagsCollection.isFocused.toBoolOrNull(),
          isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          tester.getSemantics(close).flagsCollection.isFocused.toBoolOrNull(),
          isTrue,
        );
        expect(
          tester.getSemantics(recover).flagsCollection.isFocused.toBoolOrNull(),
          isFalse,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(dismissCalls, 1);
        expect(router.state.uri.path, '/');

        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(
          tester.getSemantics(recover).flagsCollection.isFocused.toBoolOrNull(),
          isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/e2ee_key_recovery');
        expect(find.text('E2EE recovery destination'), findsOneWidget);
        expect(dismissCalls, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        semantics.dispose();
      }
    },
  );

  testWidgets('newDevice 引导显示标题与双按钮，点「稍后」关闭', (tester) async {
    await tester.pumpWidget(wrapGuide(E2EERecoveryScene.newDevice));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    if (!compiledProductFeatures.contains(FeatureKeys.e2ee)) {
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.text(t.chat.e2eeRecoveryGoRecover), findsNothing);
      return;
    }
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

    if (!compiledProductFeatures.contains(FeatureKeys.e2ee)) {
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.text(t.chat.e2eeRecoveryGoRecover), findsNothing);
      return;
    }
    expect(find.text(t.chat.e2eeRecoveryDecryptFailedTitle), findsOneWidget);
    expect(find.text(t.chat.e2eeRecoveryGoRecover), findsOneWidget);
  });
}
