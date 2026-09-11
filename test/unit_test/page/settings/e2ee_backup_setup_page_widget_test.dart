import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/settings/e2ee_backup_setup_page.dart';
import 'package:imboy/service/e2ee_backup_setup_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/e2ee_backup_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 路径3 强制备份向导 widget 测试：
/// 校验闸（短口令禁提交/两次不一致不触网）、成功全链（上传→缓存口令→
/// 完成标记→成功弹窗→放行离开）、随机恢复密钥格式、失败后「稍后再说」。
///
/// 上传经 uploadOverride 注入（widget 测试无网）；安全存储用可持久化
/// mock（helper 版固定返 null，无法覆盖缓存口令→读回链）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureStore = <String, String?>{};
  final uploaded = <String>[];

  setUp(() async {
    LocaleSettings.setLocaleRaw('zh-CN');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    secureStore.clear();
    uploaded.clear();
    await StorageService.to.setBool(kE2eeBackupSetupDoneKey, false);
    // 模拟已登录账号（cachedPassphrase 的 uid 绑定校验依赖它）
    await StorageService.to.setString(Keys.currentUid, '1000000056');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            switch (call.method) {
              case 'write':
                final args = call.arguments as Map<Object?, Object?>;
                secureStore[args['key'] as String] = args['value'] as String?;
                return null;
              case 'read':
                final args = call.arguments as Map<Object?, Object?>;
                return secureStore[args['key'] as String];
              case 'delete':
                final args = call.arguments as Map<Object?, Object?>;
                secureStore.remove(args['key'] as String);
                return null;
              default:
                return null;
            }
          },
        );
    E2EEBackupSetupService.to.resetPromptGuardForTest();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  Future<void> openPage(
    WidgetTester tester, {
    Future<E2EEBackupPutResult> Function(String password)? override,
  }) async {
    await tester.pumpWidget(
      // AppLoading（flutter_easyloading）需要宿主 overlay，否则 toast 抛
      // 「EasyLoading is not initialized」（导入页 widget 测试同款处理）
      MaterialApp(
        builder: AppLoading.init(),
        home: Builder(
          builder: (ctx) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute<void>(
                  builder: (_) => E2EEBackupSetupPage(uploadOverride: override),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> enterPassword(
    WidgetTester tester,
    String pwd, {
    String? confirm,
  }) async {
    await tester.enterText(
      find.widgetWithText(TextField, t.common.e2eeBackupPwdLabel),
      pwd,
    );
    await tester.enterText(
      find.widgetWithText(TextField, t.common.e2eeBackupConfirmPwdLabel),
      confirm ?? pwd,
    );
    await tester.pump();
  }

  CupertinoButton submitButton(WidgetTester tester) {
    final btn = find.ancestor(
      of: find.text(t.common.e2eeBackupSetupSubmit),
      matching: find.byType(CupertinoButton),
    );
    return tester.widget<CupertinoButton>(btn.first);
  }

  testWidgets('初始未输入：提交按钮禁用，点击不触网', (tester) async {
    await openPage(
      tester,
      override: (pwd) async {
        uploaded.add(pwd);
        return const E2EEBackupPutResult(ok: true, backupVersion: 1);
      },
    );
    expect(submitButton(tester).onPressed, isNull);
    expect(uploaded, isEmpty);
  });

  testWidgets('两次输入不一致：报错且不触网', (tester) async {
    await openPage(
      tester,
      override: (pwd) async {
        uploaded.add(pwd);
        return const E2EEBackupPutResult(ok: true, backupVersion: 1);
      },
    );
    await enterPassword(tester, 'abcdefgh1234', confirm: 'abcdefgh12345');
    await tester.tap(find.text(t.common.e2eeBackupSetupSubmit));
    await tester.pump();
    expect(uploaded, isEmpty);
    expect(
      find.widgetWithText(CupertinoAlertDialog, t.common.buttonCopy),
      findsNothing,
    );
  });

  testWidgets('成功全链：上传→缓存口令→完成标记→成功弹窗→放行离开', (tester) async {
    await openPage(
      tester,
      override: (pwd) async {
        uploaded.add(pwd);
        return const E2EEBackupPutResult(ok: true, backupVersion: 7);
      },
    );

    // 中间态：9 位口令触发弱口令提示
    await enterPassword(tester, 'abcdefgh1');
    expect(find.text(t.common.e2eeBackupSetupWeakHint), findsOneWidget);

    await enterPassword(tester, 'abcdefgh1234');
    expect(find.text(t.common.e2eeBackupSetupWeakHint), findsNothing);

    await tester.tap(find.text(t.common.e2eeBackupSetupSubmit));
    await tester.pumpAndSettle();

    expect(uploaded, ['abcdefgh1234']);
    expect(await E2EEBackupSetupService.to.cachedPassphrase(), 'abcdefgh1234');
    expect(StorageService.to.getBool(kE2eeBackupSetupDoneKey), isTrue);

    // 成功弹窗带版本号；点确定后向导页关闭
    expect(find.textContaining('版本 7'), findsOneWidget);
    await tester.tap(find.text(t.common.ok));
    await tester.pumpAndSettle();
    expect(find.byType(E2EEBackupSetupPage), findsNothing);
  });

  testWidgets('随机恢复密钥：格式为 8 组 5 位大写十六进制且双框一致', (tester) async {
    await openPage(tester);
    await tester.tap(find.text(t.common.e2eeUseRecoveryKey));
    await tester.pumpAndSettle();
    expect(find.text(t.common.e2eeRecoveryKeyTitle), findsOneWidget);

    await tester.tap(find.text(t.common.buttonCopy));
    await tester.pumpAndSettle();

    final pwdField = tester.widget<TextField>(
      find.widgetWithText(TextField, t.common.e2eeBackupPwdLabel),
    );
    final confirmField = tester.widget<TextField>(
      find.widgetWithText(TextField, t.common.e2eeBackupConfirmPwdLabel),
    );
    expect(
      RegExp(
        r'^[A-F0-9]{5}(-[A-F0-9]{5}){7}$',
      ).hasMatch(pwdField.controller!.text),
      isTrue,
    );
    expect(confirmField.controller!.text, pwdField.controller!.text);
  });

  testWidgets('上传失败：开放「稍后再说」，点击可离开且完成标记不落', (tester) async {
    await openPage(
      tester,
      override: (pwd) async =>
          const E2EEBackupPutResult(ok: false, versionConflict: true),
    );
    await enterPassword(tester, 'abcdefgh1234');
    // 失败前「稍后再说」不可见（不可跳过）
    expect(find.text(t.common.e2eeBackupSetupLater), findsNothing);

    await tester.tap(find.text(t.common.e2eeBackupSetupSubmit));
    await tester.pumpAndSettle();
    expect(find.text(t.common.e2eeBackupSetupLater), findsOneWidget);
    expect(StorageService.to.getBool(kE2eeBackupSetupDoneKey), isFalse);

    await tester.tap(find.text(t.common.e2eeBackupSetupLater));
    await tester.pumpAndSettle();
    expect(find.byType(E2EEBackupSetupPage), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
