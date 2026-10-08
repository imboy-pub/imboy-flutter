import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 投票消息由服务端创建，与投票详情共用权限边界。
class GroupVoteMessageTypePlugin implements MessageTypePlugin {
  const GroupVoteMessageTypePlugin();
  @override
  String get id => 'builtin:${MessageType.groupVote}';
  @override
  bool get isEnabled => true;
  @override
  String get type => MessageType.groupVote;
  @override
  MessagePluginSurface get surface => MessagePluginSurface.standalone;
  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    final metadata = message.metadata ?? {};
    final groupId = metadata['group_id']?.toString() ?? '';
    final voteId = metadata['vote_id']?.toString() ?? '';
    return Builder(
      builder: (context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppSpacing.regular),
          leading: const Icon(CupertinoIcons.chart_bar),
          title: Text(metadata['title']?.toString() ?? t.groupVote.title),
          subtitle: Text(t.groupVote.title),
          trailing: const Icon(CupertinoIcons.chevron_right),
          onTap: groupId.isEmpty || voteId.isEmpty
              ? null
              : () {
                  context.push(
                    '/group/${Uri.encodeComponent(groupId)}/vote/${Uri.encodeComponent(voteId)}',
                  );
                },
        ),
      ),
    );
  }
}
