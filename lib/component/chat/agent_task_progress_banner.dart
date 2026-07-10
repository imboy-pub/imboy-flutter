import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/page/chat/chat/agent_task_ephemeral_state_notifier.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// Agent 任务实时进度条 / transient task progress strip（Phase 4 T4.2）。
///
/// 展示过渡态(working/submitted/progress)的 ephemeral 更新（消息列表上方一行）；
/// 终态由 durable 卡片取代（见 message_agent_task_builder initState 的 remove 清理）。
/// 空则收起（SizedBox.shrink）。
class AgentTaskProgressBanner extends ConsumerWidget {
  const AgentTaskProgressBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(agentTaskEphemeralNotifierProvider);
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: tasks.values.map((t) => _row(context, t)).toList(),
    );
  }

  Widget _row(BuildContext context, AgentTaskEphemeralState t) {
    return Container(
      width: double.infinity,
      color: AppColors.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t.text.isEmpty ? t.status : t.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyle(
                FontSizeType.caption2,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
