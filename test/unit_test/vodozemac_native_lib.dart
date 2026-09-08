import 'dart:io';

import 'package:vodozemac/vodozemac.dart' as vod;

const List<String> spikeLibDirCandidates = [
  '../spikes/e2ee-group/rust/target/release/',
  'spikes/e2ee-group/rust/target/release/',
];

bool _vodInited = false;

/// 解析测试用 vodozemac 宿主动态库目录。
///
/// 优先级：
/// 环境变量优先；否则查找 umbrella 与仓内 spike 目录。
String resolveVodozemacTestLibDir() {
  final envDir =
      Platform.environment['FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR'];
  if (envDir != null && Directory(envDir).existsSync()) {
    return envDir.endsWith('/') ? envDir : '$envDir/';
  }
  for (final dir in spikeLibDirCandidates) {
    if (Directory(dir).existsSync()) return dir;
  }
  throw StateError(
    'vodozemac 测试原生库未找到：\n'
    '  - 设置 FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR 指向包含\n'
    '    libvodozemac_bindings_dart.dylib 的目录；或\n'
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
