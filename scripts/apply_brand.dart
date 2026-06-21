// 白标打标脚本 / White-label stamper.
//
// 读取项目根的 brand.yaml，把品牌值打进原生工程与 Dart 源码。
// 幂等：可重复运行；每处必须命中且只命中一次，否则报错退出（fail-fast）。
//
//   cd imboyapp && dart run scripts/apply_brand.dart
//
// 图标不在此处理（标准步骤）：放好 1024x1024 图后用 flutter_launcher_icons，
//   见末尾打印的提示。
//
// ponytail: 扁平 key:value 手解析，不引 yaml 依赖；纯文本替换，不引模板引擎。

import 'dart:io';

void main() {
  final root = Directory.current.path;
  final brand = _parseBrand(File('$root/brand.yaml'));

  final name = _require(brand, 'app_name');
  final color = _require(brand, 'primary_color');
  final apiUrl = _require(brand, 'api_base_url');
  final publicUrl = _require(brand, 'public_base_url');

  if (!RegExp(r'^0x[0-9A-Fa-f]{8}$').hasMatch(color)) {
    _fail('primary_color 必须是 0xAARRGGBB 格式，当前: $color');
  }

  // 1) iOS 显示名
  _stamp(
    '$root/ios/Runner/Info.plist',
    RegExp(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)'),
    (m) => '${m[1]}$name${m[2]}',
    'iOS CFBundleDisplayName',
  );

  // 2) Android 显示名
  _stamp(
    '$root/android/app/src/main/AndroidManifest.xml',
    RegExp(r'android:label="[^"]*"'),
    (_) => 'android:label="$name"',
    'Android android:label',
  );

  // 3) 品牌主色
  _stamp(
    '$root/lib/theme/default/app_colors.dart',
    RegExp(r'static const Color primary = Color\(0x[0-9A-Fa-f]{8}\);'),
    (_) => 'static const Color primary = Color($color);',
    'AppColors.primary',
  );

  // 4) 生产 API 域名
  _stamp(
    '$root/.env.pro',
    RegExp(r'^API_BASE_URL\s*=.*$', multiLine: true),
    (_) => 'API_BASE_URL=$apiUrl',
    '.env.pro API_BASE_URL',
  );

  // 5) 公开资源域名默认值
  _stamp(
    '$root/lib/config/env.dart',
    RegExp(r"_publicBaseUrlDefault = '[^']*'"),
    (_) => "_publicBaseUrlDefault = '$publicUrl'",
    'env.dart _publicBaseUrlDefault',
  );

  stdout.writeln('\n✅ 白标已应用: $name ($color)');
  stdout.writeln('   API=$apiUrl  PUBLIC=$publicUrl');
  stdout.writeln('\n⚠️  接下来手动两步：');
  stdout.writeln('   1) 改 .env.pro 里 envied 加密字段后重跑代码生成：');
  stdout.writeln('      dart run build_runner build --delete-conflicting-outputs');
  stdout.writeln('   2) App 图标（放好 1024x1024 png 后）：');
  stdout.writeln('      flutter pub add dev:flutter_launcher_icons');
  stdout.writeln('      # 在 pubspec 配置 image_path 后：');
  stdout.writeln('      dart run flutter_launcher_icons');
}

/// 解析扁平 key:value（忽略注释/空行；值去除首尾空白与可选引号）。
Map<String, String> _parseBrand(File f) {
  if (!f.existsSync()) _fail('找不到 ${f.path}');
  final out = <String, String>{};
  for (final raw in f.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final i = line.indexOf(':');
    if (i < 0) continue;
    final key = line.substring(0, i).trim();
    var val = line.substring(i + 1).trim();
    // 去掉行内注释（url 不含 #，故以空格+# 为界安全）
    final h = val.indexOf(' #');
    if (h >= 0) val = val.substring(0, h).trim();
    if (val.length >= 2 &&
        ((val.startsWith('"') && val.endsWith('"')) ||
            (val.startsWith("'") && val.endsWith("'")))) {
      val = val.substring(1, val.length - 1);
    }
    if (key.isNotEmpty) out[key] = val;
  }
  return out;
}

String _require(Map<String, String> m, String k) {
  final v = m[k];
  if (v == null || v.isEmpty) _fail('brand.yaml 缺少必填项: $k');
  return v!;
}

/// 替换文件中正则命中处；必须恰好命中一次，否则 fail-fast。
void _stamp(
  String path,
  RegExp pattern,
  String Function(Match) replace,
  String label,
) {
  final f = File(path);
  if (!f.existsSync()) _fail('[$label] 文件不存在: $path');
  final src = f.readAsStringSync();
  final matches = pattern.allMatches(src).toList();
  if (matches.length != 1) {
    _fail('[$label] 期望命中 1 处，实际 ${matches.length} 处 ($path)');
  }
  final next = src.replaceFirstMapped(pattern, replace);
  if (next != src) f.writeAsStringSync(next);
  stdout.writeln('  ✓ $label');
}

Never _fail(String msg) {
  stderr.writeln('❌ $msg');
  exit(1);
}
