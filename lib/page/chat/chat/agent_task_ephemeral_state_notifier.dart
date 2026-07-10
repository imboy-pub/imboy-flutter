import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 群 agent 任务实时(ephemeral)进度状态 / transient task progress（Phase 4 T4.2）。
///
/// 键 task_id，值 {status, text}。过渡态帧(working/submitted/progress)驱动更新；
/// 不落库、不进会话/未读簿记。终态由 durable 卡片取代（卡片 initState 调 remove 清理），
/// 会话销毁时订阅侧一并 remove，防全局 state Map 泄漏。
class AgentTaskEphemeralState {
  final String status;
  final String text;

  const AgentTaskEphemeralState({required this.status, required this.text});
}

class AgentTaskEphemeralNotifier
    extends Notifier<Map<String, AgentTaskEphemeralState>> {
  @override
  Map<String, AgentTaskEphemeralState> build() => {};

  void update(String taskId, {required String status, required String text}) {
    state = {
      ...state,
      taskId: AgentTaskEphemeralState(status: status, text: text),
    };
  }

  void remove(String taskId) {
    if (!state.containsKey(taskId)) return;
    state = {...state}..remove(taskId);
  }
}

/// 全局 agent 任务实时进度状态 Provider
final agentTaskEphemeralNotifierProvider =
    NotifierProvider<
      AgentTaskEphemeralNotifier,
      Map<String, AgentTaskEphemeralState>
    >(AgentTaskEphemeralNotifier.new);
