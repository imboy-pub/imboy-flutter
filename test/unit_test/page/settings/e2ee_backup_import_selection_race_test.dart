import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/settings/e2ee_backup_import_page.dart';
import 'package:imboy/store/api/e2ee_backup_api.dart';

final class _PickedFile extends PlatformFile {
  @override
  String get name => 'new.enc';
  @override
  Uri get uri => Uri.file('/synthetic/new.enc');
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Only picker name/path are used in this test');
}

class _SelectionPicker extends FilePickerPlatform {
  _SelectionPicker({this.pending});
  final Future<PlatformFile?>? pending;
  int calls = 0;
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    calls++;
    return pending == null ? _PickedFile() : await pending;
  }
}

void main() {
  for (final fails in [false, true]) {
    testWidgets(
      '关闭恢复页后忽略选择器${fails ? '错误' : '结果'}',
      (tester) => _assertPickerStopsAfterDisposal(tester, fails),
    );
  }
  for (final oldFails in [false, true]) {
    testWidgets(
      '旧文件校验${oldFails ? '失败' : '成功'}不能覆盖新选择',
      (tester) => _assertLatestFileWins(tester, oldFails),
    );
  }
}

Future<void> _assertPickerStopsAfterDisposal(
  WidgetTester tester,
  bool fails,
) async {
  final completion = Completer<PlatformFile?>();
  final picker = _SelectionPicker(pending: completion.future);
  final original = FilePickerPlatform.instance;
  FilePickerPlatform.instance = picker;
  addTearDown(() => FilePickerPlatform.instance = original);
  var verificationCalls = 0;
  await tester.pumpWidget(
    _pickerPage((_) async {
      verificationCalls++;
      return {};
    }),
  );
  await tester.tap(find.text(t.common.e2eeBackupSelectFileHint));
  await tester.pump();
  expect(picker.calls, 1);
  await tester.pumpWidget(
    MaterialApp(
      builder: AppLoading.init(),
      home: const Text('replacement page'),
    ),
  );
  if (fails) {
    completion.completeError(Exception('synthetic picker failure'));
  } else {
    completion.complete(_PickedFile());
  }
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final staleToast = find
      .text(t.common.e2eeBackupErrSelectFile)
      .evaluate()
      .isNotEmpty;
  for (var frame = 0; frame < 100; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(staleToast, isFalse);
  expect(verificationCalls, 0);
  expect(tester.takeException(), isNull);
}

Widget _pickerPage(Future<Map<String, dynamic>> Function(String) verifier) =>
    TranslationProvider(
      child: ProviderScope(
        child: MaterialApp(
          builder: AppLoading.init(),
          home: E2EEBackupImportPage(
            cloudBackupProbe: () async => E2EEBackupInfo(hasBackup: false),
            backupFileVerifier: verifier,
          ),
        ),
      ),
    );

Widget _page(Map<String, Completer<Map<String, dynamic>>> pending) =>
    TranslationProvider(
      child: ProviderScope(
        child: MaterialApp(
          builder: AppLoading.init(),
          home: E2EEBackupImportPage(
            initialFilePath: '/synthetic/old.enc',
            cloudBackupProbe: () async => E2EEBackupInfo(hasBackup: false),
            backupFileVerifier: (path) {
              final result = Completer<Map<String, dynamic>>();
              pending[path] = result;
              return result.future;
            },
          ),
        ),
      ),
    );

Future<void> _assertLatestFileWins(WidgetTester tester, bool oldFails) async {
  final originalPicker = FilePickerPlatform.instance;
  FilePickerPlatform.instance = _SelectionPicker();
  addTearDown(() => FilePickerPlatform.instance = originalPicker);
  final pending = <String, Completer<Map<String, dynamic>>>{};
  await tester.pumpWidget(_page(pending));
  expect(pending.keys, ['/synthetic/old.enc']);
  await tester.tap(find.text('old.enc'));
  await tester.pump();
  expect(pending.keys.toSet(), {'/synthetic/old.enc', '/synthetic/new.enc'});
  pending['/synthetic/new.enc']!.complete({
    'version': 'new-version',
    'algorithm': 'synthetic',
    'file_size': 77,
  });
  await tester.pump();
  await tester.pump();
  expect(find.text('new-version'), findsOneWidget);
  if (oldFails) {
    pending['/synthetic/old.enc']!.completeError(
      ArgumentError('old file invalid'),
    );
  } else {
    pending['/synthetic/old.enc']!.complete({
      'version': 'old-version',
      'algorithm': 'synthetic',
      'file_size': 77,
    });
  }
  for (var frame = 0; frame < 100; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(find.text('new.enc'), findsOneWidget);
  expect(find.text('new-version'), findsOneWidget);
  expect(find.text('old-version'), findsNothing);
  expect(tester.takeException(), isNull);
}
