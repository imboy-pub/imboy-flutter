import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 作业消息由服务端创建，与作业详情共用权限边界。
class GroupTaskMessageTypePlugin implements MessageTypePlugin {
  const GroupTaskMessageTypePlugin();
  @override
  String get id => 'builtin:${MessageType.groupTask}';
  @override
  bool get isEnabled => true;
  @override
  String get type => MessageType.groupTask;
  @override
  MessagePluginSurface get surface => MessagePluginSurface.standalone;
  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    final metadata = message.metadata ?? {};
    final groupId = metadata['group_id']?.toString() ?? '';
    final taskId = metadata['id']?.toString() ?? '';
    return Builder(
      builder: (context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppSpacing.regular),
          leading: const Icon(CupertinoIcons.doc_text),
          title: Text(metadata['title']?.toString() ?? t.groupTask.title),
          subtitle: Text(t.groupTask.title),
          trailing: const Icon(CupertinoIcons.chevron_right),
          onTap: groupId.isEmpty || taskId.isEmpty
              ? null
              : () {
                  context.push(
                    '/group/${Uri.encodeComponent(groupId)}/task/${Uri.encodeComponent(taskId)}',
                  );
                },
        ),
      ),
    );
  }
}
