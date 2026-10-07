import 'dart:io';

const _profiles = ['pro', 'dev', 'local', 'local_home', 'local_office'];

// Public local-development values only. Never use these for a deployment.
const _localEnvironment = '''
API_BASE_URL=http://127.0.0.1:9800
WS_URL=ws://127.0.0.1:9800/ws
SOLIDIFIED_KEY=00000000000000000000000000000000
SOLIDIFIED_KEY_IV=0000000000000000
IOS_APP_ID=
A_MAP_IOS_KEY=
A_MAP_ANDROID_KEY=
A_MAP_WEBS_KEY=
JPUSH_APPKEY=
ALIPAY_APP_ID=
ALIPAY_UNIVERSAL_LINK=
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
AI_TEST_ENABLED=false
''';

Future<void> main(List<String> args) async {
  if (args.any((arg) => arg != '--check') || args.length > 1) {
    stderr.writeln('Usage: dart tool/bootstrap_local_config.dart [--check]');
    exitCode = 64;
    return;
  }
  try {
    await bootstrap(checkOnly: args.contains('--check'));
  } on FileSystemException {
    stderr.writeln(
      'Local configuration preparation failed; check file access.',
    );
    exitCode = 1;
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}

Future<void> bootstrap({required bool checkOnly}) async {
  final root = Directory.current.resolveSymbolicLinksSync();
  final git = await Process.run('git', ['rev-parse', '--show-toplevel']);
  if (git.exitCode != 0 || git.stdout.toString().trim() != root) {
    throw StateError('Run from the imboyapp Git repository root.');
  }
  final inputs = <String, String>{
    for (final profile in _profiles) '.env.$profile': _localEnvironment,
  };
  final template = await File('lib/config/env_local.dart').readAsString();
  for (final entry in {'pro': 'EnvPro', 'dev': 'EnvDev'}.entries) {
    inputs['lib/config/env_${entry.key}.dart'] = _derive(template, entry);
  }
  for (final path in inputs.keys) {
    _checkPath(path);
  }
  final missing = inputs.keys
      .where((path) => !File(path).existsSync())
      .toList();
  if (checkOnly) {
    for (final path in missing) {
      stderr.writeln('Missing local configuration: $path');
    }
    exitCode = missing.isEmpty ? 0 : 1;
    return;
  }
  for (final path in missing) {
    await File(path).writeAsString(inputs[path]!);
    if (path.startsWith('.env.') && !Platform.isWindows) {
      final permission = await Process.run('chmod', ['600', path]);
      if (permission.exitCode != 0) {
        throw StateError('Could not restrict local configuration permissions.');
      }
    }
    stdout.writeln('Created $path');
  }
  stdout.writeln(
    'Existing configuration preserved. Generated files are ignored.',
  );
  stdout.writeln(
    'Local placeholders only: configure the backend signing values '
    'before login, then run dart run build_runner build.',
  );
}

String _derive(String template, MapEntry<String, String> profile) {
  final replacements = {
    "part 'env_local.g.dart';": "part 'env_${profile.key}.g.dart';",
    "path: '.env.local'": "path: '.env.${profile.key}'",
    'class EnvLocal ': 'class ${profile.value} ',
  };
  for (final entry in replacements.entries) {
    if (entry.key.allMatches(template).length != 1) {
      throw StateError(
        'Environment template changed; review bootstrap mappings.',
      );
    }
    template = template.replaceFirst(entry.key, entry.value);
  }
  return template;
}

void _checkPath(String path) {
  final parts = path.split('/');
  for (var index = 1; index <= parts.length; index++) {
    final candidate = parts.take(index).join('/');
    final type = FileSystemEntity.typeSync(candidate, followLinks: false);
    if (type == FileSystemEntityType.link ||
        (index < parts.length && type != FileSystemEntityType.directory) ||
        (index == parts.length &&
            type != FileSystemEntityType.notFound &&
            type != FileSystemEntityType.file)) {
      throw StateError('Refusing unsupported configuration path: $candidate');
    }
  }
}
