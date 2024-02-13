import 'package:sqflite/sqflite.dart';

import 'package:imboy/store/provider/app_version_provider.dart';

class SqliteDdl {
  static Future onUpgrade(Database db, int oldVsn, int newVsn) async {
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
    if (ddl1.isEmpty) {
      return;
    }
    await db.execute(ddl1);
  }
}
