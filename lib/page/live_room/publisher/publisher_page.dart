import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/live_room/publisher/publisher_provider.dart'
    show publisherProvider;
import 'package:imboy/store/model/live_room_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// WHIP Publisher 推流页面
/// 使用 WHIP 协议（WebRTC-HTTP Ingestion Protocol）向媒体服务器推送音视频流
class PublisherPage extends ConsumerStatefulWidget {
  /// 关联的直播间（从列表页跳转时传入）
  final LiveRoomModel? room;

  const PublisherPage({super.key, this.room});

  @override
  ConsumerState<PublisherPage> createState() => _PublisherPageState();
}

class _PublisherPageState extends ConsumerState<PublisherPage> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final TextEditingController _serverController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_initRenderers());
    // 若传入了 room，将 roomId 注入到 provider
    if (widget.room != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(publisherProvider.notifier).setRoom(widget.room!);
      });
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
  }

  @override
  void dispose() {
    _serverController.dispose();
    if (_localRenderer.textureId != null) {
      _localRenderer.srcObject = null;
      _localRenderer.dispose();
    }
    // 离开页面时停止推流
    ref.read(publisherProvider.notifier).stopPublish(_localRenderer);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(publisherProvider);

    if (_serverController.text != state.serverUrl) {
      _serverController.text = state.serverUrl;
    }

    final roomTitle = widget.room?.title ?? 'WHIP Publisher';

    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        titleWidget: Text(roomTitle),
        rightDMActions: const [],
      ),
      body: Column(
        children: [
          // 本地视频预览
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: Colors.black,
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
                // 状态覆盖层
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.small,
                      vertical: AppSpacing.tiny,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: AppRadius.borderRadiusTiny,
                    ),
                    child: Text(
                      state.stateStr,
                      style: TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: FontSizeType.small.size,
                      ),
                    ),
                  ),
                ),
                // 房间 stream_key 提示
                if (widget.room != null && widget.room!.streamKey.isNotEmpty)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.small,
                        vertical: AppSpacing.tiny,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: AppRadius.borderRadiusTiny,
                      ),
                      child: Text(
                        'Key: ${'*' * 8}',
                        style: TextStyle(
                          color: AppColors.darkTextPrimary,
                          fontSize: FontSizeType.tiny.size,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 控制面板
          Container(
            padding: const EdgeInsets.all(AppSpacing.regular),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 服务器地址输入
                TextField(
                  controller: _serverController,
                  decoration: InputDecoration(
                    labelText: t.main.liveRoomWhipLabel,
                    hintText: 'http://your-server/whip/publish/live/stream1',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (v) {
                    ref.read(publisherProvider.notifier).saveServerUrl(v);
                  },
                ),
                const SizedBox(height: 12),
                // 推流/停止按钮
                ElevatedButton.icon(
                  onPressed: state.isConnecting
                      ? null
                      : () async {
                          if (state.stateStr == 'publishing') {
                            await ref
                                .read(publisherProvider.notifier)
                                .stopPublish(_localRenderer);
                          } else {
                            await ref
                                .read(publisherProvider.notifier)
                                .startPublish(_localRenderer);
                          }
                        },
                  icon: Icon(
                    state.stateStr == 'publishing'
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outlined,
                  ),
                  label: Text(
                    state.isConnecting
                        ? '连接中...'
                        : state.stateStr == 'publishing'
                        ? '停止推流'
                        : '开始推流',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.stateStr == 'publishing'
                        ? AppColors.getIosRed(Theme.of(context).brightness)
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
