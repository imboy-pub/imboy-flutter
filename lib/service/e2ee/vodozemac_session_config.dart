// vodozemac 0.7 的 public API 暂未导出 OlmSessionConfig，需从生成 binding
// 创建显式的 v1 配置，以保持现有 libolm-compatible wire format。
// ignore_for_file: implementation_imports

import 'package:vodozemac/src/generated/bindings.dart' as bindings;

bindings.VodozemacOlmSessionConfig legacyOlmSessionConfig() =>
    bindings.VodozemacOlmSessionConfig.version1();
