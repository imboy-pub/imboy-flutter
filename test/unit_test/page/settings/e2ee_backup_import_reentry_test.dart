import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/settings/e2ee_backup_import_page.dart';
import 'package:imboy/store/api/e2ee_backup_api.dart';

class _ImportProbe {
  final pending = <Completer<Map<String, dynamic>>>[];
  Future<Map<String, dynamic>> call(
    String path,
    String password,
    String? account,
  ) {
    expectSync(path, '/synthetic/backup.enc');
    expectSync(password, 'SyntheticPassword123!');
    final completion = Completer<Map<String, dynamic>>();
    pending.add(completion);
    return completion.future;
  }

  void failPending() {
    for (final completion in pending) {
      if (!completion.isCompleted) {
        completion.completeError(ArgumentError('synthetic failure'));
      }
    }
  }
}

Widget _page(_ImportProbe probe, {_ImportProbe? cloud}) => TranslationProvider(
  child: ProviderScope(
    child: MaterialApp(
      builder: AppLoading.init(),
      home: E2EEBackupImportPage(
        initialFilePath: '/synthetic/backup.enc',
        cloudBackupProbe: () async => E2EEBackupInfo(hasBackup: cloud != null),
        cloudBackupRestorer: cloud == null
            ? null
            : (password, account) =>
                  cloud.call('/synthetic/backup.enc', password, account),
        backupFileVerifier: (_) async => {
          'version': 'synthetic',
          'algorithm': 'test',
          'file_size': 77,
        },
        backupFileImporter: probe.call,
      ),
    ),
  ),
);

Future<VoidCallback> _prepare(
  WidgetTester tester,
  _ImportProbe probe, {
  _ImportProbe? cloud,
}) async {
  await tester.pumpWidget(_page(probe, cloud: cloud));
  await tester.pump();
  await tester.pump();
  final password = tester
      .widgetList<TextField>(find.byType(TextField))
      .singleWhere((field) => field.obscureText);
  await tester.enterText(find.byWidget(password), 'SyntheticPassword123!');
  await tester.pump();
  return tester
      .widget<CupertinoButton>(
        find.widgetWithText(CupertinoButton, t.common.e2eeBackupImportBtn),
      )
      .onPressed!;
}

