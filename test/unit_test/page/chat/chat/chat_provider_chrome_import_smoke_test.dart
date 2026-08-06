/// Phase 2.1.b-1 探查 — chat_provider Chrome 端 import smoke
///
/// 目的：
/// - 让 dart2js 在 Chrome 平台尝试编译 chat_provider 及其传递依赖
/// - 编译失败 → 暴露 Web 不兼容的具体依赖（如 `dart:io` / `just_audio`
///   桌面/移动专属 API / 文件系统调用等）→ 产出 Phase 2.1.b 可行动清单
/// - 编译通过 → chat_provider 至少能在 Web 上加载，下一步评估能否 instantiate
///
/// 不验证运行时正确性，只验证编译可达性。
@TestOn('chrome')
library;

// ignore: unused_import
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat_provider 可在 chrome 平台 import + 编译', () {
    // 单纯 import 不抛即可。本测试若 RED → 编译输出会列出具体不兼容依赖。
    expect(true, isTrue);
  });
}
