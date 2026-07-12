import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/call_tokens.dart';
import 'package:imboy/page/chat/rtc_room/rtc_room_provider.dart';

/// 群通话页（LiveKit SFU）：参与者网格 + 底部控制条
class RtcRoomPage extends ConsumerStatefulWidget {
  const RtcRoomPage({
    super.key,
    required this.wsUrl,
    required this.token,
    required this.roomName,
    this.title = '',
  });

  final String wsUrl;
  final String token;
  final String roomName;

  /// 页面标题（群名称），空则显示房间名
  final String title;

  @override
  ConsumerState<RtcRoomPage> createState() => _RtcRoomPageState();
}

class _RtcRoomPageState extends ConsumerState<RtcRoomPage> {
  static const double _controlButtonSize = 56;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  Future<void> _connect() async {
    final ok = await ref
        .read(rtcRoomProvider.notifier)
        .connect(wsUrl: widget.wsUrl, token: widget.token);
    if (!ok && mounted) {
      AppLoading.showError(t.common.operationFailedAgainLater);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rtcRoomProvider);
    final notifier = ref.read(rtcRoomProvider.notifier);

    // 通话中被断开（服务不可达/被踢）→ 提示并退出
    ref.listen(rtcRoomProvider, (prev, next) {
      if (next.status == RtcRoomStatus.disconnected &&
          prev?.status == RtcRoomStatus.connected) {
        AppLoading.showToast(t.common.callDisconnected);
        if (mounted) Navigator.of(context).pop();
      }
    });

    return Scaffold(
      backgroundColor: CallTokens.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            _header(state),
            Expanded(child: _participantGrid(notifier.room)),
            _controlBar(state, notifier),
          ],
        ),
      ),
    );
  }

  Widget _header(RtcRoomState state) {
    final statusText = switch (state.status) {
      RtcRoomStatus.idle || RtcRoomStatus.connecting => t.common.connecting,
      RtcRoomStatus.connected => widget.roomName,
      RtcRoomStatus.failed ||
      RtcRoomStatus.disconnected => t.common.callDisconnected,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.large,
        vertical: AppSpacing.regular,
      ),
      child: Column(
        children: [
          Text(
            widget.title.isNotEmpty ? widget.title : widget.roomName,
            style: const TextStyle(
              color: CallTokens.white,
              fontSize: CallTokens.fs18,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.verticalTiny,
          Text(
            statusText,
            style: const TextStyle(
              color: CallTokens.white60,
              fontSize: CallTokens.fs12,
            ),
          ),
        ],
      ),
    );
  }

  /// 参与者网格：本地 + 远端；Room 是 ChangeNotifier，
  /// 参与者/轨道变化直接驱动重建，无需在 Provider 里复刻状态。
  Widget _participantGrid(Room? room) {
    if (room == null) {
      return const Center(
        child: CircularProgressIndicator(color: CallTokens.white54),
      );
    }
    return ListenableBuilder(
      listenable: room,
      builder: (context, _) {
        final participants = <Participant>[
          if (room.localParticipant != null) room.localParticipant!,
          ...room.remoteParticipants.values,
        ];
        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.small),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: participants.length <= 1 ? 1 : 2,
            mainAxisSpacing: AppSpacing.small,
            crossAxisSpacing: AppSpacing.small,
          ),
          itemCount: participants.length,
          itemBuilder: (_, i) => _participantTile(participants[i]),
        );
      },
    );
  }

  Widget _participantTile(Participant participant) {
    VideoTrack? videoTrack;
    for (final pub in participant.videoTrackPublications) {
      if (pub.source == TrackSource.camera && pub.track != null && !pub.muted) {
        videoTrack = pub.track as VideoTrack?;
        break;
      }
    }
    return ClipRRect(
      borderRadius: AppRadius.borderRadiusRegular,
      child: Container(
        color: CallTokens.bg1A1A1A,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (videoTrack != null)
              VideoTrackRenderer(videoTrack)
            else
              const Center(
                child: Icon(
                  Icons.account_circle,
                  size: 64,
                  color: CallTokens.white38,
                ),
              ),
            // 左下角昵称/身份标识
            Positioned(
              left: AppSpacing.small,
              bottom: AppSpacing.small,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.small,
                  vertical: AppSpacing.tiny,
                ),
                decoration: BoxDecoration(
                  color: CallTokens.blackA45,
                  borderRadius: AppRadius.borderRadiusSmall,
                ),
                child: Text(
                  participant.name.isNotEmpty
                      ? participant.name
                      : participant.identity,
                  style: const TextStyle(
                    color: CallTokens.white,
                    fontSize: CallTokens.fs11,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlBar(RtcRoomState state, RtcRoomNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.large,
        vertical: AppSpacing.regular,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _controlButton(
            icon: state.micOn ? Icons.mic : Icons.mic_off,
            label: t.common.microphone,
            onPressed: notifier.toggleMic,
          ),
          _controlButton(
            icon: state.cameraOn ? Icons.videocam : Icons.videocam_off,
            label: t.main.camera,
            onPressed: notifier.toggleCamera,
          ),
          _controlButton(
            icon: Icons.cameraswitch,
            label: t.common.switchCamera,
            onPressed: notifier.switchCamera,
          ),
          _controlButton(
            icon: Icons.call_end,
            label: t.main.hangup,
            background: AppColors.iosRed,
            onPressed: () async {
              await notifier.hangup();
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required Future<void> Function() onPressed,
    Color background = CallTokens.whiteA12,
  }) {
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: _controlButtonSize,
            height: _controlButtonSize,
            child: Icon(icon, color: CallTokens.white, size: 26),
          ),
        ),
      ),
    );
  }
}
