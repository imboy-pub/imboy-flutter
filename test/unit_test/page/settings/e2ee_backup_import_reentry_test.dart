import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
    expect(path, '/synthetic/backup.enc');
    expect(password, 'SyntheticPassword123!');
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

Widget _page(_ImportProbe probe) => TranslationProvider(
  child: ProviderScope(
    child: MaterialApp(
      builder: AppLoading.init(),
      home: E2EEBackupImportPage(
        initialFilePath: '/synthetic/backup.enc',
        cloudBackupProbe: () async => E2EEBackupInfo(hasBackup: false),
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

Future<VoidCallback> _prepare(WidgetTester tester, _ImportProbe probe) async {
  await tester.pumpWidget(_page(probe));
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
