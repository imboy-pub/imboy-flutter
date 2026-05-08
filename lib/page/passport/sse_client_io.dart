/// SseClient IO stub（PR-4β）。
///
/// 用于非 Web 平台（iOS / Android / macOS / Linux / Windows）。
/// 移动端不应调用 SSE 路径（无 EventSource 原生支持），仍走轮询。
///
/// 防御策略：connect 抛 UnsupportedError，调用方应在调 connect 前检查
/// `kIsWeb` 兜底。frames/errors 返回空流，close 静默 ok。
library;

import 'dart:async';

import 'package:imboy/page/passport/sse_client.dart';

/// 非 Web 平台 stub 实现。
class SseClientImpl implements SseClient {
  @override
  bool get isOpen => false;

  @override
  Stream<String> get frames => const Stream.empty();

  @override
  Stream<Object> get errors => const Stream.empty();

  @override
  Future<void> connect(String url) {
    return Future.error(
      UnsupportedError(
        'SseClient.connect 仅 Web 平台支持。'
        '非 Web 平台应通过 kIsWeb 检查并走轮询路径。',
      ),
    );
  }

  @override
  Future<void> close() async {}
}
