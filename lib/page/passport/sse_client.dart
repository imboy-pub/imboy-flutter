/// SSE 客户端抽象 + 平台工厂（PR-4β 基础设施层）。
///
/// 设计目标：
///   - 让 `web_login_page.dart` 的 `QRLogin` Notifier 在 PR-4γ 注入此抽象，
///     无需直接依赖 `dart:html` / `package:web`，移动端编译不报错。
///   - 测试用 `FakeSseClient` 替换真实实现，无需真启 EventSource。
///
/// 平台路由（参考 `lib/service/rsa.dart` conditional import 模式）：
///   - 非 Web 平台 → `sse_client_io.dart` stub（throw UnsupportedError）
///   - Web 平台 → `sse_client_web.dart` 真实 EventSource 包装（PR-4γ 实现）
library;

import 'sse_client_io.dart' if (dart.library.html) 'sse_client_web.dart';

// ---------------------------------------------------------------------------
// SseClient: 客户端抽象契约
// ---------------------------------------------------------------------------

/// SSE 长连接客户端接口。
///
/// 调用流程（PR-4γ Notifier 用法）：
/// ```dart
/// final client = createSseClient();
/// final framesSub = client.frames.listen(_handleFrame);
/// final errorsSub = client.errors.listen(_handleError);
/// await client.connect('/api/v1/passport/qr_login/subscribe?session_token=xxx');
/// ...
/// await client.close();
/// framesSub.cancel(); errorsSub.cancel();
/// ```
abstract class SseClient {
  /// 已连上 EventSource（onopen 触发后为 true，onerror/close 后为 false）
  bool get isOpen;

  /// 原始 SSE 帧流（每帧形如 `data: {...}` 单行，不含 `\n\n` 分隔符）。
  ///
  /// 由 PR-4α 的 `parseSseFrame` 解析为 `QrStatusEvent`。
  Stream<String> get frames;

  /// 错误流（连接失败 / 网络中断 / onerror 触发）。
  ///
  /// PR-4γ Notifier 监听后置 `_sseAttemptFailed = true`，
  /// 由 `shouldFallbackToPolling` 触发降级。
  Stream<Object> get errors;

  /// 连接 SSE 端点。
  ///
  /// 失败：抛 `UnsupportedError`（非 Web 平台）/ 网络异常。
  /// 重复 connect：实现自行决定（重连或抛异常）。
  Future<void> connect(String url);

  /// 关闭连接，释放资源。重复 close 应安全（idempotent）。
  Future<void> close();
}

// ---------------------------------------------------------------------------
// 工厂：平台条件 import 自动选择实现
// ---------------------------------------------------------------------------

/// 创建当前平台的 SseClient 实例。
///
/// - Web 平台：`SseClientImpl` 来自 `sse_client_web.dart`（PR-4γ 真实实现）
/// - 非 Web：`SseClientImpl` 来自 `sse_client_io.dart`（stub，connect 抛异常）
SseClient createSseClient() => SseClientImpl();
