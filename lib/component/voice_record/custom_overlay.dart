import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/theme_manager.dart';

/// 语音录制悬浮层
class CustomOverlay extends StatelessWidget {
  final Widget? icon;
  final BoxDecoration? decoration;
  final double width;
  final double height;
  final List<double>? waveform;
  final String durationText;
  final bool isCancelling; // 是否处于取消状态
  final bool isRecording; // 是否正在录音
  final double currentDecibels; // 当前分贝值，用于实时响应声音大小变化
  final RecorderController? recorderController; // AudioWaveforms 控制器

  const CustomOverlay({
    super.key,
    this.icon,
    this.waveform,
    this.durationText = '00:00.000',
    this.decoration,
    this.width = 240,
    this.height = 140,
    this.isCancelling = false,
    this.isRecording = true,
    this.currentDecibels = -60.0, // 默认值
    this.recorderController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.instance;
    final bgColor = theme.getThemeColor('surfaceContainerHigh');
    final textColor = theme.getThemeColor('onSurface');
    final primaryColor = theme.getThemeColor('primary');
    final errorColor = theme.getThemeColor('error');

    return Positioned(
      top: MediaQuery.of(context).size.height * 0.35,
      left: MediaQuery.of(context).size.width * 0.5 - width / 2,
      child: Material(
        type: MaterialType.transparency,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 200),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Opacity(
                opacity: value,
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: AppRadius.borderRadiusLarge,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      // 状态图标和动画
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isCancelling ? errorColor : primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isCancelling ? errorColor : primaryColor)
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          isCancelling ? Icons.delete_outline : Icons.mic,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 波形显示区域
                      Container(
                        width: width - 40, // 明确设置宽度以匹配可用空间
                        height: 64,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        child: isCancelling
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    color: errorColor,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '松开取消',
                                    style: TextStyle(
                                      color: errorColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              )
                            : Container(
                                width: width - 40,
                                height: 60,
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: (width - 40) / 2,
                                      height: 60,
                                      child: AudioWaveforms(
                                        enableGesture: false,
                                        size: Size((width - 40) / 2, 60),
                                        recorderController:
                                            recorderController ??
                                            RecorderController(),
                                        waveStyle: WaveStyle(
                                          waveColor: primaryColor,
                                          showMiddleLine: false, // 禁用中间线以避免干扰
                                          spacing: 4.0,
                                          waveThickness: 1.0,
                                          extendWaveform: true, // 扩展波形以填充整个宽度
                                          scaleFactor: 30.0, // 增加缩放因子使波形更明显
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),

                      const SizedBox(height: 12),

                      // 时间显示
                      Text(
                        durationText,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),

                      const SizedBox(height: 4),

                      // 提示文字
                      Text(
                        isCancelling ? '上滑取消发送' : '上滑取消',
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
