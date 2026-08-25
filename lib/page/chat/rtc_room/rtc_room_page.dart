import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/rtc_room/rtc_room_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/call_tokens.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 群通话页（LiveKit SFU）：主画面 + 可拖拽副画面 + 成员缩略条。
///
/// 主画面永远只承载一个参与者，副画面默认是本端；点击副画面或上下
/// 滑动即可交换主次位置，拖拽后会吸附到左右边缘。这样群通话和 P2P
/// 通话拥有相同的操作心智模型。
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
  final String title;

  @override
  ConsumerState<RtcRoomPage> createState() => _RtcRoomPageState();
}

class _RtcRoomPageState extends ConsumerState<RtcRoomPage> {
  static const double _controlButtonSize = 56;
  static const double _thumbnailWidth = 120;
  static const double _thumbnailHeight = 164;
  static const double _thumbnailMargin = 12;
  static const double _memberStripHeight = 88;

  String? _mainIdentity;
  double _thumbnailRight = _thumbnailMargin;
  double _thumbnailTop = _thumbnailMargin;
  double? _dragRight;
  double? _dragTop;
  Duration _thumbnailAnimation = Duration.zero;

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
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rtcRoomProvider);
    final notifier = ref.read(rtcRoomProvider.notifier);

    ref.listen(rtcRoomProvider, (prev, next) {
      if (next.status == RtcRoomStatus.disconnected &&
          prev?.status != RtcRoomStatus.disconnected) {
        // 页面退出统一收口在这里：自己挂断不弹"通话已断开"、也由这里
        // 一次性 pop（旧实现按钮回调再 pop 一次，会把通话页下面的聊天页
        // 也弹掉）。
        if (!ref.read(rtcRoomProvider.notifier).userHangup) {
          AppLoading.showToast(t.common.callDisconnected);
        }
        if (mounted) Navigator.of(context).pop();
      }
    });

    return Scaffold(
      backgroundColor: CallTokens.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            _header(state),
            if (state.reconnecting) _reconnectingBanner(),
            Expanded(child: _participantStage(notifier.room, state)),
            _controlBar(state, notifier),
          ],
        ),
      ),
    );
  }

  Widget _header(RtcRoomState state) {
    final statusText = switch (state.status) {
      RtcRoomStatus.idle || RtcRoomStatus.connecting => t.common.connecting,
      RtcRoomStatus.connected => t.groupSchedule.participants,
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
            style: context.textStyle(
              FontSizeType.large,
              fontWeight: FontWeight.w600,
              color: CallTokens.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.verticalTiny,
          Text(
            statusText,
            style: context.textStyle(
              FontSizeType.footnote,
              color: CallTokens.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reconnectingBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.large,
        0,
        AppSpacing.large,
        AppSpacing.small,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CallTokens.whiteA12,
          borderRadius: AppRadius.borderRadiusRegular,
          border: Border.all(color: CallTokens.white30),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.regular,
            vertical: AppSpacing.small,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CallTokens.white70,
                ),
              ),
              AppSpacing.horizontalSmall,
              Text(
                t.common.reconnecting,
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: CallTokens.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _participantStage(Room? room, RtcRoomState state) {
    if (room == null) {
      if (state.status == RtcRoomStatus.failed) {
        return _connectionFailed();
      }
      return const Center(
        child: CircularProgressIndicator(color: CallTokens.white54),
      );
    }

    return ListenableBuilder(
      listenable: room,
      builder: (context, _) {
        final participants = _participants(room);
        if (participants.isEmpty) {
          return Center(
            child: Text(
              t.common.connecting,
              style: context.textStyle(
                FontSizeType.body,
                color: CallTokens.white70,
              ),
            ),
          );
        }

        final main = _mainParticipant(participants, room);
        final secondary = _secondaryParticipant(participants, room, main);
        final remaining = participants
            .where(
              (participant) =>
                  participant.identity != main.identity &&
                  participant.identity != secondary?.identity,
            )
            .toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final stageWidth = constraints.maxWidth;
            final stageHeight = constraints.maxHeight;
            final maxRight = (stageWidth - _thumbnailWidth - _thumbnailMargin)
                .clamp(_thumbnailMargin, double.infinity)
                .toDouble();
            final maxTop =
                (stageHeight -
                        _thumbnailHeight -
                        (remaining.isEmpty
                            ? _thumbnailMargin
                            : _memberStripHeight))
                    .clamp(_thumbnailMargin, double.infinity)
                    .toDouble();

            return Stack(
              fit: StackFit.expand,
              children: [
                _buildParticipantTile(main, main: true),
                if (secondary != null)
                  AnimatedPositioned(
                    duration: _thumbnailAnimation,
                    curve: Curves.easeOutCubic,
                    right: _thumbnailRight.clamp(_thumbnailMargin, maxRight),
                    top: _thumbnailTop.clamp(_thumbnailMargin, maxTop),
                    child: _buildThumbnail(
                      secondary,
                      stageWidth: stageWidth,
                      maxRight: maxRight,
                      maxTop: maxTop,
                    ),
                  ),
                if (remaining.isNotEmpty)
                  Positioned(
                    left: AppSpacing.small,
                    right: AppSpacing.small,
                    bottom: AppSpacing.small,
                    child: _buildMemberStrip(remaining),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _connectionFailed() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, color: CallTokens.white54, size: 52),
          AppSpacing.verticalMedium,
          Text(
            t.common.callDisconnected,
            style: context.textStyle(
              FontSizeType.body,
              color: CallTokens.white70,
            ),
          ),
          AppSpacing.verticalSmall,
          TextButton.icon(
            onPressed: _connect,
            icon: const Icon(Icons.refresh),
            label: Text(t.common.buttonRetry),
            style: TextButton.styleFrom(foregroundColor: CallTokens.white),
          ),
        ],
      ),
    );
  }

  List<Participant> _participants(Room room) {
    return [
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];
  }

  Participant _mainParticipant(List<Participant> participants, Room room) {
    for (final participant in participants) {
      if (participant.identity == _mainIdentity) return participant;
    }
    final remote = participants.where(
      (participant) => participant.identity != room.localParticipant?.identity,
    );
    return remote.isNotEmpty ? remote.first : participants.first;
  }

  Participant? _secondaryParticipant(
    List<Participant> participants,
    Room room,
    Participant main,
  ) {
    final local = room.localParticipant;
    if (local != null && local.identity != main.identity) return local;
    for (final participant in participants) {
      if (participant.identity != main.identity) return participant;
    }
    return null;
  }

  Widget _buildParticipantTile(Participant participant, {required bool main}) {
    final videoTrack = _videoTrack(participant);
    return ClipRRect(
      borderRadius: main ? BorderRadius.zero : AppRadius.borderRadiusRegular,
      child: ColoredBox(
        color: CallTokens.bg1A1A1A,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (videoTrack != null)
              VideoTrackRenderer(videoTrack)
            else
              Center(
                child: Icon(
                  Icons.account_circle,
                  size: main ? 88 : 56,
                  color: CallTokens.white38,
                ),
              ),
            Positioned(
              left: AppSpacing.small,
              bottom: AppSpacing.small,
              child: _participantBadge(participant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(
    Participant participant, {
    required double stageWidth,
    required double maxRight,
    required double maxTop,
  }) {
    return Semantics(
      button: true,
      label: t.common.enterFullscreen,
      child: GestureDetector(
        onTap: () => _swapWithThumbnail(participant),
        onPanStart: (_) {
          _dragRight = _thumbnailRight;
          _dragTop = _thumbnailTop;
          if (mounted) setState(() => _thumbnailAnimation = Duration.zero);
        },
        onPanUpdate: (details) {
          final right = _dragRight ?? _thumbnailRight;
          final top = _dragTop ?? _thumbnailTop;
          _dragRight = (right - details.delta.dx)
              .clamp(_thumbnailMargin, maxRight)
              .toDouble();
          _dragTop = (top + details.delta.dy)
              .clamp(_thumbnailMargin, maxTop)
              .toDouble();
          if (mounted) setState(() {});
        },
        onPanEnd: (details) {
          _finishThumbnailDrag(stageWidth, maxRight, maxTop);
          if (shouldSwapRtcVideoLayout(details.velocity.pixelsPerSecond.dy)) {
            _swapWithThumbnail(participant);
          }
        },
        child: Container(
          width: _thumbnailWidth,
          height: _thumbnailHeight,
          decoration: BoxDecoration(
            border: Border.all(color: CallTokens.white30),
            borderRadius: AppRadius.borderRadiusRegular,
            boxShadow: const [
              BoxShadow(color: CallTokens.black54, blurRadius: 12),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildParticipantTile(participant, main: false),
              const Positioned(
                top: AppSpacing.tiny,
                right: AppSpacing.tiny,
                child: Icon(
                  Icons.swap_vert,
                  color: CallTokens.white70,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _finishThumbnailDrag(double stageWidth, double maxRight, double maxTop) {
    final right = (_dragRight ?? _thumbnailRight).clamp(
      _thumbnailMargin,
      maxRight,
    );
    final top = (_dragTop ?? _thumbnailTop).clamp(_thumbnailMargin, maxTop);
    final left = stageWidth - right - _thumbnailWidth;
    final snappedLeft = snapRtcThumbnailLeft(
      currentLeft: left,
      thumbnailWidth: _thumbnailWidth,
      stageWidth: stageWidth,
      margin: _thumbnailMargin,
    );
    _dragRight = stageWidth - snappedLeft - _thumbnailWidth;
    _dragTop = top.toDouble();
    if (!mounted) return;
    setState(() {
      _thumbnailRight = _dragRight!;
      _thumbnailTop = _dragTop!;
      _thumbnailAnimation = const Duration(milliseconds: 220);
    });
  }

  void _swapWithThumbnail(Participant participant) {
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() {
      _mainIdentity = participant.identity;
      _thumbnailRight = _thumbnailMargin;
      _thumbnailTop = _thumbnailMargin;
      _dragRight = null;
      _dragTop = null;
      _thumbnailAnimation = const Duration(milliseconds: 220);
    });
  }

  Widget _participantBadge(Participant participant) {
    final name = participant.name.isNotEmpty
        ? participant.name
        : participant.identity;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: AppSpacing.tiny,
      ),
      decoration: BoxDecoration(
        color: CallTokens.blackA55,
        borderRadius: AppRadius.borderRadiusSmall,
      ),
      child: Text(
        name,
        style: context.textStyle(
          FontSizeType.caption2,
          color: CallTokens.white,
        ),
      ),
    );
  }

  Widget _buildMemberStrip(List<Participant> participants) {
    return SizedBox(
      height: _memberStripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: participants.length,
        separatorBuilder: (_, _) => AppSpacing.horizontalSmall,
        itemBuilder: (context, index) {
          final participant = participants[index];
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _mainIdentity = participant.identity);
            },
            child: SizedBox(
              width: 108,
              child: _buildParticipantTile(participant, main: false),
            ),
          );
        },
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
            icon: state.speakerOn ? Icons.volume_up : Icons.volume_off,
            label: t.main.loudspeaker,
            onPressed: notifier.toggleSpeaker,
          ),
          _controlButton(
            icon: Icons.cameraswitch,
            label: t.common.switchCamera,
            onPressed: notifier.switchCamera,
          ),
          _controlButton(
            icon: Icons.call_end,
            label: t.main.hangup,
            background: AppColors.getIosRed(Theme.of(context).brightness),
            onPressed: () async {
              // pop 由 ref.listen 统一收口（hangup 置 status=disconnected
              // 触发 listen），此处不再手动 pop，否则双重 pop 会把通话页
              // 下面的聊天页也弹掉。
              await notifier.hangup();
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

VideoTrack? _videoTrack(Participant participant) {
  for (final publication in participant.videoTrackPublications) {
    if (publication.source == TrackSource.camera &&
        publication.track != null &&
        !publication.muted) {
      return publication.track as VideoTrack?;
    }
  }
  return null;
}
