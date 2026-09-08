import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/agent_task_ephemeral_state_notifier.dart';

/// APP-01-A02：过渡态 ephemeral 状态（不落库、不进未读）——
/// notifier 状态只在内存（Riverpod state），remove 即消失；重启/重建后为空。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('update 写入过渡态；同 task 覆盖', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(agentTaskEphemeralNotifierProvider.notifier);
    n.update('t1', status: 'working', text: 'a');
    n.update('t1', status: 'progress', text: 'b');
    final state = container.read(agentTaskEphemeralNotifierProvider);
    expect(state['t1']!.status, 'progress');
    expect(state['t1']!.text, 'b');
  });

  test('remove 移除过渡态（durable 定稿取代）', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(agentTaskEphemeralNotifierProvider.notifier);
    n.update('t2', status: 'working', text: 'x');
    n.remove('t2');
    expect(
      container.read(agentTaskEphemeralNotifierProvider).containsKey('t2'),
      isFalse,
    );
  });

  test('空 notifier：无任何持久化残留（重建后为空 Map）', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(agentTaskEphemeralNotifierProvider), isEmpty);
  });
}
