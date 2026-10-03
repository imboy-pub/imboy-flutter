import 'dart:async';

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
  _registerStrengthTest();
  _registerRecoveryTest();
  _registerMismatchTest();
  _registerClipboardReplacementTest();
  _registerClipboardGenerationTest();
  _registerClipboardDisposalTest();
  _registerClipboardDelayedReadTest();
  Widget wrap(Widget page) {
    return TranslationProvider(
      child: ProviderScope(child: MaterialApp(home: page)),
    );
  }

  // 页面 TextField 顺序：密码(0)、确认(1)、备注(2)
  Finder exportButton() =>
      find.widgetWithText(CupertinoButton, t.common.e2eeBackupGenerateBtn);

  bool isExportButtonEnabled(WidgetTester tester) =>
      tester.widget<CupertinoButton>(exportButton()).onPressed != null;

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

Widget _exportHarness() => TranslationProvider(
  child: ProviderScope(
    child: MaterialApp(
      builder: AppLoading.init(),
      home: const E2EEBackupExportPage(),
    ),
  ),
);

void _registerStrengthTest() {
  testWidgets('密码强度随弱/强输入及清空更新', (tester) async {
    await tester.pumpWidget(_exportHarness());
    await tester.pump();
    final password = find.byType(TextField).at(0);
    await tester.enterText(password, 'abcd');
    await tester.pump();
    expect(find.text(t.common.e2eeBackupPwdWeak), findsOneWidget);
    final weak = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;
    await tester.enterText(password, 'CorrectHorseBatteryStaple!123');
    await tester.pump();
    expect(find.text(t.common.e2eeBackupPwdVeryStrong), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      greaterThan(weak),
    );
    await tester.enterText(password, '');
    await tester.pump();
    expect(find.text(t.common.e2eeBackupPwdWeak), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0,
    );
  });
}

void _registerRecoveryTest() {
  testWidgets('生成恢复密钥将弹窗密钥填入两个密码框', (tester) async {
    await tester.pumpWidget(_exportHarness());
    await tester.pump();
    await tester.tap(find.text(t.common.e2eeUseRecoveryKey));
    await tester.pumpAndSettle();
    final key = tester
        .widget<SelectableText>(
          find.descendant(
            of: find.byType(CupertinoAlertDialog),
            matching: find.byType(SelectableText),
          ),
        )
        .data!;
    expect(key, isNotEmpty);
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].controller!.text, key);
    expect(fields[1].controller!.text, key);
    await tester.tap(
      find.widgetWithText(CupertinoDialogAction, t.common.buttonConfirm),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(
      tester
          .widget<CupertinoButton>(
            find.widgetWithText(
              CupertinoButton,
              t.common.e2eeBackupGenerateBtn,
            ),
          )
          .onPressed,
      isNotNull,
    );
  });
}

void _registerMismatchTest() {
  testWidgets('密码不一致时提示错误且不读取安全存储密钥', (tester) async {
    var secureReads = 0;
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      secureReads++;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(_exportHarness());
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), 'FirstPassword123!');
    await tester.enterText(find.byType(TextField).at(1), 'OtherPassword123!');
    await tester.pump();
    await tester.ensureVisible(
      find.widgetWithText(CupertinoButton, t.common.e2eeBackupGenerateBtn),
    );
    await tester.tap(
      find.widgetWithText(CupertinoButton, t.common.e2eeBackupGenerateBtn),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(t.common.e2eeBackupErrPwdMismatch), findsOneWidget);
    expect(secureReads, 0);
    expect(find.text(t.common.e2eeBackupExportSuccessTitle), findsNothing);
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(t.common.e2eeBackupErrPwdMismatch), findsNothing);
  });
}

class _ClipboardProbe {
  String text = '';
  final writes = <String>[];
  Completer<dynamic>? nextRead;
  int readStarts = 0;

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        text = (call.arguments as Map)['text'] as String;
        writes.add(text);
      }
      if (call.method == 'Clipboard.getData') {
        readStarts++;
        final deferred = nextRead;
        nextRead = null;
        if (deferred != null) return deferred.future;
        return text.isEmpty ? null : {'text': text};
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }
}

Future<String> _copyRecoveryKey(WidgetTester tester) async {
  await tester.tap(find.text(t.common.e2eeUseRecoveryKey));
  await tester.pumpAndSettle();
  final key = tester
      .widget<SelectableText>(
        find.descendant(
          of: find.byType(CupertinoAlertDialog),
          matching: find.byType(SelectableText),
        ),
      )
      .data!;
  await tester.tap(
    find.widgetWithText(CupertinoDialogAction, t.common.buttonCopy),
  );
  for (var frame = 0; frame < 80; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.byType(CupertinoAlertDialog), findsNothing);
  return key;
}

void _registerClipboardReplacementTest() {
  testWidgets('到期清理不覆盖用户后来复制的其他内容', (tester) async {
    final clipboard = _ClipboardProbe()..install();
    await tester.pumpWidget(_exportHarness());
    await tester.pump();
    final key = await _copyRecoveryKey(tester);
    expect(clipboard.text, key);
    await Clipboard.setData(const ClipboardData(text: 'unrelated-content'));
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(clipboard.text, 'unrelated-content');
    expect(clipboard.writes, [key, 'unrelated-content']);
  });
}

void _registerClipboardGenerationTest() {
  testWidgets('旧密钥计时器不清除后来生成复制的新密钥', (tester) async {
    final clipboard = _ClipboardProbe()..install();
    await tester.pumpWidget(_exportHarness());
    await tester.pump();
    final first = await _copyRecoveryKey(tester);
    await tester.pump(const Duration(seconds: 30));
    final second = await _copyRecoveryKey(tester);
    expect(second, isNot(first));
    expect(clipboard.text, second);
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(clipboard.text, second);
    expect(clipboard.writes, [first, second]);
    await tester.pump(const Duration(seconds: 38));
    await tester.pumpAndSettle();
    expect(clipboard.text, '');
    expect(clipboard.writes, [first, second, '']);
  });
}

void _registerClipboardDisposalTest() {
  testWidgets('页面销毁后仍清理自己的旧密钥且无界面写入异常', (tester) async {
    final clipboard = _ClipboardProbe()..install();
    await tester.pumpWidget(_exportHarness());
    await tester.pump();
    final key = await _copyRecoveryKey(tester);
    expect(clipboard.text, key);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(clipboard.text, '');
    expect(clipboard.writes, [key, '']);
    expect(tester.takeException(), isNull);
  });
}

void _registerClipboardDelayedReadTest() {
  for (final replacePage in [false, true]) {
    final suffix = replacePage ? '重建页面' : '同一页面';
    testWidgets('迟到的旧剪贴板读取不能清空新复制的恢复密钥（$suffix）', (tester) async {
      final clipboard = _ClipboardProbe()..install();
      await tester.pumpWidget(_exportHarness());
      await tester.pump();
      final first = await _copyRecoveryKey(tester);
      final staleRead = Completer<dynamic>();
      clipboard.nextRead = staleRead;
      await tester.pump(const Duration(seconds: 53));
      expect(clipboard.readStarts, 1);
      if (replacePage) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(_exportHarness());
        await tester.pump();
      }
      final second = await _copyRecoveryKey(tester);
      expect(second, isNot(first));
      staleRead.complete({'text': first});
      await tester.pump();
      await tester.pump();
      final afterStaleRead = clipboard.text;
      // 完成新计时器后再断言，失败也不留下 pending timer。
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(afterStaleRead, second);
      expect(clipboard.text, '');
      expect(clipboard.writes, [first, second, '']);
    });
  }
}
