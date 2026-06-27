import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/theme_manager.dart';

/// 语音录制动作状态
enum VoiceActionState {
  send, // 松开发送
  cancel, // 松开取消
  convert, // 松开转文字
}

/// 语音录制悬浮层（高保真微信风格）
class CustomOverlay extends StatelessWidget {
  final Widget? icon;
  final BoxDecoration? decoration;
  final double width;
  final double height;
  final List<double>? waveform;
  final String durationText;
  final VoiceActionState actionState; // 当前手势选中的动作
  final double currentDecibels; // 当前分贝值
  final RecorderController? recorderController; // AudioWaveforms 控制器

  const CustomOverlay({
    super.key,
    this.icon,
    this.waveform,
    this.durationText = '00:00.000',
    this.decoration,
    this.width = 260,
    this.height = 140,
    this.actionState = VoiceActionState.send,
    this.currentDecibels = -60.0,
    this.recorderController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.instance;
    final textColor = theme.getThemeColor('onSurface');
    final primaryColor = theme.getThemeColor('primary');
    final errorColor = theme.getThemeColor('error');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screenSize = MediaQuery.of(context).size;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.4), // 微暗的磨砂遮罩背景
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. 中间状态提示框
            Positioned(
              top: screenSize.height * 0.3,
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 150),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: Opacity(
                      opacity: value,
                      child: Container(
                        width: 260,
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2C2C2C)
                              : const Color(0xFFF7F7F7),
                          borderRadius: AppRadius.borderRadiusLarge,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (actionState == VoiceActionState.cancel) ...[
                              // 取消发送状态
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: errorColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.delete_outline,
                                  color: errorColor,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                t.chat.voiceReleaseCancelSend,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ] else if (actionState ==
                                VoiceActionState.convert) ...[
                              // 转文字状态
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.translate,
                                  color: Colors.amber,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                t.chat.releaseConvertToText,
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // 模拟语音转文字动画气泡
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.08),
                                  borderRadius: AppRadius.borderRadiusMedium,
                                ),
                                child: Text(
                                  t.common.voiceSttConverting,
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.7),
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ] else ...[
                              // 正常录音状态
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.mic,
                                  color: primaryColor,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                durationText,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'SF Mono',
                                ),
                              ),
                              const SizedBox(height: 8),
                              // 声波展示
                              SizedBox(
                                height: 32,
                                width: 180,
                                child: AudioWaveforms(
                                  enableGesture: false,
                                  size: const Size(180, 32),
                                  recorderController:
                                      recorderController ??
                                      RecorderController(),
                                  waveStyle: WaveStyle(
                                    waveColor: primaryColor,
                                    showMiddleLine: false,
                                    spacing: 3.0,
                                    waveThickness: 1.5,
                                    extendWaveform: true,
                                    scaleFactor: 35.0,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 2. 左侧圆形动作按钮目标（取消）
            Positioned(
              left: 45,
              bottom: 160,
              child: _buildActionTarget(
                icon: Icons.close,
                label: t.common.buttonCancel,
                activeColor: errorColor,
                isActive: actionState == VoiceActionState.cancel,
                isDark: isDark,
              ),
            ),

            // 3. 右侧圆形动作按钮目标（转文字）
            Positioned(
              right: 45,
              bottom: 160,
              child: _buildActionTarget(
                icon: Icons.translate,
                label: t.chat.convertToText,
                activeColor: Colors.amber, // 金黄色/琥珀色对齐转文字的温馨视觉
                isActive: actionState == VoiceActionState.convert,
                isDark: isDark,
              ),
            ),

            // 4. 底部动态动作提示语
            Positioned(
              bottom: 80,
              child: Text(
                actionState == VoiceActionState.cancel
                    ? t.chat.voiceReleaseCancel
                    : (actionState == VoiceActionState.convert
                          ? t.chat.releaseConvertToText
                          : t.chat.voiceSlideHint),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTarget({
    required IconData icon,
    required String label,
    required Color activeColor,
    required bool isActive,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: isActive ? 72 : 56,
          height: isActive ? 72 : 56,
          decoration: BoxDecoration(
            color: isActive
                ? activeColor
                : (isDark ? const Color(0xFF333333) : const Color(0xFFEAEAEA)),
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: isActive
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black54),
            size: isActive ? 32 : 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? activeColor : Colors.white60,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
