/// T05 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest，全部不得 skip）：
///  1. harness_real_shell_mounts
///  2. harness_restores_platform_locale_clock
///  3. harness_env_restored_after_teardown
///  4. harness_fails_render_exceptions
///  5. harness_font_missing_does_not_disable_nonvisual_tests
///  6. harness_env_switches
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/theme.dart';

import '../support/uiux_harness.dart';

class _Boom extends StatelessWidget {
  const _Boom();

  @override
  Widget build(BuildContext context) {
    throw StateError('boom: deliberate build exception fixture');
  }
}

void _noOp() {}

void main() {
  testWidgets('harness_real_shell_mounts：真实应用主题构建器挂载真实组件', (tester) async {
    await pumpUiux(
      tester,
      const NoDataView(
        icon: CupertinoIcons.exclamationmark_circle,
        text: '频道内容加载失败',
        description: '请稍后重试。',
        retryLabel: '重试',
        // retry 按钮仅在提供回调时渲染（nodata_view.dart 条件分支）。
        onTop: _noOp,
      ),
    );
    expect(find.text('频道内容加载失败'), findsOneWidget);
    expect(find.text('请稍后重试。'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    final BuildContext ctx = tester.element(find.byType(NoDataView));
    // 真实壳证据：挂载的是 AppTheme 真实构建器产物，不是夹具自造主题
    expect(
      Theme.of(ctx).colorScheme.primary,
      AppTheme.getLightThemeFromOption(FontSizeOption.normal)
          .colorScheme
          .primary,
    );
    expect(Theme.of(ctx).brightness, Brightness.light);
    assertNoRenderErrors(tester);
  });

  testWidgets('harness_restores_platform_locale_clock：环境参数在挂载期生效', (
    tester,
  ) async {
    await pumpUiux(
      tester,
      const SizedBox.shrink(),
      env: const UiuxEnv(
        platform: TargetPlatform.android,
        locale: Locale('en', 'US'),
        scale: 2.0,
      ),
    );
    // 挂载期证据取自已构建树（pumpUiux 返回前已同步复位全局平台覆盖，
    // 见夹具注释——foundation invariant 检查早于 addTearDown）。
    final BuildContext ctx = tester.element(find.byType(Scaffold));
    expect(Theme.of(ctx).platform, TargetPlatform.android);
    expect(Localizations.localeOf(ctx), const Locale('en', 'US'));
    expect(MediaQuery.textScalerOf(ctx).scale(10.0), closeTo(20.0, 0.01));
    // 夹具在返回前已复位 view 全局状态；挂载期 DPR=1 的证据取自挂载树
    expect(MediaQuery.devicePixelRatioOf(ctx), 1.0);
    assertNoRenderErrors(tester);
  });

  // 顺序固定：本用例起点即上一用例夹具退出（finally 同步还原）之后的现场
  testWidgets('harness_env_restored_after_teardown：用后平台/视口复位', (tester) async {
    expect(
      debugDefaultTargetPlatformOverride,
      isNull,
      reason: '上一用例设置的 android 平台覆盖必须已被还原',
    );
    // 视口恢复到进入夹具前的绑定默认值，而不是夹具值 360×800/1.0
    expect(tester.view.physicalSize, isNot(UiuxViewport.phone));
    expect(tester.view.devicePixelRatio, isNot(1.0));
  });

  testWidgets('harness_fails_render_exceptions：渲染/构建异常不被夹具吞掉', (tester) async {
    await pumpUiux(tester, const _Boom());
    // 框架记录到构建异常（未吞）；取空后无残留
    expect(tester.takeException(), isA<StateError>());
    expect(tester.takeException(), isNull);
  });

  testWidgets('harness_font_missing_does_not_disable_nonvisual_tests：'
      '默认测试字体下结构断言照常执行', (tester) async {
    // 本文件刻意不导入/加载 golden 字体（T05.a 独立提供）：
    // 默认字体下中文文本仍可被查找、测量并参与结构几何对比
    await pumpUiux(
      tester,
      const NoDataView(text: '暂无频道内容', description: '新的内容将在这里显示。'),
    );
    expect(find.text('暂无频道内容'), findsOneWidget);
    final Size box = tester.getSize(find.text('暂无频道内容'));
    expect(box.height, greaterThan(0));
    expect(box.width, greaterThan(0));
    assertNoRenderErrors(tester);
  });

  testWidgets('harness_env_switches：宽窗/暗色/大字参数化切换生效', (tester) async {
    await pumpUiux(
      tester,
      const SizedBox(width: double.infinity, child: Text('频道')),
      env: const UiuxEnv(
        size: UiuxViewport.wide,
        brightness: Brightness.dark,
        scale: 2.0,
      ),
    );
    // 宽窗证据取挂载树逻辑尺寸（夹具返回前已复位 view 全局状态）
    final BuildContext ctx = tester.element(find.byType(Scaffold));
    expect(MediaQuery.sizeOf(ctx), UiuxViewport.wide);
    expect(Theme.of(ctx).brightness, Brightness.dark);
    expect(MediaQuery.textScalerOf(ctx).scale(10.0), closeTo(20.0, 0.01));
    final Size atScale2 = tester.getSize(find.text('频道'));

    await pumpUiux(
      tester,
      const SizedBox(width: double.infinity, child: Text('频道')),
    );
    final Size atScale1 = tester.getSize(find.text('频道'));
    expect(
      atScale2.height,
      greaterThan(atScale1.height),
      reason:
          'scale2 的文本自然增高必须大于 scale1（STRUCTURE_ONLY，'
          '不声称字形可读性）',
    );
    assertNoRenderErrors(tester);
  });
}
