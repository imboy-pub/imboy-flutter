/// F5（PERF-05 R6b）：Cupertino 全组件文本样式必须挂 NotoSansSC 子集回退链。
///
/// 背景（netlog 实证 runs/reverify-jny02-20261116/f3-f5-login-result.json）：
/// web_shell 渲染期仍向 fonts.gstatic 拉 NotoSansSC 117/118 ×2 +
/// NotoSansSymbols ×1。本地产子集（cmap 5176）覆盖渲染文本，缺口在样式链：
/// Cupertino 组件（CupertinoNavigationBar 标题等）读 SDK 默认
/// `_kDefaultTextStyle`（fontFamily 'CupertinoSystemText' 在 web 未注册、
/// 无任何 fallback）→ 中文标题落到引擎默认字体 → CanvasKit 拉 gstatic 分片。
///
/// 修复（lib/theme/default/theme.dart）：cupertinoOverrideTheme 注入
/// CupertinoTextThemeData(textStyle: SDK 默认逐字段复刻 + 回退链)。
/// CupertinoTextThemeData 的派生样式（navTitle/picker/action 等）由
/// textStyle copyWith 生成，回退链随继承覆盖全部角色。
///
/// 本测试断言 Cupertino 母样式与导航栏标题派生样式实际携带
/// kAppFontFamilyFallback（外拉归零的静态等价判定），且 'CupertinoSystemText'
/// 字族与 label 动态色语义保留（Apple 原生渲染零变化）。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/theme.dart';

void main() {
  for (final isDark in [false, true]) {
    testWidgets(
      'Cupertino 母样式与导航栏标题携带 NotoSansSC 回退链（${isDark ? "暗色" : "亮色"}）',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: isDark ? AppTheme.getDarkTheme() : AppTheme.getLightTheme(),
            home: CupertinoPageScaffold(
              navigationBar: const CupertinoNavigationBar(middle: Text('设置')),
              child: const SizedBox.shrink(),
            ),
          ),
        );
        await tester.pump();

        final context = tester.element(find.byType(CupertinoPageScaffold));
        final cupertinoTheme = CupertinoTheme.of(context);
        final base = cupertinoTheme.textTheme.textStyle;
        final navTitle = cupertinoTheme.textTheme.navTitleTextStyle;

        expect(
          base.fontFamilyFallback,
          kAppFontFamilyFallback,
          reason: 'Cupertino 母样式必须整链挂上（首位 NotoSansSC）',
        );
        expect(
          navTitle.fontFamilyFallback,
          kAppFontFamilyFallback,
          reason: 'navTitle 派生样式经 copyWith 继承整链',
        );
        // SDK 默认行为不回退：'CupertinoSystemText' 字族保留（Apple 原生
        // 照常命中；web 未命中时走上方回退链）。
        expect(base.fontFamily, 'CupertinoSystemText');
        expect(navTitle.fontFamily, 'CupertinoSystemText');
        expect(base.fontSize, 17.0);
        expect(base.letterSpacing, -0.41);
      },
    );
  }

  testWidgets('回退链首位是内嵌 NotoSansSC 子集（阻断 gstatic 外拉的前提）', (tester) async {
    expect(kAppFontFamilyFallback.first, 'NotoSansSC');
    expect(kAppFontFamilyFallback, contains('sans-serif'));
  });

  testWidgets('亮暗两套主题的 Cupertino 母样式颜色为 label 动态色（语义不变）', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getLightTheme(),
        home: CupertinoPageScaffold(child: const SizedBox.shrink()),
      ),
    );
    await tester.pump();
    final light = CupertinoTheme.of(
      tester.element(find.byType(CupertinoPageScaffold)),
    ).textTheme.textStyle;
    expect(
      (light.color as CupertinoDynamicColor?)?.color,
      CupertinoColors.label.color,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getDarkTheme(),
        home: CupertinoPageScaffold(child: const SizedBox.shrink()),
      ),
    );
    await tester.pump();
    final dark = CupertinoTheme.of(
      tester.element(find.byType(CupertinoPageScaffold)),
    ).textTheme.textStyle;
    expect(
      (dark.color as CupertinoDynamicColor?)?.darkColor,
      CupertinoColors.label.darkColor,
    );
    // 两套主题均沿用 SDK 的 label 动态色（按上下文亮度解析）——语义不变。
  });
}
