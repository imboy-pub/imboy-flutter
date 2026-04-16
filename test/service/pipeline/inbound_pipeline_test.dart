/// 钉住 `InboundPipeline` 的管道执行契约 —— RED 阶段。
///
/// 契约：
///   - 管道按 stages 顺序执行
///   - 某 stage 返回 null → 管道提前终止，后续 stage 不执行
///   - 所有 stage 通过 → execute 正常完成
///   - 空 stages → 不报错
///
/// 本测试不依赖 Flutter / sqflite / 任何平台组件，纯 Dart。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/pipeline/inbound_pipeline.dart';

void main() {
  group('InboundPipeline — 管道执行契约', () {
    // ------------------------------------------------------------------ //
    // 辅助 Fake Stage 构建器
    // ------------------------------------------------------------------ //

    /// 透传 stage：原样返回收到的消息。
    InboundStage passThroughStage({void Function(InboundMessage msg)? onProcess}) {
      return _FakeStage(
        onProcess: (msg) async {
          onProcess?.call(msg);
          return msg;
        },
      );
    }

    /// 终止 stage：返回 null，模拟中断。
    InboundStage terminateStage({void Function(InboundMessage msg)? onProcess}) {
      return _FakeStage(
        onProcess: (msg) async {
          onProcess?.call(msg);
          return null;
        },
      );
    }

    // ------------------------------------------------------------------ //
    // 1. 空 stages 列表 → execute 不报错
    // ------------------------------------------------------------------ //
    test('空 stages 列表 → execute 正常完成，不报错', () async {
      final pipeline = InboundPipeline(const []);
      final msg = _testMessage('msg-1');

      await expectLater(pipeline.execute(msg), completes);
    });

    // ------------------------------------------------------------------ //
    // 2. 单 stage 返回 null → 管道终止，后续 stage 不执行
    // ------------------------------------------------------------------ //
    test('单 stage 返回 null → 管道终止', () async {
      var executed = false;
      final afterStage = passThroughStage(
        onProcess: (_) => executed = true,
      );
      final pipeline = InboundPipeline([
        terminateStage(),
        afterStage,
      ]);

      await pipeline.execute(_testMessage('msg-2'));

      expect(executed, isFalse, reason: '第一个 stage 返回 null 后后续 stage 不应执行');
    });

    // ------------------------------------------------------------------ //
    // 3. 单 stage 返回消息 → 消息通过
    // ------------------------------------------------------------------ //
    test('单 stage 透传消息 → execute 正常完成', () async {
      var processCalled = false;
      final pipeline = InboundPipeline([
        passThroughStage(onProcess: (_) => processCalled = true),
      ]);

      await pipeline.execute(_testMessage('msg-3'));

      expect(processCalled, isTrue);
    });

    // ------------------------------------------------------------------ //
    // 4. 三个 stage 串联，中间 stage 返回 null → 第三个 stage 不执行
    // ------------------------------------------------------------------ //
    test('三 stage 串联，中间返回 null → 第三个 stage 不执行', () async {
      final executedStages = <int>[];

      final pipeline = InboundPipeline([
        passThroughStage(onProcess: (_) => executedStages.add(1)),
        terminateStage(onProcess: (_) => executedStages.add(2)),
        passThroughStage(onProcess: (_) => executedStages.add(3)),
      ]);

      await pipeline.execute(_testMessage('msg-4'));

      expect(executedStages, equals([1, 2]));
    });

    // ------------------------------------------------------------------ //
    // 5. stage 按顺序执行（通过调用计数器验证）
    // ------------------------------------------------------------------ //
    test('三个 stage 按顺序执行（1 → 2 → 3）', () async {
      final callOrder = <int>[];

      final pipeline = InboundPipeline([
        passThroughStage(onProcess: (_) => callOrder.add(1)),
        passThroughStage(onProcess: (_) => callOrder.add(2)),
        passThroughStage(onProcess: (_) => callOrder.add(3)),
      ]);

      await pipeline.execute(_testMessage('msg-5'));

      expect(callOrder, equals([1, 2, 3]));
    });

    // ------------------------------------------------------------------ //
    // 6. 所有 stage 通过 → execute 完成
    // ------------------------------------------------------------------ //
    test('所有 stage 通过 → execute 正常完成（Future completes）', () async {
      final pipeline = InboundPipeline([
        passThroughStage(),
        passThroughStage(),
        passThroughStage(),
      ]);

      await expectLater(
        pipeline.execute(_testMessage('msg-6')),
        completes,
      );
    });

    // ------------------------------------------------------------------ //
    // 7. stage 收到的是上一个 stage 的输出消息
    // ------------------------------------------------------------------ //
    test('每个 stage 收到上一个 stage 输出的消息（消息在管道中传递）', () async {
      final receivedMsgIds = <String>[];

      // stage 1：把 msgId 加 '-s1' 后缀后返回新消息
      final stage1 = _FakeStage(
        onProcess: (msg) async {
          receivedMsgIds.add(msg.msgId);
          return InboundMessage(msgId: '${msg.msgId}-s1', payload: msg.payload);
        },
      );

      // stage 2：记录收到的 msgId
      final stage2 = _FakeStage(
        onProcess: (msg) async {
          receivedMsgIds.add(msg.msgId);
          return msg;
        },
      );

      final pipeline = InboundPipeline([stage1, stage2]);
      await pipeline.execute(_testMessage('msg-7'));

      expect(receivedMsgIds[0], 'msg-7');
      expect(receivedMsgIds[1], 'msg-7-s1',
          reason: 'stage 2 应接到 stage 1 的输出消息');
    });

    // ------------------------------------------------------------------ //
    // 8. 第一个 stage 返回 null → 只执行了 1 个 stage
    // ------------------------------------------------------------------ //
    test('第一个 stage 返回 null → 只有第一个 stage 被调用', () async {
      var stage2Called = false;
      var stage3Called = false;

      final pipeline = InboundPipeline([
        terminateStage(),
        passThroughStage(onProcess: (_) => stage2Called = true),
        passThroughStage(onProcess: (_) => stage3Called = true),
      ]);

      await pipeline.execute(_testMessage('msg-8'));

      expect(stage2Called, isFalse);
      expect(stage3Called, isFalse);
    });
  });
}

// -------------------------------------------------------------------------- //
// 辅助类型
// -------------------------------------------------------------------------- //

InboundMessage _testMessage(String msgId) =>
    InboundMessage(msgId: msgId, payload: const {});

/// 可配置行为的假 stage。
class _FakeStage implements InboundStage {
  final Future<InboundMessage?> Function(InboundMessage) onProcess;

  _FakeStage({required this.onProcess});

  @override
  Future<InboundMessage?> process(InboundMessage message) => onProcess(message);
}
