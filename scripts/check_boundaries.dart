// Boundary guard: lib/modules/** and lib/page/** must not import third-party packages directly.
// Allowed: dart:*, flutter*, package:imboy/*
// Run: dart scripts/check_boundaries.dart
import 'dart:io';

const _restrictedDirs = ['lib/modules', 'lib/page'];

// Allowed import prefixes (matched against the full import string content)
const _allowedPkgPrefixes = [
  'package:imboy/',
  'package:flutter',
  'package:flutter_localizations/',
];

void main() {
  var violations = 0;
  final cwd = Directory.current.path;

  for (final dirPath in _restrictedDirs) {
    final dir = Directory('$cwd/$dirPath');
    if (!dir.existsSync()) continue;

    final dartFiles = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (!line.startsWith("import '") && !line.startsWith('import "'))
          continue;

        // Only check package: imports (skip dart:, relative, and imboy internal)
        final pkgMatch = RegExp(
          r'''import ['"]([^'"]+)['"]''',
        ).firstMatch(line);
        if (pkgMatch == null) continue;
        final importPath = pkgMatch.group(1)!;

        // Allow dart: built-ins and relative imports
        if (!importPath.startsWith('package:')) continue;

        // Check against allowed prefixes
        final allowed = _allowedPkgPrefixes.any(importPath.startsWith);
        if (!allowed) {
          final rel = file.path.replaceFirst('$cwd/', '');
          stderr.writeln('VIOLATION $rel:${i + 1}: $line');
          violations++;
        }
      }
    }
  }

  if (violations > 0) {
    stderr.writeln('\n$violations boundary violation(s) found.');
    exit(1);
  }
  stdout.writeln('Boundary check passed (0 violations).');
}
