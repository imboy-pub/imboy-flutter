import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/live_room/subscriber/subscriber_provider.dart'
    show subscriberProvider;
import 'package:imboy/store/model/live_room_model.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// WHEP Subscriber 拉流页面
/// 使用 WHEP 协议（WebRTC-HTTP Egress Protocol）从媒体服务器拉取音视频流
class SubscriberPage extends ConsumerStatefulWidget {
  /// 要观看的直播间（从列表页跳转时传入）
  final LiveRoomModel? room;

  const SubscriberPage({super.key, this.room});

  @override
  ConsumerState<SubscriberPage> createState() => _SubscriberPageState();
}

class _SubscriberPageState extends ConsumerState<SubscriberPage> {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final TextEditingController _serverController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_initRenderers());
  }

  Future<void> _initRenderers() async {
    await _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _remoteRenderer.srcObject = null;
    _remoteRenderer.dispose();
    // 离开页面时停止拉流
    ref.read(subscriberProvider.notifier).stopSubscribe(_remoteRenderer);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriberProvider);

    if (_serverController.text != state.serverUrl) {
      _serverController.text = state.serverUrl;
    }

    final roomTitle = widget.room?.title ?? 'WHEP Subscriber';

    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        titleWidget: Text(roomTitle),
        rightDMActions: [
          // 显示当前观看人数（若有房间信息）
          if (widget.room != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  const Icon(Icons.remove_red_eye, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    '${widget.room!.viewerCount}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 远端视频渲染区
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: Colors.black,
                  child: RTCVideoView(
                    _remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
                // 状态覆盖层
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: AppRadius.borderRadiusTiny,
                    ),
                    child: Text(
                      state.stateStr,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 控制面板
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 服务器地址输入
                TextField(
                  controller: _serverController,
                  decoration: InputDecoration(
                    labelText: t.main.liveRoomWhepLabel,
                    hintText:
                        'https://your-server/whep/subscribe/room_id/stream_id',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (v) {
                    ref.read(subscriberProvider.notifier).saveServerUrl(v);
                  },
                ),
                const SizedBox(height: 12),
                // 播放/停止按钮
                ElevatedButton.icon(
                  onPressed: state.isConnecting
                      ? null
                      : () async {
                          if (state.stateStr == 'playing') {
                            await ref
                                .read(subscriberProvider.notifier)
                                .stopSubscribe(_remoteRenderer);
                          } else {
                            await ref
                                .read(subscriberProvider.notifier)
                                .startSubscribe(_remoteRenderer);
                          }
                        },
                  icon: Icon(
                    state.stateStr == 'playing'
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outlined,
                  ),
                  label: Text(
                    state.isConnecting
                        ? '连接中...'
                        : state.stateStr == 'playing'
                        ? '停止播放'
                        : '开始播放',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.stateStr == 'playing'
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
