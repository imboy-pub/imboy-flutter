import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

const _baselinePath = 'scripts/quality/riverpod_lifecycle_baseline.txt';

void main(List<String> args) {
  final update = args.length == 1 && args.single == '--update-baseline';
  if (args.isNotEmpty && !update) {
    stderr.writeln(
      'usage: dart run tool/check_riverpod_lifecycle.dart [--update-baseline]',
    );
    exitCode = 64;
    return;
  }

  final current = _implicitRiverpodDeclarations();
  if (update) {
    final entries = current.toList()..sort();
    File(_baselinePath).writeAsStringSync(
      '# Implicit autoDispose @riverpod declaration baseline; entries may only be removed.\n'
      '${entries.join('\n')}\n',
    );
    stdout.writeln('Updated $_baselinePath (${current.length} entries).');
    return;
  }

  final baselineFile = File(_baselinePath);
  if (!baselineFile.existsSync()) {
    stderr.writeln('BLOCKED: missing $_baselinePath');
    exitCode = 2;
    return;
  }
  final baseline = baselineFile
      .readAsLinesSync()
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toSet();
  final regressions = current.difference(baseline).toList()..sort();
  final resolved = baseline.difference(current).toList()..sort();

  if (regressions.isNotEmpty || resolved.isNotEmpty) {
    stderr.writeln(
      'Riverpod lifecycle gate failed: new declarations must declare '
      '@Riverpod(keepAlive: true|false), and resolved entries must be removed '
      'with --update-baseline.',
    );
    for (final entry in regressions) {
      stderr.writeln('- $entry');
    }
    if (resolved.isNotEmpty) stderr.writeln('Resolved baseline entries:');
    for (final entry in resolved) {
      stderr.writeln('- $entry');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Riverpod lifecycle gate passed: ${current.length} baseline entries remain.',
  );
}

Set<String> _implicitRiverpodDeclarations() {
  final lib = Directory('lib');
  if (!lib.existsSync()) {
    stderr.writeln('BLOCKED: lib/ not found; run from the repository root');
    exit(2);
  }

  final findings = <String>{};
  for (final entity in lib.listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (_isGenerated(entity.path)) continue;

    final unit = parseString(
      content: entity.readAsStringSync(),
      path: entity.path,
      throwIfDiagnostics: false,
    ).unit;
    final prefixes = _riverpodImportPrefixes(unit);
    if (prefixes.isEmpty) continue;
    final path = entity.path.replaceAll('\\', '/');
    for (final declaration in unit.declarations) {
      final (kind, name, metadata) = switch (declaration) {
        ClassDeclaration() => (
          'class',
          declaration.namePart.typeName.lexeme,
          declaration.metadata,
        ),
        FunctionDeclaration() => (
          'function',
          declaration.name.lexeme,
          declaration.metadata,
        ),
        _ => ('', '', const <Annotation>[]),
      };
      if (metadata.any(
        (annotation) => _isImplicitRiverpod(annotation, prefixes),
      )) {
        findings.add('$path:$kind:$name');
      }
    }
  }
  return findings;
}

Set<String> _riverpodImportPrefixes(CompilationUnit unit) => unit.directives
    .whereType<ImportDirective>()
    .where(
      (directive) =>
          directive.uri.stringValue ==
          'package:riverpod_annotation/riverpod_annotation.dart',
    )
    .map((directive) => directive.prefix?.name ?? '')
    .toSet();

bool _isImplicitRiverpod(Annotation annotation, Set<String> prefixes) {
  final name = annotation.name.toSource();
  final matched = prefixes.any(
    (prefix) =>
        name == (prefix.isEmpty ? 'riverpod' : '$prefix.riverpod') ||
        name == (prefix.isEmpty ? 'Riverpod' : '$prefix.Riverpod'),
  );
  if (!matched) return false;
  if (name.endsWith('riverpod')) return true;

  final arguments = annotation.arguments;
  if (arguments == null) return true;
  return !arguments.arguments.whereType<NamedArgument>().any(
    (argument) => argument.name.lexeme == 'keepAlive',
  );
}

bool _isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.gr.dart') ||
    path.endsWith('.pb.dart') ||
    path.endsWith('.pbenum.dart') ||
    path.endsWith('.pbjson.dart') ||
    path.endsWith('.pbserver.dart');
