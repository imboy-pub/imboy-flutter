import 'dart:ui';
import 'package:imboy/theme/default/app_spacing.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:imboy/component/helper/func.dart' show avatarImageProvider;
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/call_tokens.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 全屏来电界面（FaceTime / iOS 风格）。
class IncomingCallView extends StatefulWidget {
  final String avatar;
  final String nickname;

  /// 'video' | 'audio'，决定接听按钮图标与副标题文案。
  final String media;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallView({
    super.key,
    required this.avatar,
    required this.nickname,
    required this.media,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<IncomingCallView> createState() => _IncomingCallViewState();
}

class _IncomingCallViewState extends State<IncomingCallView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0.5;
    } else if (!reduceMotion && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  bool get _isVideo => widget.media == 'video';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildBlurredBackground(),
          // 顶部信息
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: size.height * 0.18),
              child: Column(
                children: [
                  _buildPulsingAvatar(),
                  const SizedBox(height: 26),
                  Text(
                    widget.nickname,
                    style: context
                        .textStyle(
                          FontSizeType.extraLargeTitle,
                          fontWeight: FontWeight.w600,
                          color: CallTokens.white,
                        )
                        .copyWith(letterSpacing: 0.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppSpacing.verticalMedium,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isVideo
                            ? CupertinoIcons.videocam
                            : CupertinoIcons.phone,
                        size: 17,
                        color: CallTokens.white70,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        t.common.incomingCall(
                          param: _isVideo ? t.chat.video : t.main.audio,
                        ),
                        style: context.textStyle(
                          FontSizeType.subheadline,
                          color: CallTokens.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 底部接听 / 拒接
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 48, 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAction(
                      icon: CupertinoIcons.phone_down_circle_fill,
                      label: t.common.declineCall,
                      background: AppColors.getIosRed(
                        MediaQuery.of(context).platformBrightness,
                      ),
                      onTap: widget.onDecline,
                    ),
                    _buildAction(
                      icon: _isVideo
                          ? CupertinoIcons.videocam
                          : CupertinoIcons.phone,
                      label: t.common.answer,
                      background: AppColors.getIosGreen(
                        MediaQuery.of(context).platformBrightness,
                      ),
                      onTap: widget.onAccept,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurredBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          image: avatarImageProvider(widget.avatar, w: 600),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(color: CallTokens.bgDeep),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  CallTokens.blackA55,
                  CallTokens.blackA35,
                  CallTokens.blackA75,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPulsingAvatar() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glow = 0.25 + _pulse.value * 0.35;
        final spread = 2.0 + _pulse.value * 12.0;
        return Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: CallTokens.white24, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: glow),
                blurRadius: 30,
                spreadRadius: spread,
              ),
            ],
          ),
          child: child,
        );
      },
      child: ClipOval(
        child: Avatar(imgUri: widget.avatar, width: 128, height: 128),
      ),
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String label,
    required Color background,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: background.withValues(alpha: 0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                onTap();
              },
              child: SizedBox(
                width: 72,
                height: 72,
                child: Icon(icon, color: CallTokens.white, size: 34),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: context.textStyle(
              FontSizeType.footnote,
              color: CallTokens.white70,
            ),
          ),
        ],
      ),
    );
  }
}
