/// T05 结构夹具框架 — imboy-enterprise-uiux-v1
///
/// 结构/交互测试的统一真实壳：真实应用主题构建器（[AppTheme]）+ 真实
/// i18n provider（TranslationProvider）+ 可参数化的 viewport/亮度/平台/
/// locale/文字缩放。不依赖视觉字体资产——缺确定性 CJK 字体只阻塞
/// T05.a 与视觉验收（GOLDEN_ENV.md），不阻塞本框架与任何非视觉测试。
///
/// 与视觉环境的边界：本文件不导入 golden_font_loader，不参与任何
/// 图像比较；无真实字体的截图一律标 STRUCTURE_ONLY，不冒充中文可读
/// 性或精确文本几何验收（STRUCTURE_ENV.md）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/theme.dart';

/// 冻结视口（PRD §7：360×800 基准 / 1280×800 宽窗；DPR 恒为 1）
class UiuxViewport {
  static const Size phone = Size(360, 800);
  static const Size wide = Size(1280, 800);
}

/// 结构测试环境描述（与视觉环境 GOLDEN_ENV.md 严格分离）
class UiuxEnv {
  final Size size;
  final Brightness brightness;
  final TargetPlatform platform;
  final Locale locale;

  /// 文字缩放倍率（1=基准，2=大字）；以 [TextScaler.linear] 生效，
  /// 禁止 clamp/关闭缩放（PRD D06）。
  final double scale;

  const UiuxEnv({
    this.size = UiuxViewport.phone,
    this.brightness = Brightness.light,
    this.platform = TargetPlatform.iOS,
    this.locale = const Locale('zh', 'CN'),
    this.scale = 1.0,
  });
}

/// 冻结时钟：仅作为断言输入（日期分隔、等待时长格式化等的期望值来源）。
/// 不拦截应用内 DateTime.now()——该限制登记于 STRUCTURE_ENV.md。
DateTime uiuxFrozenClock() => DateTime(2026, 1, 15, 10, 0, 0);

/// 结构夹具：真实主题 + 真实 i18n + 参数化环境。
/// 渲染异常不被吞（配合 [assertNoRenderErrors]）。
///
/// 平台/视口恢复必须在 [pumpUiux] 返回前同步完成（try/finally）：
/// flutter_test 的 foundation invariant 检查发生在测试体结束的瞬间，
/// 早于 dart test 的 addTearDown 回调——用 addTearDown 还原
/// [debugDefaultTargetPlatformOverride] 会让所有成功通过的用例
/// 反而报 "foundation debug variable was changed by the test"。
/// 挂载完成后复位不影响已构建树的 Theme/MediaQuery 产物。
Future<void> pumpUiux(
  WidgetTester tester,
  Widget child, {
  UiuxEnv env = const UiuxEnv(),
}) async {
  final TargetPlatform? prevPlatform = debugDefaultTargetPlatformOverride;
  final double prevDpr = tester.view.devicePixelRatio;
  final Size prevPhysical = tester.view.physicalSize;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = env.size;
  debugDefaultTargetPlatformOverride = env.platform;
  try {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          locale: env.locale,
          theme: env.brightness == Brightness.light
              ? AppTheme.getLightThemeFromOption(FontSizeOption.normal)
              : AppTheme.getDarkThemeFromOption(FontSizeOption.normal),
          builder: (context, native) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(env.scale)),
            child: native!,
          ),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
  } finally {
    debugDefaultTargetPlatformOverride = prevPlatform;
    tester.view.devicePixelRatio = prevDpr;
    tester.view.physicalSize = prevPhysical;
  }
}

/// 结构判定：任何从被测树逃逸的渲染/构建异常都必须让当前卡失败。
void assertNoRenderErrors(WidgetTester tester) {
  final Object? ex = tester.takeException();
  if (ex != null) {
    fail('render exception escaped the widget tree: $ex');
  }
}
