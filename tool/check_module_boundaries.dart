import 'dart:io';

final _directivePattern = RegExp(r'''^\s*(import|export)\s+['"]([^'"]+)['"]''');
const _legacyDomainRoots = <String, List<String>>{
  'identity': ['lib/page/passport/'],
  'social_graph': [
    'lib/page/contact/',
    'lib/page/mention/',
    'lib/page/mine/user_collect/',
    'lib/service/mention_service.dart',
  ],
  'group_collab': [
    'lib/page/group/',
    'lib/service/group_schedule_service.dart',
    'lib/service/group_task_service.dart',
    'lib/service/group_vote_service.dart',
  ],
  'channel_content': ['lib/page/channel/', 'lib/service/channel_service.dart'],
  'moment_social': ['lib/page/moment/'],
  'security_privacy': [
    'lib/page/settings/e2ee_',
    'lib/service/e2ee/',
    'lib/service/e2ee_',
  ],
  'ops_governance': [
    'lib/page/mine/feedback/',
    'lib/page/single/upgrade.dart',
    'lib/service/notification.dart',
    'lib/service/notification_provider.dart',
  ],
};

void main() {
  final repoRoot = Directory.current.absolute;
  final violations = <String>[];

  for (final root in ['lib', 'test']) {
    final directory = Directory('${repoRoot.path}/$root');
    if (!directory.existsSync()) {
      continue;
    }

    for (final entity in directory.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final importerRel = _normalizeRepoPath(
        _relativePath(repoRoot.path, entity.path),
      );
      final importerDomain = _moduleDomain(importerRel);
      final lines = entity.readAsLinesSync();

      for (var i = 0; i < lines.length; i++) {
        final match = _directivePattern.firstMatch(lines[i]);
        if (match == null) {
          continue;
        }

        final uri = match.group(2)!;
        final targetRel = _resolveModuleTarget(repoRoot, importerRel, uri);
        if (targetRel == null) {
          continue;
        }

        final targetDomain = _moduleDomain(targetRel);
        if (targetDomain == null) {
          continue;
        }

        final isSameDomainInternal =
            importerDomain != null && importerDomain == targetDomain;
        final isPublicEntry =
            targetRel == 'lib/modules/$targetDomain/public.dart';

        if (isSameDomainInternal || isPublicEntry) {
          continue;
        }

        violations.add(
          '$importerRel:${i + 1}: `$uri` bypasses the `$targetDomain` public entry; '
          'use `package:imboy/modules/$targetDomain/public.dart` instead.',
        );
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln(
      'Module boundary check passed: no cross-domain module internal imports found.',
    );
    return;
  }

  stderr.writeln('Module boundary violations detected:');
  for (final violation in violations) {
    stderr.writeln('- $violation');
  }
  exitCode = 1;
}

String? _resolveModuleTarget(
  Directory repoRoot,
  String importerRel,
  String uri,
) {
  if (uri.startsWith('package:imboy/modules/')) {
    return _normalizeRepoPath('lib/${uri.substring('package:imboy/'.length)}');
  }

  if (uri.startsWith('package:')) {
    return null;
  }

  if (!uri.startsWith('./') && !uri.startsWith('../')) {
    return null;
  }

  final importerUri = File('${repoRoot.path}/$importerRel').uri;
  final resolvedUri = importerUri.resolve(uri);
  final resolvedPath = _normalizeFsPath(resolvedUri.toFilePath());
  final repoPath = _normalizeFsPath(repoRoot.path);
  if (!resolvedPath.startsWith('$repoPath/')) {
    return null;
  }

  final repoRel = resolvedPath.substring(repoPath.length + 1);
  return repoRel.startsWith('lib/modules/') ? repoRel : null;
}

String? _moduleDomain(String repoRel) {
  final normalized = _normalizeRepoPath(repoRel);
  final parts = normalized.split('/');
  if (parts.length < 4 || parts[0] != 'lib' || parts[1] != 'modules') {
    for (final entry in _legacyDomainRoots.entries) {
      for (final root in entry.value) {
        if (normalized.startsWith(root)) {
          return entry.key;
        }
      }
    }
    return null;
  }
  return parts[2];
}

String _relativePath(String rootPath, String filePath) {
  final normalizedRoot = _normalizeFsPath(rootPath);
  final normalizedFile = _normalizeFsPath(filePath);
  if (normalizedFile == normalizedRoot) {
    return '';
  }
  return normalizedFile.substring(normalizedRoot.length + 1);
}

String _normalizeRepoPath(String path) => _normalizeFsPath(path);

String _normalizeFsPath(String path) => path.replaceAll('\\', '/');
