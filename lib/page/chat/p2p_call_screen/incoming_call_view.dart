import 'dart:ui';
import 'package:imboy/theme/default/app_spacing.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:imboy/component/helper/func.dart' show avatarImageProvider;
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/call_tokens.dart';

/// 全屏来电界面（FaceTime / iOS 风格）。
///
/// 纯表现层：仅负责呈现与动效，接听 / 拒接的信令逻辑由调用方通过
/// [onAccept] / [onDecline] 回调注入（见 component/webrtc/func.dart）。
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
    // 尊重系统“减弱动态效果”(WCAG 2.3.3): 关闭无限呼吸动画，定格稳态光环。
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
    final size = MediaQuery.of(context).size;
    final brightness = Theme.of(context).brightness;

    return Material(
      color: CallTokens.black,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBlurredBackground(),
            // 顶部信息：大头像（呼吸光环）+ 昵称 + 来电类型
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(top: size.height * 0.18),
                child: Column(
                  children: [
                    _buildPulsingAvatar(),
                    const SizedBox(height: 26),
                    Text(
                      widget.nickname,
                      style: const TextStyle(
                        color: CallTokens.white,
                        fontSize: CallTokens.fs28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.verticalMedium,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isVideo ? Icons.videocam : Icons.call,
                          size: 17,
                          color: CallTokens.white70,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          t.common.incomingCall(
                            param: _isVideo ? t.chat.video : t.main.audio,
                          ),
                          style: const TextStyle(
                            color: CallTokens.white70,
                            fontSize: CallTokens.fs15,
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
                        icon: Icons.call_end,
                        label: t.common.declineCall,
                        background: AppColors.getIosRed(brightness),
                        onTap: widget.onDecline,
                      ),
                      _buildAction(
                        icon: _isVideo ? Icons.videocam : Icons.phone,
                        label: t.common.answer,
                        background: AppColors.getIosGreen(brightness),
                        onTap: widget.onAccept,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 对方头像高斯模糊铺底 + 深色压暗，营造景深（FaceTime 观感）。
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

  /// 大号实心圆形动作按钮（72pt）+ 文字标签，带触感反馈与无障碍语义。
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
          Material(
            color: background,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            elevation: 8,
            shadowColor: background.withValues(alpha: 0.6),
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                onTap();
              },
              customBorder: const CircleBorder(),
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
            style: const TextStyle(
              color: CallTokens.white70,
              fontSize: CallTokens.fs13,
            ),
          ),
        ],
      ),
    );
  }
}
