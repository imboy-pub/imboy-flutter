/// 连接状态组件
///
/// 显示 WebRTC 连接状态的组件
library;

import 'package:flutter/material.dart';
import 'package:imboy/component/webrtc/connection/connection_state.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// WebRTC 连接状态组件
class WebRTCConnectionStatusWidget extends StatelessWidget {
  final WebRTCConnectionState state;
  final String? errorMessage;
  final VoidCallback? onTap;

  const WebRTCConnectionStatusWidget({
    super.key,
    required this.state,
    this.errorMessage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getStateConfig(state);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: config.color.withValues(alpha: 0.1),
          borderRadius: AppRadius.borderRadiusSmall,
          border: Border.all(
            color: config.color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (config.showIndicator)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(config.color),
                ),
              ),
            if (config.showIndicator) const SizedBox(width: 8),
            Icon(
              config.icon,
              color: config.color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              config.label,
              style: TextStyle(
                color: config.color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (errorMessage != null && errorMessage!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  errorMessage!,
                  style: TextStyle(
                    color: config.color.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 根据连接状态获取配置
  _StateConfig _getStateConfig(WebRTCConnectionState state) {
    switch (state) {
      case WebRTCConnectionState.initializing:
      case WebRTCConnectionState.ready:
      case WebRTCConnectionState.creatingOffer:
      case WebRTCConnectionState.creatingAnswer:
      case WebRTCConnectionState.connecting:
        return const _StateConfig(
          icon: Icons.sync,
          color: Colors.blue,
          label: '连接中',
          showIndicator: true,
        );

      case WebRTCConnectionState.connected:
        return const _StateConfig(
          icon: Icons.check_circle,
          color: Colors.green,
          label: '已连接',
          showIndicator: false,
        );

      case WebRTCConnectionState.reconnecting:
        return const _StateConfig(
          icon: Icons.sync_problem,
          color: Colors.orange,
          label: '重连中',
          showIndicator: true,
        );

      case WebRTCConnectionState.failed:
        return const _StateConfig(
          icon: Icons.error,
          color: Colors.red,
          label: '连接失败',
          showIndicator: false,
        );

      case WebRTCConnectionState.disconnected:
        return const _StateConfig(
          icon: Icons.link_off,
          color: Colors.orange,
          label: '已断开',
          showIndicator: false,
        );

      case WebRTCConnectionState.closing:
      case WebRTCConnectionState.closed:
        return const _StateConfig(
          icon: Icons.cancel,
          color: Colors.grey,
          label: '已结束',
          showIndicator: false,
        );

      default:
        return const _StateConfig(
          icon: Icons.help,
          color: Colors.grey,
          label: '未知',
          showIndicator: false,
        );
    }
  }
}

/// 状态配置
class _StateConfig {
  final IconData icon;
  final Color color;
  final String label;
  final bool showIndicator;

  const _StateConfig({
    required this.icon,
    required this.color,
    required this.label,
    this.showIndicator = false,
  });
}

/// 简化的状态徽章组件
class ConnectionStateBadge extends StatelessWidget {
  final WebRTCConnectionState state;
  final double? size;

  const ConnectionStateBadge({
    super.key,
    required this.state,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfigForState(state);
    final badgeSize = size ?? 16.0;

    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        color: config.color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          config.icon,
          color: Colors.white,
          size: badgeSize * 0.5,
        ),
      ),
    );
  }

  _StateConfig _getConfigForState(WebRTCConnectionState state) {
    switch (state) {
      case WebRTCConnectionState.connected:
        return const _StateConfig(
          icon: Icons.check_circle,
          color: Colors.green,
          label: '已连接',
        );
      case WebRTCConnectionState.connecting:
      case WebRTCConnectionState.reconnecting:
        return const _StateConfig(
          icon: Icons.sync,
          color: Colors.blue,
          label: '连接中',
        );
      default:
        return const _StateConfig(
          icon: Icons.error,
          color: Colors.red,
          label: '未连接',
        );
    }
  }
}

/// 状态文字组件
class ConnectionStateText extends StatelessWidget {
  final WebRTCConnectionState state;
  final TextStyle? style;

  const ConnectionStateText({
    super.key,
    required this.state,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfigForState(state);

    return Text(
      config.label,
      style: (style ?? const TextStyle()).copyWith(
        color: config.color,
      ),
    );
  }

  _StateConfig _getConfigForState(WebRTCConnectionState state) {
    switch (state) {
      case WebRTCConnectionState.connected:
        return const _StateConfig(
          icon: Icons.check_circle,
          color: Colors.green,
          label: '已连接',
        );
      case WebRTCConnectionState.connecting:
      case WebRTCConnectionState.reconnecting:
        return const _StateConfig(
          icon: Icons.sync,
          color: Colors.blue,
          label: '连接中',
        );
      default:
        return const _StateConfig(
          icon: Icons.error,
          color: Colors.red,
          label: '未连接',
        );
    }
  }
}

/// 带动画的状态指示器
class AnimatedConnectionStatusIndicator extends StatefulWidget {
  final WebRTCConnectionState state;
  final String? errorMessage;

  const AnimatedConnectionStatusIndicator({
    super.key,
    required this.state,
    this.errorMessage,
  });

  @override
  State<AnimatedConnectionStatusIndicator> createState() =>
      _AnimatedConnectionStatusIndicatorState();
}

class _AnimatedConnectionStatusIndicatorState
    extends State<AnimatedConnectionStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // 如果状态需要动画，则启动动画
    if (_needsAnimation(widget.state)) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedConnectionStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      if (_needsAnimation(widget.state)) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _needsAnimation(WebRTCConnectionState state) {
    return state == WebRTCConnectionState.connecting ||
        state == WebRTCConnectionState.reconnecting;
  }

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: _animation.value,
      child: WebRTCConnectionStatusWidget(
        state: widget.state,
        errorMessage: widget.errorMessage,
      ),
    );
  }
}
