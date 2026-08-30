import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// envied 构建新鲜度守卫（H2 真机走查发现②，2026-08-30）。
///
/// envied 生成器不把 `.env` 文件声明为 build_runner 输入依赖：
/// 修改 `.env.local` 后直接跑 `flutter build` 会复用缓存的
/// `env_local.g.dart`（旧值烘焙进 APK），且无任何告警——真机走查中
/// 曾因此导致 init 配置解密失败、登录静默卡死。
///
/// 本测试把 `.env.local` 的关键值与 `env_local.g.dart` 烘焙值逐一比对，
/// 不一致即失败，提示先重建再打包。
///
/// 解码说明：obfuscate:true 字段在 .g.dart 中是两组 `List<int>`
/// （key 与 data 按位异或），此处按相同算法还原明文。
const gDartPath = 'lib/config/env_local.g.dart';
const envPath = '.env.local';

void main() {
  late String gDart;
  late Map<String, String> env;

  setUpAll(() {
    gDart = File(gDartPath).readAsStringSync();
    env = parseEnvFile(File(envPath).readAsStringSync());
  });

  test('env_local.g.dart 必须由当前 .env.local 生成（API_BASE_URL 明文比对）', () {
    final baked = extractPlainField(gDart, 'apiBaseUrl');
    expect(
      baked,
      env['API_BASE_URL'],
      reason:
          'API_BASE_URL 已改但 env_local.g.dart 仍是旧值——'
          '先删 lib/config/env_local.g.dart 再跑 build_runner，'
          '或打包时用 --dart-define=API_BASE_URL_OVERRIDE 覆写。',
    );
  });

  test('env_local.g.dart 必须由当前 .env.local 生成（SOLIDIFIED_KEY 混淆值还原比对）', () {
    final baked = decodeObfuscated(gDart, 'solidifiedKey');
    expect(
      baked,
      env['SOLIDIFIED_KEY'],
      reason:
          'SOLIDIFIED_KEY 已改但 env_local.g.dart 仍是旧值——'
          '会导致 /init GCM 解密失败（InvalidCipherTextException）、'
          '登录静默卡死。先删 lib/config/env_local.g.dart 再跑 build_runner，'
          '或用 --dart-define=SOLIDIFIED_KEY_OVERRIDE 覆写。',
    );
  });

  test('env_local.g.dart 必须由当前 .env.local 生成（SOLIDIFIED_KEY_IV 混淆值还原比对）', () {
    final baked = decodeObfuscated(gDart, 'solidifiedKeyIv');
    expect(
      baked,
      env['SOLIDIFIED_KEY_IV'],
      reason:
          'SOLIDIFIED_KEY_IV 已改但 env_local.g.dart 仍是旧值——'
          'legacy CBC 降级路径会解密失败。先删 lib/config/env_local.g.dart '
          '再跑 build_runner，或用 --dart-define=SOLIDIFIED_KEY_IV_OVERRIDE 覆写。',
    );
  });
}

/// 解析 KEY=VALUE 形态的 env 文件：去掉注释行与首尾引号。
Map<String, String> parseEnvFile(String content) {
  final result = <String, String>{};
  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    final key = line.substring(0, eq).trim();
    var value = line.substring(eq + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    result[key] = value;
  }
  return result;
}

/// 提取 .g.dart 中 obfuscate:false 字段的明文值（非混淆字段以
/// `static const String <name> = '<值>';` 形态存在）。
String extractPlainField(String gDart, String fieldName) {
  final m = RegExp(
    "static const String $fieldName = '([^']*)'",
  ).firstMatch(gDart);
  if (m == null) {
    fail('env_local.g.dart 中找不到字段 $fieldName（生成产物结构变化？）');
  }
  return m.group(1)!;
}

/// 还原 obfuscate:true 字段：envied 以 key/data 两组 `List<int>` 按位异或。
String decodeObfuscated(String gDart, String fieldName) {
  final key = extractIntList(gDart, '_enviedkey${_lowerFirst(fieldName)}');
  final data = extractIntList(gDart, '_envieddata${_lowerFirst(fieldName)}');
  if (key == null || data == null) {
    fail('env_local.g.dart 中找不到混淆字段 $fieldName（生成产物结构变化？）');
  }
  return String.fromCharCodes([
    for (var i = 0; i < data.length; i++) data[i] ^ key[i % key.length],
  ]);
}

String _lowerFirst(String s) =>
    s.isEmpty ? s : '${s[0].toLowerCase()}${s.substring(1)}';

List<int>? extractIntList(String gDart, String listName) {
  final m = RegExp(
    'static const List<int> $listName = <int>\\[([^\\]]*)\\];',
    dotAll: true,
  ).firstMatch(gDart);
  if (m == null) return null;
  return m
      .group(1)!
      .split(',')
      .map((e) => int.tryParse(e.trim()))
      .whereType<int>()
      .toList();
}
