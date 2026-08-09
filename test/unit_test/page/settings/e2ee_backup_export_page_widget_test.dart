import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/settings/e2ee_backup_export_page.dart';

/// lib/page/settings/e2ee_backup_export_page.dart 的 widget 渲染测试。
///
/// 回归 BUG#132：确认密码框缺 onChanged → 输入不触发 setState →
/// 导出按钮 isEnabled（password 非空 && confirm 非空 && !_isExporting）
/// 不重算 → 按钮卡在初始 disabled 状态，必须再动密码框才解锁。
///
/// 页面 build 路径只依赖 i18n（t.common.*）与纯函数
/// E2EELocalBackupService.calculatePasswordStrength，不触碰平台通道，
/// 故普通 pump 即可，无需 runAsync（区别于 import 页测试）。
void main() {
  Widget wrap(Widget page) {
    return TranslationProvider(
      child: ProviderScope(child: MaterialApp(home: page)),
    );
  }

  // 页面 TextField 顺序：密码(0)、确认(1)、备注(2)
  Finder exportButton() =>
      find.widgetWithText(ElevatedButton, t.common.e2eeBackupGenerateBtn);

  bool isExportButtonEnabled(WidgetTester tester) =>
      tester.widget<ElevatedButton>(exportButton()).onPressed != null;

  group('E2EEBackupExportPage 导出按钮启用条件（BUG#132 回归）', () {
    testWidgets('初始两框为空时导出按钮 disabled', (tester) async {
      await tester.pumpWidget(wrap(const E2EEBackupExportPage()));
      await tester.pump();

      expect(exportButton(), findsOneWidget);
      expect(isExportButtonEnabled(tester), isFalse);
    });

    testWidgets('仅填密码框时导出按钮仍 disabled', (tester) async {
      await tester.pumpWidget(wrap(const E2EEBackupExportPage()));
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), 'secret123');
      await tester.pump();

      expect(isExportButtonEnabled(tester), isFalse);
    });

    testWidgets('填入确认框后导出按钮 enabled（无 onChanged 时此步不解锁）', (tester) async {
      await tester.pumpWidget(wrap(const E2EEBackupExportPage()));
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), 'secret123');
      await tester.pump();
      // 关键回归点：确认框输入必须触发 setState 重算 isEnabled
      await tester.enterText(find.byType(TextField).at(1), 'secret123');
      await tester.pump();

      expect(isExportButtonEnabled(tester), isTrue);
    });
  });
}
