/// C11 冒烟层 vodozemac 原生库加载器。
///
/// 两种运行环境：
/// 1. **macOS app（`flutter test -d macos`）**：与生产 interop 测试同机制，
///    经 `package:flutter_vodozemac` 从 app bundle `Contents/Frameworks` 加载
///    `flutter_vodozemac.framework`（cargokit 随 app 构建打包）。
///    app 沙箱会阻止 dlopen 仓库外部 dylib，因此该环境必须走 bundle 内库。
/// 2. **宿主 flutter_tester（`flutter test` 无设备）**：显式提供 dylib 目录：
///    - 环境变量 `FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR`（worktree 无
///      gitignored spikes 产物时，指向主仓 `imboyapp/spikes/e2ee-group/rust/target/release/`）；
///    - 或本 worktree 内 `spikes/e2ee-group/rust/target/release/`；
///    - 都没有则抛 [StateError]（fail-closed，不静默跳过加密）。
///
/// 与 `test/unit_test/vodozemac_native_lib.dart` 同源逻辑；integration_test
/// 不 import test/ 下文件，故在此独立维护。
library;

import 'dart:io';

import 'package:flutter_vodozemac/flutter_vodozemac.dart' as fvod;
import 'package:vodozemac/vodozemac.dart' as vod;

const List<String> _libDirCandidates = <String>[
  '../spikes/e2ee-group/rust/target/release/',
  'spikes/e2ee-group/rust/target/release/',
];

const String _envKey = 'FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR';

bool _inited = false;

/// 当前进程是否运行在 macOS .app bundle 内（即 flutter test -d macos）。
bool get runningInsideMacAppBundle =>
    Platform.isMacOS && Platform.resolvedExecutable.contains('.app/');

/// 解析宿主 flutter_tester 环境的 vodozemac dylib 目录（不初始化）。
String resolveVodozemacHarnessLibDir() {
  final envDir = Platform.environment[_envKey];
  if (envDir != null && Directory(envDir).existsSync()) {
    return envDir.endsWith('/') ? envDir : '$envDir/';
  }
  for (final dir in _libDirCandidates) {
    if (Directory(dir).existsSync()) return dir;
  }
  throw StateError(
    'vodozemac 冒烟测试原生库未找到：设置 $_envKey 指向包含 '
    'libvodozemac_bindings_dart.dylib 的目录（如主仓 imboyapp/spikes/'
    'e2ee-group/rust/target/release/），或在 worktree 内构建 spikes。',
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