Future<void> _finish(WidgetTester tester, _ImportProbe probe) async {
  probe.failPending();
  for (var frame = 0; frame < 100; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('云端口令错误提示且不写密钥，失败后可重试', (tester) async {
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var writes = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'write') writes++;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final local = _ImportProbe(), cloud = _ImportProbe();
    await _prepare(tester, local, cloud: cloud);
    await _startCloudRestore(tester);
    expect(cloud.pending.length, 1);
    cloud.pending.single.completeError(ArgumentError('wrong password'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(t.common.e2eeBackupErrCloudPwd), findsOneWidget);
    expect(writes, 0);
    expect(local.pending, isEmpty);
    expect(find.text(t.common.e2eeBackupImportSuccessTitle), findsNothing);
    await _finish(tester, cloud);
    await _startCloudRestore(tester);
    expect(cloud.pending.length, 2);
    await _finish(tester, cloud);
    expect(writes, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('云端确认期间阻止缓存的本地导入回调，取消后可导入', (tester) async {
    final local = _ImportProbe(), cloud = _ImportProbe();
    final localAction = await _prepare(tester, local, cloud: cloud);
    _cloudAction(tester)();
    localAction();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final callsDuringPrompt = local.pending.length;
    await _finish(tester, local);
    await _cancelCloudPrompts(tester);
    final reopenedAction = tester
        .widget<CupertinoButton>(
          find.widgetWithText(CupertinoButton, t.common.e2eeBackupImportBtn),
        )
        .onPressed;
    expect(reopenedAction, isNotNull);
    reopenedAction!();
    await _finish(tester, local);
    expect(callsDuringPrompt, 0);
    expect(local.pending.length, 1);
    expect(cloud.pending, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('同一帧重复云端恢复只打开一个确认框', (tester) async {
    final local = _ImportProbe(), cloud = _ImportProbe();
    await _prepare(tester, local, cloud: cloud);
    final action = _cloudAction(tester);
    action();
    action();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final count = find
        .byType(CupertinoAlertDialog, skipOffstage: false)
        .evaluate()
        .length;
    await _cancelCloudPrompts(tester);
    expect(count, 1);
    expect(cloud.pending, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('取消云端恢复确认后可以重新打开', (tester) async {
    final local = _ImportProbe(), cloud = _ImportProbe();
    await _prepare(tester, local, cloud: cloud);
    for (var attempt = 0; attempt < 2; attempt++) {
      _cloudAction(tester)();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await _cancelCloudPrompts(tester);
    }
    expect(cloud.pending, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    '云端解密等待期间关闭页面不开始写入恢复密钥',
    (tester) => _assertNoLateKeyWrites(tester, cloudRestore: true),
  );
  testWidgets('本地恢复等待期间不能弹出云端恢复确认框', _assertLocalBlocksCloud);
  testWidgets('云端恢复等待期间不能启动本地恢复', _assertCloudBlocksLocal);
  testWidgets('解密等待期间关闭页面不开始写入恢复密钥', _assertNoLateKeyWrites);
  testWidgets('同一帧重复导入只启动一次解密', (tester) async {
    final probe = _ImportProbe();
    final action = await _prepare(tester, probe);
    action();
    action();
    await tester.pump();
    final callsWhilePending = probe.pending.length;
    await _finish(tester, probe);
    expect(callsWhilePending, 1);
    expect(probe.pending.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('导入失败后仍可再次发起导入', (tester) async {
    final probe = _ImportProbe();
    (await _prepare(tester, probe))();
    await _finish(tester, probe);
    final action = tester
        .widget<CupertinoButton>(
          find.widgetWithText(CupertinoButton, t.common.e2eeBackupImportBtn),
        )
        .onPressed!;
    action();
    await _finish(tester, probe);
    expect(probe.pending.length, 2);
    expect(tester.takeException(), isNull);
  });
}

VoidCallback _cloudAction(WidgetTester tester) => tester
    .widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, t.common.e2eeBackupCloudRestoreBtn),
    )
    .onPressed!;

Future<void> _assertLocalBlocksCloud(WidgetTester tester) async {
  final local = _ImportProbe(), cloud = _ImportProbe();
  final localAction = await _prepare(tester, local, cloud: cloud);
  final cloudAction = _cloudAction(tester);
  localAction();
  cloudAction();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  final dialogVisible = find.byType(CupertinoAlertDialog).evaluate().isNotEmpty;
  if (dialogVisible) {
    await tester.tap(
      find.widgetWithText(CupertinoDialogAction, t.common.buttonCancel),
    );
    await tester.pump();
  }
  await _finish(tester, local);
  expect(dialogVisible, isFalse);
  expect(cloud.pending, isEmpty);
  expect(tester.takeException(), isNull);
}

Future<void> _assertCloudBlocksLocal(WidgetTester tester) async {
  final local = _ImportProbe(), cloud = _ImportProbe();
  final localAction = await _prepare(tester, local, cloud: cloud);
  await _startCloudRestore(tester);
  expect(cloud.pending.length, 1);
  localAction();
  await tester.pump();
  final localCalls = local.pending.length;
  await _finish(tester, cloud);
  await _finish(tester, local);
  expect(localCalls, 0);
  expect(tester.takeException(), isNull);
}

Future<void> _startCloudRestore(WidgetTester tester) async {
  _cloudAction(tester)();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.enterText(
    find.byType(CupertinoTextField),
    'SyntheticPassword123!',
  );
  await tester.tap(
    find.widgetWithText(
      CupertinoDialogAction,
      t.common.e2eeBackupCloudRestoreBtn,
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _assertNoLateKeyWrites(
  WidgetTester tester, {
  bool cloudRestore = false,
}) async {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var writes = 0;
  messenger.setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'write') {
      writes++;
      // 记录首次写入意图即中止，禁止继续后续恢复/设备回写流程。
      throw PlatformException(code: 'synthetic-write-stop');
    }
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  final probe = _ImportProbe();
  final localAction = await _prepare(
    tester,
    probe,
    cloud: cloudRestore ? probe : null,
  );
  if (cloudRestore) {
    await _startCloudRestore(tester);
  } else {
    localAction();
  }
  expect(probe.pending.length, 1);
  await tester.pumpWidget(const SizedBox.shrink());
  probe.pending.single.complete({
    'private_key': 'SYNTHETIC_PRIVATE',
    'public_key': 'SYNTHETIC_PUBLIC',
    'key_id': 'synthetic-key',
  });
  for (var frame = 0; frame < 100; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(writes, 0);
  expect(tester.takeException(), isNull);
}

Future<void> _cancelCloudPrompts(WidgetTester tester) async {
  for (var dialog = 0; dialog < 3; dialog++) {
    final cancel = find.widgetWithText(
      CupertinoDialogAction,
      t.common.buttonCancel,
    );
    if (cancel.evaluate().isEmpty) return;
    await tester.tap(cancel.last);
    await tester.pumpAndSettle();
  }
}
