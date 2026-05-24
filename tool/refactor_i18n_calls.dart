import 'dart:io';
import 'package:yaml/yaml.dart';

void main() async {
  final zhCnDir = Directory('assets/i18n/zh-CN');
  if (!zhCnDir.existsSync()) return;

  final keyMap = <String, String>{};
  final files = zhCnDir.listSync().whereType<File>().toList();
  files.sort((a, b) {
    final na = a.uri.pathSegments.last.split('.').first;
    final nb = b.uri.pathSegments.last.split('.').first;
    if (na == 'common' || na == 'main') return 1;
    if (nb == 'common' || nb == 'main') return -1;
    return 0;
  });

  for (final file in files) {
    final ns = file.uri.pathSegments.last.split('.').first;
    try {
      final yaml = loadYaml(file.readAsStringSync());
      if (yaml is Map) {
        for (final key in yaml.keys) {
          String keyStr = key.toString();
          if (keyStr.contains('(')) keyStr = keyStr.split('(').first;
          keyMap[keyStr] = ns;
        }
      }
    } catch (e) {}
  }

  final libDir = Directory('lib');
  final dartFiles = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

  print('Starting refined surgical refactor of ${dartFiles.length} files...');

  final safePattern = RegExp(r'\b(context\.t|AppStrings\.of\(context\))\.(\w+)\b');
  
  // Matches t.key only if not followed by '(' (to avoid method calls on unrelated objects like Timer)
  // t.key(...) for parameterized translations is handled separately via keyMap lookup.
  
  int updatedCount = 0;
  for (final file in dartFiles) {
    if (file.path.contains('tool/')) continue;
    if (file.path.endsWith('strings.g.dart')) continue;
    
    String content = file.readAsStringSync();
    String original = content;

    // 1. Safe replacements
    content = content.replaceAllMapped(safePattern, (match) {
      final prefix = match.group(1);
      final key = match.group(2);
      if (keyMap.containsKey(key)) {
        return '$prefix.${keyMap[key]}.$key';
      }
      return match.group(0)!;
    });

    // 2. Conditional t.key replacements
    if (content.contains(RegExp(r'final\s+t\s*=\s*(context\.t|Translations\.of|AppStrings\.of)'))) {
      content = content.replaceAllMapped(RegExp(r'(?<![\w\.])t\.(\w+)\b'), (match) {
        final key = match.group(1);
        if (keyMap.containsKey(key)) {
          // Heuristic: If followed by '(', check if it's likely a Timer or something else.
          // In this project, 't' is heavily used as a Timer in loops.
          if (content.contains('for (final t in') || content.contains('for(final t in')) {
             if (key == 'cancel' || key == 'clear') return match.group(0)!;
          }
          return 't.${keyMap[key]}.$key';
        }
        return match.group(0)!;
      });
    }

    if (content != original) {
      for (final ns in Set<String>.from(keyMap.values)) {
         content = content.replaceAll('t.$ns.$ns.', 't.$ns.');
         content = content.replaceAll('context.t.$ns.$ns.', 'context.t.$ns.');
         content = content.replaceAll('AppStrings.of(context).$ns.$ns.', 'AppStrings.of(context).$ns.');
      }
      file.writeAsStringSync(content);
      updatedCount++;
    }
  }

  print('Refactor complete. Updated $updatedCount files.');
}
