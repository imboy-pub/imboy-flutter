/// 消息入站管道 — 纯 Dart，不依赖 Flutter / sqflite / 任何平台组件。
///
/// 契约：
///   - [stages] 按顺序执行
///   - 某 stage 返回 null → 管道提前终止，后续 stage 不执行
///   - 每个 stage 收到上一个 stage 的输出消息（可对消息做变换）
///   - 空 stages 列表 → 不报错，直接完成
library;

/// 消息在管道中传递的数据结构。
final class InboundMessage {
  const InboundMessage({
    required this.msgId,
    required this.payload,
  });

  final String msgId;
  final Map<String, Object?> payload;
}

/// 管道阶段接口。
///
/// [process] 返回 null 表示此消息应被丢弃，管道提前终止。
/// 返回非 null 消息时，管道继续向下传递。
abstract interface class InboundStage {
  Future<InboundMessage?> process(InboundMessage message);
}

/// 消息入站管道。
///
/// 将 [stages] 中的各阶段串联执行，形成责任链（Chain of Responsibility）。
final class InboundPipeline {
  const InboundPipeline(this.stages);

  final List<InboundStage> stages;

  /// 执行管道。
  ///
  /// - 若某 stage 返回 null，管道提前终止，后续 stage 不再执行。
  /// - 若所有 stage 均通过，Future 正常完成。
  Future<void> execute(InboundMessage message) async {
    InboundMessage? current = message;
    for (final stage in stages) {
      current = await stage.process(current!);
      if (current == null) return;
    }
  }
}
