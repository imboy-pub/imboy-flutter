import 'dart:io';

import 'package:vodozemac/vodozemac.dart' as vod;

/// spike 已构建的 vodozemac 宿主动态库候选路径（历史约定，依赖布局）。
/// umbrella 布局：spikes 在检出上一级（imboy.pub/spikes）；
/// 仓内布局：spikes 在 imboyapp 仓内（当前实际布局）。
const List<String> spikeLibDirCandidates = [
  '../spikes/e2ee-group/rust/target/release/',
  'spikes/e2ee-group/rust/target/release/',
];

bool _vodInited = false;

/// 解析测试用 vodozemac 宿主动态库目录。
///
/// 优先级：
/// 1. `FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR` 环境变量（CI 推荐，
///    flutter_rust_bridge loader 亦认此变量）；
/// 2. `../spikes/...`（umbrella 工作区布局）；
/// 3. `spikes/...`（spikes 收进 imboyapp 仓内后的布局）。
///
/// 都缺失时抛 [StateError]，绝不静默返回不存在的路径——frb 会回退打开
/// 不兼容镜像，表现为 createInboundSession 报
/// "message didn't contain a version"。
String resolveVodozemacTestLibDir() {
  final envDir =
      Platform.environment['FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR'];
  if (envDir != null && Directory(envDir).existsSync()) {
    return envDir.endsWith('/') ? envDir : '$envDir/';
  }
  for (final dir in spikeLibDirCandidates) {
    if (Directory(dir).existsSync()) {
      return dir;
    }
  }
  throw StateError(
    'vodozemac 测试原生库未找到：\n'
    '  - 设置 FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR 指向包含\n'
    '    libvodozemac_bindings_dart.dylib 的目录；或\n'
    '  - 在以下任一路径布置库（来源 spikes/e2ee-group 的\n'
    '    cargo build --release）：\n'
    '${spikeLibDirCandidates.map((d) => '    - $d').join('\n')}',
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
