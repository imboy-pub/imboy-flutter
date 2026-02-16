/// 网络质量指示器组件
///
/// 实时显示 WebRTC 通话的网络质量状态
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/webrtc/connection/connection_manager.dart';
import 'package:imboy/component/webrtc/quality/quality_config.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 网络质量指示器组件
class WebRTCNetworkQualityIndicator extends ConsumerStatefulWidget {
  final String sessionId;

  const WebRTCNetworkQualityIndicator({
    super.key,
    required this.sessionId,
  });

  @override
  ConsumerState<WebRTCNetworkQualityIndicator> createState() =>
      _WebRTCNetworkQualityIndicatorState();
}

class _WebRTCNetworkQualityIndicatorState
    extends ConsumerState<WebRTCNetworkQualityIndicator> {
  @override
  Widget build(BuildContext context) {
    // 如果连接管理器没有该会话，显示空组件
    final connection = WebRTCConnectionManager.instance.getConnection(widget.sessionId);
    if (connection == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<int>(
      stream: connection.qualityScoreStream,
      initialData: 100,
      builder: (context, snapshot) {
        final score = snapshot.data ?? 100;
        return _buildIndicator(score);
      },
    );
  }

  Widget _buildIndicator(int score) {
    final quality = WebRTCQualityConfig.defaultConfig()
        .getNetworkQuality(score);

    final config = _getQualityConfig(quality);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.15),
        borderRadius: AppRadius.borderRadiusSmall,
        border: Border.all(
          color: config.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            color: config.color,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            config.label,
            style: TextStyle(
              color: config.color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (score < 80) ...[
            const SizedBox(width: 6),
            Text(
              '($score)',
              style: TextStyle(
                color: config.color.withValues(alpha: 0.8),
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 获取质量配置
  _QualityConfig _getQualityConfig(WebRTCNetworkQuality quality) {
    switch (quality) {
      case WebRTCNetworkQuality.excellent:
        return const _QualityConfig(
          icon: Icons.signal_wifi_4_bar,
          color: Color(0xFF4CAF50),
          label: '优秀',
        );
      case WebRTCNetworkQuality.good:
        return const _QualityConfig(
          icon: Icons.network_wifi_3_bar,
          color: Color(0xFF8BC34A),
          label: '良好',
        );
      case WebRTCNetworkQuality.fair:
        return const _QualityConfig(
          icon: Icons.network_wifi_2_bar,
          color: Color(0xFFFF9800),
          label: '一般',
        );
      case WebRTCNetworkQuality.poor:
        return const _QualityConfig(
          icon: Icons.network_wifi_1_bar,
          color: Color(0xFFF44336),
          label: '较差',
        );
    }
  }
}

/// 质量配置（内部类）
class _QualityConfig {
  final IconData icon;
  final Color color;
  final String label;

  const _QualityConfig({
    required this.icon,
    required this.color,
    required this.label,
  });
}

/// 简化版网络质量指示器（仅显示图标）
class SimpleNetworkQualityIndicator extends StatelessWidget {
  final int qualityScore;
  final double size;

  const SimpleNetworkQualityIndicator({
    super.key,
    required this.qualityScore,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final quality = WebRTCQualityConfig.defaultConfig()
        .getNetworkQuality(qualityScore);

    final config = _getQualityConfig(quality);

    return Icon(
      config.icon,
      color: config.color,
      size: size,
    );
  }

  /// 获取质量配置
  _QualityConfig _getQualityConfig(WebRTCNetworkQuality quality) {
    switch (quality) {
      case WebRTCNetworkQuality.excellent:
        return const _QualityConfig(
          icon: Icons.signal_wifi_4_bar,
          color: Color(0xFF4CAF50),
          label: '优秀',
        );
      case WebRTCNetworkQuality.good:
        return const _QualityConfig(
          icon: Icons.network_wifi_3_bar,
          color: Color(0xFF8BC34A),
          label: '良好',
        );
      case WebRTCNetworkQuality.fair:
        return const _QualityConfig(
          icon: Icons.network_wifi_2_bar,
          color: Color(0xFFFF9800),
          label: '一般',
        );
      case WebRTCNetworkQuality.poor:
        return const _QualityConfig(
          icon: Icons.network_wifi_1_bar,
          color: Color(0xFFF44336),
          label: '较差',
        );
    }
  }
}

/// 网络质量进度条组件
class NetworkQualityProgressBar extends StatelessWidget {
  final int qualityScore;
  final double? width;
  final double height;
  final bool showLabel;

  const NetworkQualityProgressBar({
    super.key,
    required this.qualityScore,
    this.width,
    this.height = 4,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final quality = WebRTCQualityConfig.defaultConfig()
        .getNetworkQuality(qualityScore);
    final config = _getQualityConfig(quality);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel)
          Text(
            config.label,
            style: TextStyle(
              color: config.color,
              fontSize: 10,
            ),
          ),
        if (showLabel) const SizedBox(height: 4),
        Container(
          width: width ?? 80,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: LinearProgressIndicator(
              value: qualityScore / 100,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(config.color),
              minHeight: height,
            ),
          ),
        ),
      ],
    );
  }

  /// 获取质量配置
  _QualityConfig _getQualityConfig(WebRTCNetworkQuality quality) {
    switch (quality) {
      case WebRTCNetworkQuality.excellent:
        return const _QualityConfig(
          icon: Icons.signal_wifi_4_bar,
          color: Color(0xFF4CAF50),
          label: '优秀',
        );
      case WebRTCNetworkQuality.good:
        return const _QualityConfig(
          icon: Icons.network_wifi_3_bar,
          color: Color(0xFF8BC34A),
          label: '良好',
        );
      case WebRTCNetworkQuality.fair:
        return const _QualityConfig(
          icon: Icons.network_wifi_2_bar,
          color: Color(0xFFFF9800),
          label: '一般',
        );
      case WebRTCNetworkQuality.poor:
        return const _QualityConfig(
          icon: Icons.network_wifi_1_bar,
          color: Color(0xFFF44336),
          label: '较差',
        );
    }
  }
}
