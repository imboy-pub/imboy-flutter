import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/page/workspace/workspace_channel_detail_page.dart';

import 'channel_detail_page.dart';
import 'channel_di_provider.dart';

/// 外部资源引用先读取权威快照，不能凭转发卡片切换全局空间。
class ChannelLinkTargetPage extends ConsumerStatefulWidget {
  const ChannelLinkTargetPage({super.key, required this.channelId});
  final String channelId;
  @override
  ConsumerState<ChannelLinkTargetPage> createState() =>
      _ChannelLinkTargetState();
}

class _ChannelLinkTargetState extends ConsumerState<ChannelLinkTargetPage> {
  late Future<ChannelModel?> _target;
  @override
  void initState() {
    super.initState();
    _target = ref.read(channelServiceProvider).refreshChannel(widget.channelId);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ChannelModel?>(
    future: _target,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(
          body: Center(child: CupertinoActivityIndicator()),
        );
      }
      final channel = snapshot.data;
      if (channel == null) {
        return Scaffold(
          appBar: AppBar(title: Text(context.t.channel.title)),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.t.common.loadError),
                TextButton(
                  onPressed: () => setState(() {
                    _target = ref
                        .read(channelServiceProvider)
                        .refreshChannel(widget.channelId);
                  }),
                  child: Text(context.t.common.retry),
                ),
              ],
            ),
          ),
        );
      }
      if (channel.scope == 'workspace' && channel.workspaceId != null) {
        return WorkspaceChannelDetailPage(
          channelId: widget.channelId,
          workspaceId: channel.workspaceId,
        );
      }
      return ChannelDetailPage(channelId: widget.channelId);
    },
  );
}
