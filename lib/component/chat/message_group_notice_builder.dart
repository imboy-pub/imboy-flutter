import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 群公告消息由服务端在公告发布时创建（group_notice_logic），与公告管理页
/// 共用权限边界；客户端只渲染不发送。点击进群公告页查看全文/管理。
class GroupNoticeMessageTypePlugin implements MessageTypePlugin {
  const GroupNoticeMessageTypePlugin();
  @override
  String get id => 'builtin:${MessageType.groupNotice}';
  @override
  bool get isEnabled => true;
  @override
  String get type => MessageType.groupNotice;
  @override
  MessagePluginSurface get surface => MessagePluginSurface.standalone;
  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    final metadata = message.metadata ?? {};
    final groupId = metadata['group_id']?.toString() ?? '';
    final title = (metadata['title']?.toString() ?? '').trim();
    final body = (metadata['content']?.toString() ?? '').trim();
    return Builder(
      builder: (context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppSpacing.regular),
          leading: const Icon(CupertinoIcons.speaker_2_fill),
          title: Text(title.isNotEmpty ? title : t.common.groupAnnouncement),
          subtitle: body.isEmpty
              ? null
              : Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const Icon(CupertinoIcons.chevron_right),
          onTap: groupId.isEmpty
              ? null
              : () {
                  context.push(
                    '/group/announcement',
                    extra: {'groupId': groupId},
                  );
                },
        ),
      ),
    );
  }
}
