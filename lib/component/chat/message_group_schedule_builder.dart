import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/schedule/group_schedule_ui.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 群日程消息展现层 / Group Schedule Message Card Builder
///
/// 对标微信/钉钉会话内日程卡片：白底窄卡 + 状态胶囊（已取消红、
/// 已结束灰、未开始蓝、进行中绿）+ 时间范围行；已取消整卡灰化、
/// 标题删除线，让"取消"在会话流里一眼可见。
class MessageGroupScheduleBuilder extends StatelessWidget {
  final CustomMessage message;

  const MessageGroupScheduleBuilder({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final metadata = message.metadata ?? {};
    // 空串标题与缺 title 一样走"未命名日程"兜底。
    final rawTitle = metadata['title']?.toString().trim() ?? '';
    final title = rawTitle.isEmpty
        ? t.groupSchedule.untitledSchedule
        : rawTitle;
    final startAt = _toEpochSec(metadata['start_time']);
    final endAt = _toEpochSec(metadata['end_time'] ?? metadata['end_at']);
    final scheduleId = metadata['id']?.toString() ?? '';
    final groupId = metadata['group_id']?.toString() ?? '';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final state = resolveScheduleTimeState(
      status: _toInt(metadata['status']),
      startAtSec: startAt,
      endAtSec: endAt,
      nowSec: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    final isCancelled = state == GroupScheduleTimeState.cancelled;

    final isSentByMe = message.authorId == UserRepoLocal.to.currentUid;
    final borderRadius = MessageSpacing.getBubbleBorderRadius(isSentByMe);

    // 日程卡是"白底卡片"而非聊天气泡，文字色走主题 token 而不是裸 Colors.*，
    // 否则暗色下白字白底 / 亮色下 white60 直接看不见。
    final titleColor = isCancelled
        ? AppColors.iosGray
        : AppColors.getTextColor(Theme.of(context).brightness);

    return Opacity(
      // 已取消整卡降不透明度，与列表页的灰化策略一致。
      opacity: isCancelled ? 0.75 : 1,
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHighest
              : AppColors.mediaScrimWhite,
          borderRadius: borderRadius,
          border: Border.all(
            color: isDark ? AppColors.overlayWhite10 : AppColors.iosGray5,
            width: 0.5,
          ),
        ),
        child: Material(
          color: AppColors.transparent,
          child: GestureDetector(
            onTap: () {
              if (groupId.isNotEmpty && scheduleId.isNotEmpty) {
                final encodedId = Uri.encodeComponent(scheduleId);
                context.push('/group/$groupId/schedule/$encodedId');
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.calendar,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.groupSchedule.title,
                          style: context.textStyle(
                            FontSizeType.small,
                            color: AppColors.iosGray,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ScheduleStatusBadge(state: state),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: context
                        .textStyle(
                          FontSizeType.medium,
                          color: titleColor,
                          fontWeight: FontWeight.bold,
                        )
                        .copyWith(
                          decoration: isCancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (startAt > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.clock,
                          size: 12,
                          color: AppColors.iosGray,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _timeRangeText(context, startAt, endAt),
                            style: context.textStyle(
                              FontSizeType.caption2,
                              color: AppColors.iosGray,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 20),
                  if (!isCancelled && state != GroupScheduleTimeState.ended)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            t.groupSchedule.cardViewAndAttend,
                            style: context.textStyle(
                              FontSizeType.caption2,
                              color: AppColors.iosGray,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          CupertinoIcons.chevron_right,
                          size: 12,
                          color: AppColors.iosGray,
                        ),
                      ],
                    )
                  else
                    Text(
                      t.groupSchedule.cardViewDetail,
                      style: context.textStyle(
                        FontSizeType.caption2,
                        color: AppColors.iosGray,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _timeRangeText(BuildContext context, int startAt, int endAt) {
    final start = DateTime.fromMillisecondsSinceEpoch(startAt * 1000);
    // publish payload 不带 end_time：缺结束时间只展示开始，
    // 否则会渲染成"11:23 – 11:23"。
    if (endAt <= startAt) {
      return formatScheduleStartTime(context, start);
    }
    return formatScheduleTimeRange(
      context,
      start,
      DateTime.fromMillisecondsSinceEpoch(endAt * 1000),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// 卡片元数据里时间可能是 RFC3339 字符串（服务端 publish 的 payload
  /// 用 start_time=RFC3339），也可能是秒级时间戳；统一折算成秒。
  int _toEpochSec(dynamic value) {
    if (value == null) return 0;
    if (value is int) {
      return value > 1000000000000 ? value ~/ 1000 : value;
    }
    final text = value.toString().trim();
    if (text.isEmpty) return 0;
    final parsed = int.tryParse(text);
    if (parsed != null) {
      return parsed > 1000000000000 ? parsed ~/ 1000 : parsed;
    }
    final dt = DateTime.tryParse(text);
    return dt == null ? 0 : dt.millisecondsSinceEpoch ~/ 1000;
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
