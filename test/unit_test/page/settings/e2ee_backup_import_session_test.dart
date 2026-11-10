import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:device_info_plus_platform_interface/device_info_plus_platform_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/settings/e2ee_backup_import_page.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/e2ee_backup_api.dart';

const _raceWait = Duration(seconds: 5);

class _DeferredDeviceInfo extends DeviceInfoPlatform {
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<BaseDeviceInfo> deviceInfo() async {
    if (!entered.isCompleted) entered.complete();
    await release.future;
    if (Platform.isLinux) {
      return LinuxDeviceInfo(
        name: 'Synthetic',
        id: 'current-device',
        prettyName: 'Synthetic',
        machineId: 'synthetic-machine',
      );
    }
    return BaseDeviceInfo({
      'computerName': 'Synthetic',
      'hostName': 'Synthetic',
      'arch': 'arm64',
      'model': 'Synthetic',
      'modelName': 'Synthetic',
      'kernelVersion': 'Synthetic',
      'osRelease': 'Synthetic',
      'majorVersion': 1,
      'minorVersion': 0,
      'patchVersion': 0,
      'activeCPUs': 1,
      'memorySize': 1,
      'cpuFrequency': 1,
      'systemGUID': 'current-device',
    });
  }
}

void main() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final secure = <String, String?>{};
  final deviceWrites = <String?>[];
  Future<String?> Function(String key, String? value)? read;

  setUp(() async {
    LocaleSettings.setLocaleRaw('zh-CN');
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: 'restore-A',
      'e2ee_recovery_needed': true,
    });
    await StorageService.init();
    secure.clear();
    deviceWrites.clear();
    read = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final arguments = call.arguments as Map;
          final key = arguments['key'] as String?;
          switch (call.method) {
            case 'read':
              final value = secure[key];
              return read == null ? value : await read!(key!, value);
            case 'write':
              secure[key!] = arguments['value'] as String?;
              if (key == 'e2ee_device_id') deviceWrites.add(secure[key]);
              return null;
            case 'delete':
              secure.remove(key);
              return null;
            default:
              return null;
          }
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> switchToB() async {
    await StorageService.to.setString(Keys.currentUid, 'restore-B');
    secure.addAll({
      'e2ee_private_key': 'B-private',
      'e2ee_public_key': 'B-public',
      'e2ee_key_id': 'B-key',
      'e2ee_device_id': 'B-device',
    });
  }

  void expectBUnchanged(WidgetTester tester) {
    expect(secure['e2ee_private_key'], 'B-private');
    expect(secure['e2ee_public_key'], 'B-public');
    expect(secure['e2ee_device_id'], 'B-device');
    expect(deviceWrites, isEmpty);
    expect(StorageService.to.getBool('e2ee_recovery_needed'), isTrue);
    expect(find.text(t.common.e2eeBackupImportSuccessTitle), findsNothing);
    expect(tester.takeException(), isNull);
  }

  testWidgets('设备 DID 迟到读取不回写新账号密钥或上报旧公钥', (tester) async {
    secure['e2ee_device_id'] = 'A-device';
    final submit = await _prepareImport(tester);
    await tester.runAsync(() async {
      // Create the gate in the same real zone as the session-write queue.
      final entered = Completer<void>(), release = Completer<void>();
      read = (key, value) async {
        if (key == 'e2ee_device_id' && !entered.isCompleted) {
          entered.complete();
          await release.future;
        }
        return value;
      };
      final owner = AccountLocalTaskOwner.capture();
      final submitted = submit();
      try {
        await entered.future.timeout(_raceWait);
        await switchToB();
        release.complete();
        await submitted.timeout(_raceWait);
      } finally {
        if (!release.isCompleted) release.complete();
        final cleanup = AccountLocalTaskRegistry.instance.beginCleanup(owner);
        try {
          await cleanup.stopped.timeout(_raceWait);
        } finally {
          cleanup.release();
          read = null;
        }
      }
    });
    await tester.pump();
    expectBUnchanged(tester);
  });

  testWidgets('设备信息等待期间清理会等待原任务并拒绝迟到 DID 写入', (tester) async {
    final previousDeviceInfo = DeviceInfoPlatform.instance;
    addTearDown(() => DeviceInfoPlatform.instance = previousDeviceInfo);
    final submit = await _prepareImport(tester);
    await tester.runAsync(() async {
      final detail = _DeferredDeviceInfo();
      DeviceInfoPlatform.instance = detail;
      final owner = AccountLocalTaskOwner.capture();
      final submitted = submit();
      AccountLocalTaskCleanup? cleanup;
      try {
        await detail.entered.future.timeout(_raceWait);
        cleanup = AccountLocalTaskRegistry.instance.beginCleanup(owner);
        var drained = false;
        final stopped = cleanup.stopped.then((_) => drained = true);
        await Future<void>.delayed(Duration.zero);
        expect(drained, isFalse);
        await switchToB();
        detail.release.complete();
        await stopped.timeout(_raceWait);
        await submitted.timeout(_raceWait);
        expect(drained, isTrue);
      } finally {
        if (!detail.release.isCompleted) detail.release.complete();
        cleanup ??= AccountLocalTaskRegistry.instance.beginCleanup(owner);
        try {
          await cleanup.stopped.timeout(_raceWait);
        } finally {
          cleanup.release();
        }
      }
    });
    await tester.pump();
    expectBUnchanged(tester);
  });

  testWidgets('在途公钥报告结束前不完成清理，迟到成功不写恢复标记', (tester) async {
    late Completer<void> entered;
    late Completer<bool> release;
    final submit = await _prepareImport(
      tester,
      reporter: (result) {
        expect(result['public_key'], 'A-restored-public');
        entered.complete();
        return release.future;
      },
    );
    await tester.runAsync(() async {
      entered = Completer<void>();
      release = Completer<bool>();
      final owner = AccountLocalTaskOwner.capture();
      final submitted = submit();
      AccountLocalTaskCleanup? cleanup;
      try {
        await entered.future.timeout(_raceWait);
        cleanup = AccountLocalTaskRegistry.instance.beginCleanup(owner);
        var drained = false;
        final stopped = cleanup.stopped.then((_) => drained = true);
        await Future<void>.delayed(Duration.zero);
        expect(drained, isFalse);
        await switchToB();
        release.complete(true);
        await stopped.timeout(_raceWait);
        await submitted.timeout(_raceWait);
        expect(drained, isTrue);
        expect(
          StorageService.to.containsKey(
            E2EELocalBackupService.kLastRestoreMarkerKey,
          ),
          isFalse,
        );
      } finally {
        if (!release.isCompleted) release.complete(false);
        cleanup ??= AccountLocalTaskRegistry.instance.beginCleanup(owner);
        try {
          await cleanup.stopped.timeout(_raceWait);
        } finally {
          cleanup.release();
        }
      }
    });
    await tester.pump();
    expectBUnchanged(tester);
  });
}

Future<Future<void> Function()> _prepareImport(
  WidgetTester tester, {
  Future<bool> Function(Map<String, dynamic>)? reporter,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
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
            backupFileImporter: (_, _, _) async => {
              'private_key': 'A-restored-private',
              'public_key': 'A-restored-public',
              'key_id': 'A-key',
              'device_id': 'backup-source-device',
              'created_at': '2026-01-01T00:00:00Z',
            },
            deviceKeyReporter: reporter,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  final password = tester
      .widgetList<TextField>(find.byType(TextField))
      .singleWhere((field) => field.obscureText);
  await tester.enterText(find.byWidget(password), 'SyntheticPassword123!');
  await tester.pump();
  final action = tester
      .widget<CupertinoButton>(
        find.widgetWithText(CupertinoButton, t.common.e2eeBackupImportBtn),
      )
      .onPressed;
  expect(action, isNotNull);
  return action! as Future<void> Function();
}
