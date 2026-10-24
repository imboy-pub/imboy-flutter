/// C11 冒烟层 vodozemac 原生库加载器。
///
/// 两种运行环境：
/// 1. **macOS app（`flutter test -d macos`）**：与生产 interop 测试同机制，
///    经 `package:flutter_vodozemac` 从 app bundle `Contents/Frameworks` 加载
///    `flutter_vodozemac.framework`（cargokit 随 app 构建打包）。
///    app 沙箱会阻止 dlopen 仓库外部 dylib，因此该环境必须走 bundle 内库。
/// 2. **宿主 flutter_tester（`flutter test` 无设备）**：显式提供 dylib 目录：
///    - 环境变量 `FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR`；
///    - 或 flutter_vodozemac 插件自带的 macOS 预编译库（与 vodozemac 纯 Dart
///      包 bindings 同版本发布，FRB content hash 必然配套——spike 本地构建
///      会随 pub 依赖升级失配被拒载，故插件库优先）；
///    - 或本 worktree 内 `spikes/e2ee-group/rust/target/release/`；
///    - 都没有则抛 [StateError]（fail-closed，不静默跳过加密）。
///
/// 与 `test/unit_test/vodozemac_native_lib.dart` 同源逻辑；integration_test
/// 不 import test/ 下文件，故在此独立维护（两处须同步修改）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_vodozemac/flutter_vodozemac.dart' as fvod;
import 'package:vodozemac/vodozemac.dart' as vod;

const List<String> _libDirCandidates = <String>[
  '../spikes/e2ee-group/rust/target/release/',
  'spikes/e2ee-group/rust/target/release/',
];

const String _envKey = 'FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR';

/// FRB 期望的库名 stem（见 vodozemac 包 api.dart init 默认参数）。
const String _expectedStemFile = 'libvodozemac_bindings_dart.dylib';

bool _inited = false;

/// 当前进程是否运行在 macOS .app bundle 内（即 flutter test -d macos）。
bool get runningInsideMacAppBundle =>
    Platform.isMacOS && Platform.resolvedExecutable.contains('.app/');

/// flutter_vodozemac 插件自带的 macOS 预编译 dylib（复制改名进 .dart_tool 缓存，
/// 缓存目录以插件包目录名（含版本号）为键，依赖升级后自动失效重拷）。
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

/// 解析宿主 flutter_tester 环境的 vodozemac dylib 目录（不初始化）。
///
/// 优先级：环境变量 > 插件自带预编译库 > spike 目录。
String resolveVodozemacHarnessLibDir() {
  final envDir = Platform.environment[_envKey];
  if (envDir != null && Directory(envDir).existsSync()) {
    return envDir.endsWith('/') ? envDir : '$envDir/';
  }
  final bundled = _bundledPluginLibDir();
  if (bundled != null) return bundled;
  for (final dir in _libDirCandidates) {
    if (Directory(dir).existsSync()) return dir;
  }
  throw StateError(
    'vodozemac 冒烟测试原生库未找到：设置 $_envKey 指向包含 '
    '$_expectedStemFile 的目录，或在 worktree 内构建 spikes。',
  );
}

/// vod.init 全进程只能调用一次（RustLib 重复初始化会抛错）。
Future<void> ensureVodozemacForHarness() async {
  if (_inited) return;
  if (runningInsideMacAppBundle) {
    await fvod.init();
  } else {
    await vod.init(libraryPath: resolveVodozemacHarnessLibDir());
  }
  _inited = true;
}
