import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = File('tool/bootstrap_local_config.dart').absolute.path;
  final template = File('lib/config/env_local.dart').readAsStringSync();
  late Directory fixture;

  setUp(() async {
    fixture = await Directory.systemTemp.createTemp('imboy-local-config-');
    await Process.run('git', [
      'init',
      '--quiet',
    ], workingDirectory: fixture.path);
    await Directory('${fixture.path}/lib/config').create(recursive: true);
    await File('${fixture.path}/lib/config/env_local.dart')
        .writeAsString(template);
  });

  tearDown(() async => fixture.delete(recursive: true));

  Future<ProcessResult> run([List<String> args = const []]) =>
      Process.run('dart', [script, ...args], workingDirectory: fixture.path);

  test('check reports missing inputs without creating them', () async {
    final result = await run(['--check']);
    expect(result.exitCode, 1);
    expect(File('${fixture.path}/.env.local').existsSync(), isFalse);
    expect(
      File('${fixture.path}/lib/config/env_pro.dart').existsSync(),
      isFalse,
    );
  });

  test(
    'initializes safe defaults and preserves existing config bytes',
    () async {
      final existing = File('${fixture.path}/.env.local');
      await existing.writeAsString('API_BASE_URL=http://127.0.0.1:1234\n');
      final result = await run();
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(
        existing.readAsStringSync(),
        'API_BASE_URL=http://127.0.0.1:1234\n',
      );
      final environment = File('${fixture.path}/.env.pro').readAsStringSync();
      expect(environment, contains('API_BASE_URL=http://127.0.0.1:9800\n'));
      expect(environment, contains('JPUSH_APPKEY=\n'));
      expect(environment, contains('AI_TEST_ENABLED=false\n'));
      final pro = File('${fixture.path}/lib/config/env_pro.dart')
          .readAsStringSync();
      expect(pro, contains("part 'env_pro.g.dart';"));
      expect(pro, contains("path: '.env.pro'"));
      expect(pro, contains('class EnvPro '));
      expect((await run(['--check'])).exitCode, 0);
      expect((await run()).exitCode, 0);
      expect(
        existing.readAsStringSync(),
        'API_BASE_URL=http://127.0.0.1:1234\n',
      );
    },
  );

  test('rejects symlinks before writing any configuration', () async {
    final target = File('${fixture.path}/preserved');
    await target.writeAsString('keep');
    await Link('${fixture.path}/.env.dev').create(target.path);
    final result = await run();
    expect(result.exitCode, 1);
    expect(target.readAsStringSync(), 'keep');
    expect(File('${fixture.path}/.env.pro').existsSync(), isFalse);
  }, skip: Platform.isWindows);

  test(
    'rejects changed template instead of deriving invalid classes',
    () async {
      await File('${fixture.path}/lib/config/env_local.dart').writeAsString(
        template.replaceFirst('class EnvLocal ', 'class RenamedLocal '),
      );
      expect((await run()).exitCode, 1);
      expect(File('${fixture.path}/.env.local').existsSync(), isFalse);
    },
  );
}
