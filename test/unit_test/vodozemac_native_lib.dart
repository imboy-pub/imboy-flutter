import 'dart:convert';
import 'dart:io';

import 'package:vodozemac/vodozemac.dart' as vod;

const List<String> spikeLibDirCandidates = [
  '../spikes/e2ee-group/rust/target/release/',
  'spikes/e2ee-group/rust/target/release/',
];

/// FRB 期望的库名 stem（见 vodozemac 包 api.dart init 默认参数）。
const _expectedStemFile = 'libvodozemac_bindings_dart.dylib';

bool _vodInited = false;

/// flutter_vodozemac 插件自带的 macOS 预编译 dylib 目录（复制改名后）。
///
/// 插件库与纯 Dart 包 bindings 同版本配套发布，hash 必然匹配；而 spike
/// 本地构建（spikes/e2ee-group/rust）随 pub 依赖升级后 FRB content hash
/// 失配被拒载（2026-10-21 mod-up 升 0.9.0 后 38 个用例 setUpAll 失败的
/// 根因），故插件库优先于 spike。
String? _bundledPluginLibDir() {
  if (!Platform.isMacOS) return null;
  final cfg = File('.dart_tool/package_config.json');
  if (!cfg.existsSync()) return null;
  try {
    final packages =
        (jsonDecode(cfg.readAsStringSync()) as Map)['packages'] as List;
    final String? rootUri =
        packages.cast<Map<String, dynamic>>().firstWhere(
              (p) => p['name'] == 'flutter_vodozemac',
              orElse: () => const <String, dynamic>{},
            )['rootUri']
            as String?;
    if (rootUri == null || !rootUri.startsWith('file:')) return null;
    final pluginRoot = Uri.parse(rootUri).toFilePath();
    final src = File(
      '$pluginRoot/macos/flutter_vodozemac/flutter_vodozemac.xcframework/'
      'macos-arm64_x86_64/libflutter_vodozemac.dylib',
    );
    if (!src.existsSync()) return null;
    // 插件库名 stem 与 FRB 期望不同，复制改名进 .dart_tool 缓存；缓存目录
    // 以插件包目录名（含版本号）为键，依赖升级后自动失效重拷。
    final versionDir = Uri.parse(rootUri).pathSegments
        .lastWhere((s) => s.isNotEmpty);
    final cacheDir = Directory('.dart_tool/vod_test_lib/$versionDir');
    final dst = File('${cacheDir.path}/$_expectedStemFile');
    if (!dst.existsSync()) {
      cacheDir.createSync(recursive: true);
      src.copySync(dst.path);
    }
    return '${cacheDir.path}/';
  } on Exception {
    return null;
  }
}

/// 解析测试用 vodozemac 宿主动态库目录。
///
/// 优先级：
/// 环境变量 > flutter_vodozemac 插件自带预编译库（配套保证）> spike 目录。
/// 与 `integration_test/e2ee_release/harness/vodozemac_loader.dart` 同源
///（integration_test 不 import test/，两处须同步修改）。
String resolveVodozemacTestLibDir() {
  final envDir =
      Platform.environment['FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR'];
  if (envDir != null && Directory(envDir).existsSync()) {
    return envDir.endsWith('/') ? envDir : '$envDir/';
  }
  final bundled = _bundledPluginLibDir();
  if (bundled != null) return bundled;
  for (final dir in spikeLibDirCandidates) {
    if (Directory(dir).existsSync()) return dir;
  }
  throw StateError(
    'vodozemac 测试原生库未找到：\n'
    '  - 设置 FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR 指向包含\n'
    '    $_expectedStemFile 的目录；或\n'
    '${spikeLibDirCandidates.map((d) => '  - $d').join('\n')}',
  );
}

/// vod.init 全进程只能调一次（RustLib 重复初始化会抛错）。
Future<void> ensureVodozemac() async {
  if (_vodInited) return;
  await vod.init(libraryPath: resolveVodozemacTestLibDir());
  _vodInited = true;
}

/// 探测测试原生库是否可用（不触发初始化）。
bool hasVodozemacTestLib() {
  try {
    resolveVodozemacTestLibDir();
    return true;
  } on StateError {
    return false;
  }
}
