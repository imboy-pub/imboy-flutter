import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/app_loading.dart';
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

  group('#102 恢复密钥剪贴板自动清除', () {
    testWidgets('复制后 60 秒剪贴板被覆写（内容仍是该密钥时）', (tester) async {
      // mock 剪贴板平台通道：记录 setData、内存态返回 getData
      var clipboardText = '';
      var lastSetData = '<never>';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            switch (call.method) {
              case 'Clipboard.setData':
                lastSetData =
                    ((call.arguments as Map?)?['text'] as String?) ?? '';
                clipboardText = lastSetData;
                return null;
              case 'Clipboard.getData':
                return clipboardText.isEmpty ? null : {'text': clipboardText};
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            // EasyLoading 需 builder 注入（复制动作内 showSuccess）
            builder: AppLoading.init(),
            home: const ProviderScope(child: E2EEBackupExportPage()),
          ),
        ),
      );
      await tester.pump();

      // 打开恢复密钥弹窗
      await tester.tap(find.text(t.common.e2eeUseRecoveryKey));
      await tester.pump();

      // 从弹窗 SelectableText 读取生成的密钥
      final keyWidget = tester.widget<SelectableText>(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.byType(SelectableText),
        ),
      );
      final key = keyWidget.data!;

      // 点「复制」：写入剪贴板 + 弹 toast（不直接 await，toast 动画推帧）
      await tester.tap(find.text(t.common.buttonCopy));
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(lastSetData, key);

      // 快进 60s：到期剪贴板内容仍是该密钥 → 覆写为空串
      await tester.pump(const Duration(seconds: 61));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(lastSetData, '');
    });
  });
}
