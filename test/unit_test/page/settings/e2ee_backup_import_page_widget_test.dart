import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/settings/e2ee_backup_import_page.dart';
import 'package:imboy/service/e2ee_crypto_service.dart';

/// lib/page/settings/e2ee_backup_import_page.dart 的 widget 渲染测试。
///
/// 真机已目击：L8 文件选择器调起、L13 警告卡、L11 密码框禁用、
/// L12 导入按钮置灰（get_ui disabled 属性）、L14 云端恢复卡不存在时静默。
/// 此处用 initialFilePath 注入文件，补 L9（合法文件元信息卡）与
/// L10（非法文件 SnackBar）的确定性断言——文件选择器（documentsui）
/// 无法从外部注入 .enc 文件，深链 query 又不映射 extra。
///
/// 网络隔离：HttpClient 用 IOHttpClientAdapter + _buildHttpClient，
/// flutter test 的 HttpOverrides 禁网 → initState 的 _probeCloudBackup
/// 请求失败被 catch 静默吞掉（L436-438），不会真打生产。
/// packBackupBytes 内 readAll() 平台通道在测试环境抛
/// MissingPluginException 同样被吞，仅备份 RSA 假密钥对。
///
/// 注意：禁用 pumpAndSettle——禁网环境 Dio 请求的失败 Future 可能迟迟
/// 不结算（连接级挂起），pumpAndSettle 会等到 10min 超时。统一用
/// 固定次数的 pump + pump(Duration) 推进虚拟时间。
/// 文件校验（_verifyFile 的 readAsBytes）是真实 IO，在 FakeAsync zone
/// 永不完成，必须用 tester.runAsync 包裹 pump 与等待。
void main() {
  Widget wrap(Widget page) {
    return TranslationProvider(
      child: ProviderScope(child: MaterialApp(home: page)),
    );
  }

  /// runAsync 内 pump 页面并推进几帧，让 postFrameCallback 的
  /// _verifyFile（真实文件 IO）有机会完成。
  ///
  /// 注意：pump(Duration) 只推 fake 时钟、不真实等待。readAsBytes 的
  /// 完成回调须先经真实事件循环到达（fake microtask 队列），再经下一次
  /// pump 的 flushMicrotasks 恢复 await 链——故两次 pump 之间必须真实
  /// 等待（Future.delayed 在 runAsync 的 realAsyncZone 里是真实 timer）。
  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(page);
      await tester.pump(); // postFrameCallback 触发 _verifyFile（IO 发起）
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await tester.pump(); // flush IO 回调 + 渲染 _verifyFile 的 setState 帧
      await tester.pump(const Duration(milliseconds: 100)); // 稳定帧
    });
  }

  /// 构造合法备份文件字节（纯同步，不碰平台通道）。
  ///
  /// 头部布局对齐 E2EELocalBackupService._buildFileHeader 的 32 字节格式：
  /// magic8 + ver2 + algo2 + iter4 + saltLen2 + ivLen2 + tagLen2
  /// + notesLen4 + reserved6。verifyBackupFile 只做 _ensureSizeBounds
  /// （≥77 字节）与 _parseFileHeader（Magic Number + KDF 迭代数 1~1,000,000），
  /// 不解密——故后随 salt16 + iv12 + tag16 + 1 字节密文占位（共 45 字节）
  /// 即可通过校验。
  Uint8List buildValidBackupBytes() {
    final header = Uint8List(32);
    final bd = ByteData.sublistView(header);
    final magicBytes = E2EECryptoService.magicNumber
        .padRight(8, '\x00')
        .codeUnits;
    header.setRange(0, 8, magicBytes);
    bd.setUint16(8, E2EECryptoService.formatVersion);
    bd.setUint16(10, E2EECryptoService.algorithmId);
    bd.setUint32(12, E2EECryptoService.pbkdf2Iterations);
    bd.setUint16(16, E2EECryptoService.saltLength);
    bd.setUint16(18, E2EECryptoService.ivLength);
    bd.setUint16(20, E2EECryptoService.authTagLength);
    // notes_length(offset 22) 与 reserved6 保持 0
    return Uint8List.fromList([...header, ...Uint8List(45)]);
  }

  /// 生成合法备份文件（同步落盘；testWidgets 的 FakeAsync zone 内
  /// 真实异步 IO 永不完成，此处不 await 任何异步）
  File makeValidBackup(Directory dir) {
    final file = File('${dir.path}/valid_backup.enc');
    file.writeAsBytesSync(buildValidBackupBytes());
    return file;
  }

  group('E2EEBackupImportPage 文件校验', () {
    testWidgets('L9 选中合法文件后展示备份元信息卡并启用密码框', (tester) async {
      final tmpDir = Directory.systemTemp.createTempSync('e2ee_widget_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));
      final file = makeValidBackup(tmpDir);

      await pumpPage(
        tester,
        wrap(E2EEBackupImportPage(initialFilePath: file.path)),
      );

      // 元信息卡：标题 + 版本/算法/文件大小行 + 校验通过文案
      expect(find.text(t.common.e2eeBackupInfoTitle), findsOneWidget);
      expect(find.text(t.common.e2eeBackupVersionLabel), findsOneWidget);
      expect(find.text(t.common.e2eeBackupAlgorithmLabel), findsOneWidget);
      expect(find.text(t.common.e2eeBackupFileSizeLabel), findsOneWidget);
      expect(find.text(t.common.e2eeBackupFileValid), findsOneWidget);

      // 密码框启用（L11 的启用侧）
      final pwdField = tester
          .widgetList<TextField>(find.byType(TextField))
          .where((w) => w.obscureText)
          .first;
      expect(pwdField.enabled, isTrue, reason: '选中合法文件后密码框应启用');
    });

    testWidgets('L9 选中合法文件但密码为空时导入按钮保持禁用', (tester) async {
      final tmpDir = Directory.systemTemp.createTempSync('e2ee_widget_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));
      final file = makeValidBackup(tmpDir);

      await pumpPage(
        tester,
        wrap(E2EEBackupImportPage(initialFilePath: file.path)),
      );

      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, t.common.e2eeBackupImportBtn),
      );
      expect(btn.onPressed, isNull, reason: '密码为空时导入按钮应置灰禁用');
    });

    testWidgets('L10 文件格式非法时提示校验失败且不展示元信息卡', (tester) async {
      final tmpDir = Directory.systemTemp.createTempSync('e2ee_widget_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));
      final fake = File('${tmpDir.path}/fake.enc');
      fake.writeAsBytesSync('this is not a real e2ee backup file'.codeUnits);

      await pumpPage(
        tester,
        wrap(E2EEBackupImportPage(initialFilePath: fake.path)),
      );

      // SnackBar 校验失败提示
      expect(
        find.text(t.common.e2eeBackupErrValidateFailed),
        findsOneWidget,
        reason: '非法文件应弹出校验失败提示',
      );
      // 无元信息卡（_backupInfo 置 null）
      expect(find.text(t.common.e2eeBackupInfoTitle), findsNothing);
      // 密码框保持禁用（_backupInfo == null）
      final pwdField = tester
          .widgetList<TextField>(find.byType(TextField))
          .where((w) => w.obscureText)
          .first;
      expect(pwdField.enabled, isFalse, reason: '校验失败后密码框应保持禁用');
    });

    testWidgets('L11 未选文件时密码框禁用、导入按钮禁用', (tester) async {
      await pumpPage(tester, wrap(const E2EEBackupImportPage()));

      final pwdField = tester
          .widgetList<TextField>(find.byType(TextField))
          .where((w) => w.obscureText)
          .first;
      expect(pwdField.enabled, isFalse, reason: '未选合法文件时密码框应禁用');

      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, t.common.e2eeBackupImportBtn),
      );
      expect(btn.onPressed, isNull, reason: '无文件时导入按钮应禁用');
    });

    testWidgets('L14 云端备份探测失败时按无备份静默处理（无恢复卡）', (tester) async {
      await pumpPage(tester, wrap(const E2EEBackupImportPage()));

      // 测试环境禁网 → info() 抛异常 → catch 静默 → 不显示云端恢复卡
      expect(find.text(t.common.e2eeBackupCloudRestoreTitle), findsNothing);
    });

    testWidgets('L13 警告卡片始终展示覆盖密钥风险提示', (tester) async {
      await tester.pumpWidget(wrap(const E2EEBackupImportPage()));
      await tester.pump();

      expect(find.text(t.common.e2eeBackupImportGuide), findsOneWidget);
      expect(find.text(t.common.e2eeBackupImportReplaceKey), findsOneWidget);
      expect(find.text(t.common.e2eeBackupImportTrustedSource), findsOneWidget);
    });
  });
}
