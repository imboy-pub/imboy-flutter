// SQLite 迁移脚本生成器（WP3）
// Generates assets/migrations/{upgrade,downgrade}.sql from the typed
// migration manifest (lib/service/migrations/manifest_all.dart).
//
// 用法 / Usage:
//   dart run tool/generate_sqlite_migrations.dart --check
//     校验仓库内 .sql 与 manifest 生成物一致。
//     退出码 0 = 一致；1 = 漂移（打印 diff 摘要）。
//   dart run tool/generate_sqlite_migrations.dart --output <dir>
//     把生成的 upgrade.sql / downgrade.sql 写入 <dir>（不会改动仓库文件）。
//     退出码 0 = 成功；1 = 写入失败。
//   其他参数：退出码 64。
//
// 单一真源纪律：任何迁移改动都必须修改 manifest 边数据，然后运行
// --output assets/migrations 同步参考文件；直接改 .sql 会被 --check 拒绝。
import 'dart:io';

import 'package:imboy/service/embedded_schema_scripts.dart';

const _usage = '''
Usage:
  dart run tool/generate_sqlite_migrations.dart --check
  dart run tool/generate_sqlite_migrations.dart --output <dir>
Exit codes: 0 ok, 1 drift/write failure, 64 bad args''';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(_usage);
    exit(64);
  }
  switch (args[0]) {
    case '--check':
      _check();
    case '--output':
      if (args.length < 2) {
        stderr.writeln('--output requires a directory argument');
        exit(64);
      }
      _output(args[1]);
    default:
      stderr.writeln(_usage);
      exit(64);
  }
}

void _check() {
  var drift = false;
  for (final entry in {
    'assets/migrations/upgrade.sql': buildUpgradeSqlFromManifest(),
    'assets/migrations/downgrade.sql': buildDowngradeSqlFromManifest(),
  }.entries) {
    final repo = File(entry.key).readAsStringSync();
    if (repo == entry.value) {
      stdout.writeln(
        'OK  ${entry.key} matches manifest (${repo.length} bytes)',
      );
    } else {
      drift = true;
      stderr.writeln(
        'DRIFT ${entry.key}: repo ${repo.length}B vs generated '
        '${entry.value.length}B',
      );
      _printFirstDiff(repo, entry.value);
    }
  }
  exit(drift ? 1 : 0);
}

void _output(String dir) {
  try {
    Directory(dir).createSync(recursive: true);
    File('$dir/upgrade.sql').writeAsStringSync(buildUpgradeSqlFromManifest());
    File(
      '$dir/downgrade.sql',
    ).writeAsStringSync(buildDowngradeSqlFromManifest());
    stdout.writeln('Wrote upgrade.sql & downgrade.sql to $dir');
    exit(0);
  } catch (e) {
    stderr.writeln('Write failed: $e');
    exit(1);
  }
}

void _printFirstDiff(String a, String b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) {
      stderr.writeln('  first diff at byte $i');
      stderr.writeln(
        '  repo     : ...${a.substring(i - 30 < 0 ? 0 : i - 30, i + 30)}...',
      );
      stderr.writeln(
        '  generated: ...${b.substring(i - 30 < 0 ? 0 : i - 30, i + 30)}...',
      );
      return;
    }
  }
  stderr.writeln('  length-only difference (prefix identical)');
}
