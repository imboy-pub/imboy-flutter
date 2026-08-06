import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';

/// E2EE-015 纵深防御：SqliteService.db 句柄按 uid 隔离。
///
/// 修复前 getter 仅按 isOpen 复用句柄，若 logout 未 close（purge 失败旁路），
/// 换号后新账号会写进上一账号仍打开的 SQLCipher 库（安全审查 CRITICAL）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    SqliteService.setDbForTest(null);
  });

  Future<Database> openMem() =>
      databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

  test('uid 一致时复用已打开句柄', () async {
    await StorageService.to.setString(Keys.currentUid, 'uidA');
    final injected = await openMem();
    SqliteService.setDbForTest(injected);

    final got = await SqliteService.to.db;
    expect(got, same(injected));
    expect(injected.isOpen, isTrue);
    await injected.close();
  });

  test('uid 漂移时关闭旧账号句柄，不复用', () async {
    await StorageService.to.setString(Keys.currentUid, 'uidA');
    final oldHandle = await openMem();
    SqliteService.setDbForTest(oldHandle);

    // 模拟 logout 未 close 后直接换号
    await StorageService.to.setString(Keys.currentUid, 'uidB');
    // 漂移检测在重开之前先 close 旧句柄；宿主环境无 sqlcipher 插件，
    // 重开会抛 MissingPluginException——吞掉即可，关键断言是旧句柄已关、未复用。
    Object? got = oldHandle;
    try {
      got = await SqliteService.to.db;
    } on Object {
      got = null;
    }

    expect(oldHandle.isOpen, isFalse, reason: '旧账号句柄必须被关闭');
    expect(got, isNot(same(oldHandle)), reason: '绝不把旧句柄交给新账号');
  });
}
