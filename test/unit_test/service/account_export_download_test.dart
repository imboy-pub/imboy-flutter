import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/account_export_download.dart';
import 'package:imboy/service/account_export_download_native.dart' as native;

/// FL-13 账号导出下载平台适配（VM 编译＝native 实现）：
/// 正常（写入注入目录、内容逐字节一致）、负例（文件名穿越、空 payload、
/// 落点目录不可用）与 Web 共享形状契约（viaBrowserDownload 语义）。
void main() {
  group('sanitizeAccountExportFileName', () {
    test('保留合法名与扩展名', () {
      expect(
        native.sanitizeAccountExportFileName('imboy_data_1710000000000.json'),
        'imboy_data_1710000000000.json',
      );
    });

    test('剔除路径穿越与绝对路径前缀（含反斜杠）', () {
      expect(
        native.sanitizeAccountExportFileName('../../etc/imboy.json'),
        'imboy.json',
      );
      expect(
        native.sanitizeAccountExportFileName('/tmp/x/evil.json'),
        'evil.json',
      );
      expect(
        native.sanitizeAccountExportFileName(r'C:\Users\a\data.json'),
        'data.json',
      );
    });

    test('空/空白/仅点号/控制字符回退默认名', () {
      expect(
        native.sanitizeAccountExportFileName(''),
        'imboy_data_export.json',
      );
      expect(
        native.sanitizeAccountExportFileName('   '),
        'imboy_data_export.json',
      );
      expect(
        native.sanitizeAccountExportFileName('..'),
        'imboy_data_export.json',
      );
      expect(
        native.sanitizeAccountExportFileName('a\x00b\tc.json'),
        'abc.json',
      );
    });
  });

  group('saveAccountExportJson（VM＝native 实现，真实文件 IO）', () {
    late Directory base;
    setUp(() {
      base = Directory.systemTemp.createTempSync('fl13_export_test');
    });
    tearDown(() {
      if (base.existsSync()) {
        base.deleteSync(recursive: true);
      }
    });

    test('正常：经门面写入注入目录，内容逐字节一致，返回绝对路径', () async {
      final payload = const JsonEncoder.withIndent('  ').convert({
        'profile': {'account': 'u1'},
        'messages': <String>['m-1'],
      });
      final result = await saveAccountExportJson(
        fileName: 'imboy_data_1710000000000.json',
        jsonContent: payload,
        intoDirectoryPath: base.path,
      );
      expect(result.viaBrowserDownload, isFalse);
      final file = File(result.location);
      expect(file.parent.path, base.path);
      // 导出内容原样落盘：无额外字段/令牌注入（FL-13:LOCAL:01）。
      expect(file.readAsStringSync(), payload);
    });

    test('负例：文件名穿越被清洗，落点不逃出注入目录', () async {
      final result = await saveAccountExportJson(
        fileName: '../escape.json',
        jsonContent: '{}',
        intoDirectoryPath: base.path,
      );
      final file = File(result.location);
      expect(file.parent.path, base.path);
      expect(file.existsSync(), isTrue);
      expect(
        File('${base.parent.path}${Platform.pathSeparator}escape.json')
            .existsSync(),
        isFalse,
      );
    });

    test('负例：空 payload 显式失败，不产出空导出文件', () async {
      await expectLater(
        saveAccountExportJson(
          fileName: 'empty.json',
          jsonContent: '',
          intoDirectoryPath: base.path,
        ),
        throwsArgumentError,
      );
      expect(base.listSync(), isEmpty);
    });

    test('负例：落点被文件占用时错误如实上抛（fail-closed）', () async {
      final blocker = File('${base.path}/blocker')..writeAsStringSync('x');
      await expectLater(
        saveAccountExportJson(
          fileName: 'x.json',
          jsonContent: '{}',
          intoDirectoryPath: blocker.path,
        ),
        throwsA(anyOf(isA<FileSystemException>(), isA<ArgumentError>())),
      );
    });

    test('目录缺省时回退系统临时目录并可写入（Web 断连降级路径形状不变）', () async {
      final result = await saveAccountExportJson(
        fileName: 'imboy_default_dir.json',
        jsonContent: '{"ok":true}',
      );
      expect(result.viaBrowserDownload, isFalse);
      expect(File(result.location).existsSync(), isTrue);
    });
  });

  test('两实现共享形状：结果类型字段与清洗函数在门面与 native 一致', () {
    // VM 下门面条件导入解析到 native；同参调用同一函数。
    expect(
      identical(saveAccountExportJson, native.saveAccountExportJson),
      isTrue,
    );
    const result = native.AccountExportDownloadResult(
      location: 'x.json',
      viaBrowserDownload: false,
    );
    expect(result.location, 'x.json');
    expect(result.viaBrowserDownload, isFalse);
  });
}
