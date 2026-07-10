import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/store/api/agent_task_api.dart';
import 'package:imboy/page/chat/chat/agent_task_ephemeral_state_notifier.dart';
import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/i18n/strings.g.dart';

/// Agent 任务群消息卡片 / Agent task in-group card（Phase 4 T4.2）
///
/// 渲染后端 durable agent_task 群消息（msg_type=text，payload.agent_task 元数据）：
/// 状态徽标 + 文案；`awaiting_approval` 且 actions 含 approve/reject 时展示可点击审批按钮。
/// 点击后调 AgentTaskApi，**不乐观翻转本地状态**——最终态由后端经 WS 回显重建卡片
/// （对齐转账卡片 message_transfer_builder 的做法）。
class MessageAgentTaskBuilder extends ConsumerStatefulWidget {
  final Message message;

  const MessageAgentTaskBuilder({super.key, required this.message});

  @override
  ConsumerState<MessageAgentTaskBuilder> createState() =>
      _MessageAgentTaskBuilderState();
}

class _MessageAgentTaskBuilderState
    extends ConsumerState<MessageAgentTaskBuilder> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // durable 卡片到达 → 清掉该 task 的 ephemeral 进度条（定稿取代过渡态）
    final task = widget.message.metadata?['agent_task'] as Map?;
    final taskId = task?['task_id']?.toString() ?? '';
    if (taskId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(agentTaskEphemeralNotifierProvider.notifier).remove(taskId);
        }
      });
    }
  }

  Future<void> _decide(String taskId, {required bool approve}) async {
    if (_isProcessing || taskId.isEmpty) return;
    setState(() => _isProcessing = true);
    AppLoading.show();
    final ok = approve
        ? await AgentTaskApi().approve(taskId)
        : await AgentTaskApi().reject(taskId);
    if (ok) {
      // 由后端 WS 回显更新卡片状态，不在此乐观翻转本地状态。
      AppLoading.dismiss();
    } else {
      AppLoading.dismiss();
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.message.metadata ?? const {};
    final task =
        (metadata['agent_task'] as Map?)?.cast<String, dynamic>() ?? const {};
    final taskId = task['task_id']?.toString() ?? '';
    final status = task['status']?.toString() ?? '';
    final content =
        metadata['content']?.toString() ??
        metadata['text']?.toString() ??
        _statusLabel(status);
    final actions =
        (task['actions'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];

    final isAwaiting = status == 'awaiting_approval';
    final canApprove = isAwaiting && actions.contains('approve');
    final canReject = isAwaiting && actions.contains('reject');

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppColors.getChatBubbleBackground(
          false,
          false,
          Theme.of(context).brightness,
        ),
        borderRadius: MessageSpacing.getBubbleBorderRadius(false),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(_statusIcon(status), color: _statusColor(status), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.agentTask.title,
                  style: context.textStyle(
                    FontSizeType.normal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _statusLabel(status),
                style: context.textStyle(
                  FontSizeType.caption2,
                  color: _statusColor(status),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: context.textStyle(FontSizeType.normal)),
          if (canApprove || canReject) ...[
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (canReject)
                  TextButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _decide(taskId, approve: false),
                    child: Text(
                      t.agentTask.reject,
                      style: context.textStyle(
                        FontSizeType.normal,
                        color: AppColors.iosRed,
                      ),
                    ),
                  ),
                if (canApprove)
                  TextButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _decide(taskId, approve: true),
                    child: Text(
                      t.agentTask.approve,
                      style: context.textStyle(
                        FontSizeType.normal,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _statusIcon(String status) => switch (status) {
    'completed' => Icons.check_circle_outline,
    'failed' => Icons.error_outline,
    'cancelled' => Icons.cancel_outlined,
    'awaiting_approval' => Icons.hourglass_top,
    _ => Icons.smart_toy_outlined,
  };

  Color _statusColor(String status) => switch (status) {
    'completed' => AppColors.iosGreen,
    'failed' => AppColors.iosRed,
    'cancelled' => AppColors.iosGray,
    'awaiting_approval' => AppColors.iosOrange,
    _ => AppColors.primary,
  };

  String _statusLabel(String status) => switch (status) {
    'working' => t.agentTask.working,
    'submitted' => t.agentTask.submitted,
    'progress' => t.agentTask.progress,
    'completed' => t.agentTask.completed,
    'failed' => t.agentTask.failed,
    'cancelled' => t.agentTask.cancelled,
    'awaiting_approval' => t.agentTask.awaitingApproval,
    _ => t.agentTask.title,
  };
}
