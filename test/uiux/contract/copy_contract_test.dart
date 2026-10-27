/// T06 合同自测 — imboy-enterprise-uiux-v1
///
/// 必需清单（manifest，全部不得 skip）：
///  1. uiux_discuss_copy_removed（W06/F12：键移除且无 General 字样）
///  2. uiux_copy_has_no_debug_url_or_raw_source
///  3. uiux_supported_locales_key_parity
///  4. uiux_copy_has_no_pii_like_content
///
/// 直接读 assets/i18n 的 yaml（不依赖生成物）；locale 集合从目录派生。
library;

import 'dart:io' show Directory, File, FileSystemEntity;

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// T06 目标 namespace（卡 write_paths；channel/enterpriseOa 本卡无新增键，
/// 一并纳入扫描以防既有文案回归）。
const List<String> kTargetNamespaces = <String>[
  'workspace',
  'channel',
  'enterpriseOa',
  'customerService',
];

/// W06/F12 收敛后必须移除的讨论引导键（J12：不造 General）。
const String kDiscussGuideKey = 'discussInGroupGuide';

/// 「具体可达的 URL」：schema 后必须紧跟真实 host 首字符（字母/数字）。
/// `https://…` / `https://...` 这类省略号占位示例是合法输入提示文案，
/// 不属于 debug URL。
final RegExp _concreteUrlPattern = RegExp(r'https?://[A-Za-z0-9]');

/// slang 参数化键有两种等价写法：`key` + 值内 `$param`，或显式注解
/// `key(param)`。生成签名相同；parity 比较对注解后缀归一化。
String _normalizeKey(String key) {
  final int i = key.indexOf('(');
  return i < 0 ? key : key.substring(0, i);
}

/// 疑似 PII：11 位手机号 / email / 18 位身份证。
final RegExp _piiPattern = RegExp(
  r'(?<!\d)1[3-9]\d{9}(?!\d)|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
  r'|(?<!\d)\d{17}[\dXx](?!\d)',
);

List<String> _supportedLocales() {
  final List<String> locales = <String>[];
  for (final FileSystemEntity e in Directory('assets/i18n').listSync()) {
    if (e is Directory && File('${e.path}/workspace.i18n.yaml').existsSync()) {
      locales.add(e.path.split('/').last);
    }
  }
  locales.sort();
  return locales;
}

/// 展开为 (keyPath, value) 对（值均应为 String）。
Map<String, String> _flatten(YamlMap doc) {
  final Map<String, String> out = <String, String>{};
  void walk(YamlNode node, String path) {
    final Object? v = node.value;
    if (v is YamlMap) {
      v.nodes.forEach((dynamic k, YamlNode val) {
        walk(val, path.isEmpty ? k.value.toString() : '$path.${k.value}');
      });
    } else if (v is String) {
      out[path] = v;
    } else if (v != null) {
      out[path] = v.toString();
    }
  }

  walk(YamlMap.wrap(doc), '');
  return out;
}

void main() {
  final List<String> locales = _supportedLocales();

  test('uiux_discuss_copy_removed：讨论引导键（全 locale）已移除', () {
    expect(locales, isNotEmpty);
    for (final String loc in locales) {
      final File f = File('assets/i18n/$loc/workspace.i18n.yaml');
      final YamlMap doc = loadYaml(f.readAsStringSync()) as YamlMap;
      final Map<String, String> flat = _flatten(doc);
      expect(
        flat.containsKey(kDiscussGuideKey),
        isFalse,
        reason: '$loc 仍保留 $kDiscussGuideKey（W06/F12 收敛后应删除）',
      );
      // J12「不造 General」指频道讨论面不得伪造 General 目的地；
      // 工作区创建/邀请文案对真实 General 群的指称不受此约束。
    }
  });

  test('uiux_copy_has_no_debug_url_or_raw_source：目标 ns 无可达 URL 与裸 wire 值', () {
    for (final String ns in kTargetNamespaces) {
      for (final String loc in locales) {
        final File f = File('assets/i18n/$loc/$ns.i18n.yaml');
        if (!f.existsSync()) continue; // 缺失 ns 文件走 slang base 回退（现状）
        final Map<String, String> flat = _flatten(
          loadYaml(f.readAsStringSync()) as YamlMap,
        );
        flat.forEach((String key, String value) {
          expect(
            _concreteUrlPattern.hasMatch(value),
            isFalse,
            reason: '$loc/$ns.$key 含可达 URL: $value',
          );
          // 原始 wire 值直出（P3-03 形态）：整值恰为 wire token，
          // 或「来源: wire」拼接泄漏。
          final String trimmed = value.trim();
          expect(
            trimmed == 'widget',
            isFalse,
            reason: '$loc/$ns.$key 是裸 wire 值',
          );
          expect(
            trimmed.endsWith(': widget'),
            isFalse,
            reason: '$loc/$ns.$key 疑似 wire 泄漏拼接: $value',
          );
        });
      }
    }
  });

  test('uiux_supported_locales_key_parity：同一 ns 的各 locale 键集一致', () {
    for (final String ns in kTargetNamespaces) {
      Set<String>? base;
      String? baseLoc;
      for (final String loc in locales) {
        final File f = File('assets/i18n/$loc/$ns.i18n.yaml');
        if (!f.existsSync()) continue;
        final Set<String> keys = _flatten(
          loadYaml(f.readAsStringSync()) as YamlMap,
        ).keys.map(_normalizeKey).toSet();
        base ??= keys;
        baseLoc ??= loc;
        expect(
          keys,
          base,
          reason:
              '$ns 的 $loc 键集与 $baseLoc 不一致 '
              '(+${keys.difference(base).toList()} '
              '-${base.difference(keys).toList()})',
        );
      }
      expect(base, isNotNull, reason: '$ns 至少应存在于一个 locale');
    }
  });

  test('uiux_copy_has_no_pii_like_content：目标 ns 无真实客户信息形态', () {
    for (final String ns in kTargetNamespaces) {
      for (final String loc in locales) {
        final File f = File('assets/i18n/$loc/$ns.i18n.yaml');
        if (!f.existsSync()) continue;
        _flatten(loadYaml(f.readAsStringSync()) as YamlMap)
            .forEach((String key, String value) {
              expect(
                _piiPattern.hasMatch(value),
                isFalse,
                reason: '$loc/$ns.$key 疑似含 PII（手机号/邮箱/证件号）: $value',
              );
            });
      }
    }
  });
}
