/// Production fallback bodies and core delete events in the browser runtime.
@TestOn('browser')
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'web_message_content_test.dart' as content;

// 「Web core delete events」组不在本 chrome 聚合内：其 harness 是 VM 侧
// sqflite_ffi + 版本化 fixture（web_core_delete_event_test.dart，
// sqfliteFfiInit/databaseFactoryFfi 在 web 上不受支持），由同名 VM 目标
// 覆盖（scoped profile 复跑 3/3 PASS）。本文件只聚合浏览器运行时的
// 内容渲染组。
void main() {
  debugPrint = debugPrintSynchronously;
  group('Web message content', content.main);
}
