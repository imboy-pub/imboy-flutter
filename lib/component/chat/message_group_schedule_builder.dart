import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';

/// 群日程消息展现层 / Group Schedule Message Card Builder
class MessageGroupScheduleBuilder extends StatelessWidget {
  final CustomMessage message;

  const MessageGroupScheduleBuilder({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final metadata = message.metadata ?? {};
    final title = metadata['title']?.toString() ?? '未命名日程';
    final startTime = metadata['start_time']?.toString() ?? '';
    final scheduleId = metadata['id']?.toString() ?? '';
    final groupId = metadata['group_id']?.toString() ?? '';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (groupId.isNotEmpty && scheduleId.isNotEmpty) {
              final encodedId = Uri.encodeComponent(scheduleId);
              context.push('/group/$groupId/schedule/$encodedId');
            }
          },
          borderRadius: AppRadius.borderRadiusMedium,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month, color: AppColors.primary, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      t.groupSchedule.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (startTime.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '时间: $startTime',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '查看详情并确认参加',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GroupScheduleMessageTypePlugin implements MessageTypePlugin {
  const GroupScheduleMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.groupSchedule}';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.standalone;

  @override
  String get type => MessageType.groupSchedule;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return MessageGroupScheduleBuilder(message: message);
  }
}
