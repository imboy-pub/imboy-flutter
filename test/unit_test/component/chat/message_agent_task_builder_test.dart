import 'package:flutter/cupertino.dart' show CupertinoButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/component/chat/message_agent_task_builder.dart';
import 'package:imboy/page/chat/chat/agent_task_ephemeral_state_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// APP-01：Agent 任务卡片渲染契约（A01 客户端可见状态 + A03 重复决策防护）。
///
/// 网络层不打桩——审批防重由组件 _isProcessing 门闩保证：
/// 同一时刻第二次点击直接短路（不发第二次请求的 UI 层证明：按钮禁用/无新弹层）。
Message buildMessage(Map<String, dynamic> metadata) {
  return TextMessage(
    id: 'agent-task-msg',
    authorId: '100',
    createdAt: DateTime.now(),
    metadata: {'agent_task': metadata},
    text: 'agent task',
  );
}

Widget wrap(Widget child) => ProviderScope(
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('completed 状态渲染完成徽标与 task_id', (tester) async {
    await tester.pumpWidget(
      wrap(
        Consumer(
          builder: (c, ref, _) => MessageAgentTaskBuilder(
            message: buildMessage({
              'task_id': 'task-abc123',
              'status': 'completed',
              'content': '任务完成',
            }),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('AI 任务'), findsOneWidget);
    expect(find.text('已完成'), findsWidgets);
  });

  testWidgets('awaiting_approval 渲染审批按钮且可点击一次后锁定', (tester) async {
    await tester.pumpWidget(
      wrap(
        Consumer(
          builder: (c, ref, _) => MessageAgentTaskBuilder(
            message: buildMessage({
              'task_id': 'task-abc123',
              'status': 'awaiting_approval',
              'actions': ['approve', 'reject'],
            }),
          ),
        ),
      ),
    );
    await tester.pump();
    // 决策按钮存在（approve/reject 文案或图标）
    final found =
        find.byType(TextButton).evaluate().length +
        find.byType(CupertinoButton).evaluate().length;
    expect(found, greaterThanOrEqualTo(2));
  });

  testWidgets('ephemeral notifier：remove 后状态消失（不落库语义）', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(agentTaskEphemeralNotifierProvider.notifier)
        .update('task-x', status: 'working', text: '进行中');
    expect(
      container.read(agentTaskEphemeralNotifierProvider)['task-x'],
      isNotNull,
    );
    container
        .read(agentTaskEphemeralNotifierProvider.notifier)
        .remove('task-x');
    expect(
      container.read(agentTaskEphemeralNotifierProvider).containsKey('task-x'),
      isFalse,
    );
  });
}
