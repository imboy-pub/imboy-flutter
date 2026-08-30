// UpgradeCard 负按钮渲染契约测试（force 升级语义）：
// negativeBtn 文案为空串时按钮隐藏（Visibility isNotEmpty），
// 非空时显示——upgrade_page.dart 的初始构造与 initGeneral() 文案重建
// 共同依赖此契约保证「force 升级不提供下次再说」。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/single/upgrade_page.dart';

Future<void> _pumpCard(
  WidgetTester tester, {
  required String negativeBtn,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: UpgradeCard(
              title: '检测到新版本 1.0.1',
              message: '自动化测试升级流程（测完即删）',
              positiveBtn: '立即更新',
              negativeBtn: negativeBtn,
              hasLinearProgress: true,
              progress: 0,
              positiveCallback: () {},
              negativeCallback: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('force 升级（negativeBtn 空串）：负按钮隐藏', (tester) async {
    await _pumpCard(tester, negativeBtn: '');

    expect(find.text('立即更新'), findsOneWidget);
    expect(
      find.text('下次再说'),
      findsNothing,
      reason: 'force 升级必须更新，不得提供「下次再说」跳过选项',
    );
  });

  testWidgets('非 force（negativeBtn 非空）：负按钮可见', (tester) async {
    await _pumpCard(tester, negativeBtn: '下次再说');

    expect(find.text('立即更新'), findsOneWidget);
    expect(find.text('下次再说'), findsOneWidget);
  });

  testWidgets('文案重建（updateProgress）把负按钮置空串后隐藏——initGeneral 场景', (tester) async {
    await _pumpCard(tester, negativeBtn: '下次再说');
    expect(find.text('下次再说'), findsOneWidget);

    // 模拟 initGeneral() 在 force 卡片上的文案重建
    final state = tester.state(find.byType(UpgradeCard)) as UpgradeCardState;
    state.updateProgress(
      title: '检测到新版本 1.0.1',
      message: '自动化测试升级流程（测完即删）',
      positiveBtn: '立即更新',
      negativeBtn: '',
      hasLinearProgress: true,
      progress: 0,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('下次再说'),
      findsNothing,
      reason: 'initGeneral 把负按钮置空串后按钮必须隐藏（修复的回归点）',
    );
  });
}
