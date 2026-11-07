import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:imboy/component/webrtc/media_permission.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/call_tokens.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 顶部“网络不佳，正在重连…”横幅（接通后 Room Reconnecting/Resuming 时显示）。
/// 数据源是真实连接态，非伪造信号格，断连时不会误显“良好”。
class P2pCallReconnectingBanner extends StatelessWidget {
  const P2pCallReconnectingBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(color: CallTokens.blackA55),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CupertinoActivityIndicator(color: CallTokens.white70),
                ),
                AppSpacing.horizontalSmall,
                Text(
                  message,
                  style: context.textStyle(
                    // fs13(13) 精确匹配 footnote(13)
                    FontSizeType.footnote,
                    color: CallTokens.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// NET-06 轻度质量提示：非遮挡、不阻挡任何控制（重连横幅负责中断档）。
class P2pCallNetworkUnstableBanner extends StatelessWidget {
  const P2pCallNetworkUnstableBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(color: CallTokens.blackA55),
            child: Text(
              message,
              style: context.textStyle(
                FontSizeType.footnote,
                color: CallTokens.white70,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class P2pCallMediaErrorBanner extends StatelessWidget {
  const P2pCallMediaErrorBanner({
    super.key,
    required this.message,
    required this.permissionTarget,
    required this.settingsLabel,
  });

  final String message;
  final MediaPermissionTarget? permissionTarget;
  final String settingsLabel;

  @override
  Widget build(BuildContext context) {
    final target = permissionTarget;
    return Positioned(
      left: 16,
      right: 16,
      bottom: 116,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          decoration: BoxDecoration(
            color: CallTokens.blackA75,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CallTokens.white24),
          ),
          child: Row(
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_circle,
                color: CallTokens.white70,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: CallTokens.white,
                  ),
                ),
              ),
              if (target != null)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () =>
                      unawaited(openMediaPermissionSettings(target)),
                  child: Text(
                    settingsLabel,
                    style: context.textStyle(
                      FontSizeType.footnote,
                      color: CallTokens.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
