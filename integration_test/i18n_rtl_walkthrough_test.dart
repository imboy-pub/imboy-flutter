// i18n 发布治理 Gate 3 真机走查（2026-09-05）
//
// 目的：在 Android 真机上验证 i18n 运行时行为，补齐 widget 级 UI Gate
// 覆盖不到的真实渲染证据：
//   1. ar-SA 运行时切换后主 Shell 整树翻转为 RTL（P6 移除全局
//      Directionality(TextDirection.ltr) 修复的真机端到端证据）；
//   2. de-DE 长文案在真实设备渲染下的主 Shell 布局；
//   3. 截图取证：Android 真机 binding.takeScreenshot 在厂商 ROM 上会阻塞，
//      按 test_utils 既有约定走 AI_SCREENSHOT_HOLD_MS 检查点暂停 +
//      宿主侧 adb screencap 抓屏。
//
// 运行方法（宿主侧需要同时开 adb 抓屏巡检，见 I18N_AUDIT_REPORT.md §6.6）：
//   adb reverse tcp:9800 tcp:9800
//   flutter test integration_test/i18n_rtl_walkthrough_test.dart \
//     -d <real_device_id> \
//     --dart-define=APP_ENV=local \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9800 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9800 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9800/api/v1/ws \
//     --dart-define=TEST_PHONE=smoke_bob \
//     --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=AI_SCREENSHOT_HOLD_MS=4000
//
// 只读走查：不发消息、不改资料、不创建任何业务对象。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/main.dart' as app;
import 'package:integration_test/integration_test.dart';

import 'flows/test_utils.dart'
    show
        checkPreconditions,
        flowLog,
        installPluginErrorFilter,
        settle,
        takeScreenshot;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Gate3 真机走查：主 Shell × 基线/ar-SA RTL/de-DE', (tester) async {
    installPluginErrorFilter();
    app.main();

    // 标准前置链：后端可达 → 入口稳定 → 欢迎页跳过 → UI 登录 → 主 Shell 挂载
    if (!await checkPreconditions(tester)) {
      fail('i18n 走查前置失败：后端不可达、入口异常或登录未成功进入主界面');
    }
    await settle(tester, maxSeconds: 3);

    final baseline = LocaleSettings.currentLocale;
    flowLog('i18n 走查: 基线 locale=${baseline.toString()}');

    // 检查点 1：基线语言主 Shell
    final baselineDir = Directionality.of(
      tester.element(find.byType(Scaffold).first),
    );
    flowLog('i18n 走查: 基线方向=${baselineDir.toString()}');
    await takeScreenshot(tester, 'i18n_01_baseline_shell');

    // 检查点 2：ar-SA — 整树必须翻转为 RTL
    LocaleSettings.setLocaleRaw('ar-SA');
    await settle(tester, maxSeconds: 8);
    final arDir = Directionality.of(
      tester.element(find.byType(Scaffold).first),
    );
    expect(
      arDir,
      TextDirection.rtl,
      reason:
          '真机切 ar-SA 后主 Shell 必须为 RTL。若为 LTR 说明全局 '
          'Directionality(TextDirection.ltr) 回潮（P6 修复被还原）或方向'
          '传播链断裂——先查 lib/run.dart 是否重新出现全局 Directionality。',
    );
    await takeScreenshot(tester, 'i18n_02_ar_shell');

    // 检查点 3：de-DE — 长文案代表语言，回 LTR
    LocaleSettings.setLocaleRaw('de-DE');
    await settle(tester, maxSeconds: 8);
    final deDir = Directionality.of(
      tester.element(find.byType(Scaffold).first),
    );
    expect(deDir, TextDirection.ltr, reason: 'de-DE 应为 LTR');
    await takeScreenshot(tester, 'i18n_03_de_shell');

    // 恢复基线语言，不在设备残留 ar 态（app 若持久化语言，避免影响后续使用）
    LocaleSettings.setLocale(baseline);
    await settle(tester, maxSeconds: 5);
  });
}
