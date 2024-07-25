import 'package:imboy/component/helper/func.dart';
import 'package:sqflite/sqflite.dart';

import 'package:imboy/store/provider/app_version_provider.dart';

class SqliteDdl {
  static Future onUpgrade(Database db, int oldVsn, int newVsn) async {
    iPrint("SqliteService_onUpgrade2 $oldVsn, $newVsn");
    final AppVersionProvider p = AppVersionProvider();
    final List<String> ddl = await p.sqliteUpgradeDdl(
      oldVsn,
      newVsn,
    );
    if (ddl.isEmpty) {
      return;
    }

    for (var ddl1 in ddl) {
      exeDDL(db, ddl1);
    }
  }

  static Future onDowngrade(Database db, int oldVsn, int newVsn) async {
    final AppVersionProvider p = AppVersionProvider();
    final List<String> ddl = await p.sqliteDowngradeDdl(
      oldVsn,
      newVsn,
    );
    if (ddl.isEmpty) {
      return;
    }
    for (var ddl1 in ddl) {
      exeDDL(db, ddl1);
    }
  }

  static Future<void> exeDDL(Database db, String ddl1) async {
    ddl1 = ddl1.trim();
    if (ddl1.isEmpty) {
      return;
    }
    try {
      await db.execute(ddl1);
    } catch (e) {
      iPrint('exeDDL e $ddl1');
      iPrint('exeDDL e ${e.toString()}');
    }
  }
}
