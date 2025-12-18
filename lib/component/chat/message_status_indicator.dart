import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:imboy/theme/theme_manager.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/service/websocket.dart';

/// 消息状态枚举
enum MessageStatusType {
  sending,   // 发送中
  sent,      // 已发送
  delivered, // 已送达
  seen,      // 已读
  failed,    // 发送失败
}

class MessageStatusIndicator extends StatefulWidget {
  final MessageStatusType status;
  final DateTime? timestamp;
  final VoidCallback? onRetry;
  final bool isSentByMe;
  final double size;

  const MessageStatusIndicator({
    super.key,
    required this.status,
    this.timestamp,
    this.onRetry,
    required this.isSentByMe,
    this.size = 16,
  });

  @override
  State<MessageStatusIndicator> createState() => _MessageStatusIndicatorState();
}

class _MessageStatusIndicatorState extends State<MessageStatusIndicator> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _shakeAnimation;
  bool _showTooltip = false;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -5.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: -5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    // 如果是失败状态，启动抖动动画
    if (widget.status == MessageStatusType.failed) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(MessageStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.status == MessageStatusType.failed && 
        oldWidget.status != MessageStatusType.failed) {
      _animationController.repeat(reverse: true);
      HapticFeedback.heavyImpact();
    } else if (widget.status != MessageStatusType.failed && 
               oldWidget.status == MessageStatusType.failed) {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 检查网络是否可用
  /// Check if network is available.
  bool _isNetworkAvailable() {
    try {
      // 这里可以接入真实的网络状态检测
      // 暂时使用WebSocket状态作为网络状态指示
      return Get.find<WebSocketService>().status.value == SocketStatus.connected;
    } catch (e) {
      return true; // 默认认为网络可用
    }
  }

  String _getStatusText() {
    switch (widget.status) {
      case MessageStatusType.sending:
        return '发送中';
      case MessageStatusType.sent:
        return '已发送';
      case MessageStatusType.delivered:
        return '已送达';
      case MessageStatusType.seen:
        return '已读';
      case MessageStatusType.failed:
        return '发送失败';
    }
  }

  String _getStatusDescription() {
    final timeText = widget.timestamp != null 
        ? DateTimeHelper.dateTimeFmt(widget.timestamp!)
        : '';
    
    switch (widget.status) {
      case MessageStatusType.sending:
        return '消息正在发送中...';
      case MessageStatusType.sent:
        return '消息已发送${timeText.isNotEmpty ? '于 $timeText' : ''}';
      case MessageStatusType.delivered:
        return '消息已送达${timeText.isNotEmpty ? '于 $timeText' : ''}';
      case MessageStatusType.seen:
        return '消息已读${timeText.isNotEmpty ? '于 $timeText' : ''}';
      case MessageStatusType.failed:
        return '消息发送失败，点击重试';
    }
  }

  Widget _buildStatusIcon() {
    final theme = ThemeManager.instance;
    final primaryColor = theme.getThemeColor('primary');
    final errorColor = theme.getThemeColor('error');
    final textSecondaryColor = theme.getThemeColor('textSecondary');

    final iconColor = switch (widget.status) {
      MessageStatusType.sending => textSecondaryColor,
      MessageStatusType.sent => textSecondaryColor,
      MessageStatusType.delivered => textSecondaryColor,
      MessageStatusType.seen => primaryColor,
      MessageStatusType.failed => errorColor,
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child: _buildIconContent(iconColor),
    );
  }

  Widget _buildIconContent(Color color) {
    switch (widget.status) {
      case MessageStatusType.sending:
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            // 显示网络状态指示器
            if (!_isNetworkAvailable())
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
              ),
          ],
        );
      case MessageStatusType.sent:
        return Icon(Icons.check, color: color, size: widget.size);
      case MessageStatusType.delivered:
      case MessageStatusType.seen:
        return Icon(Icons.done_all, color: color, size: widget.size);
      case MessageStatusType.failed:
        return AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onRetry?.call();
                },
                borderRadius: BorderRadius.circular(widget.size / 2),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.error_outline,
                    color: color,
                    size: widget.size,
                  ),
                ),
              ),
            );
          },
        );
    }
  }

  void _showStatusTooltip(BuildContext context) {
    final theme = ThemeManager.instance;
    final bgColor = theme.getThemeColor('surfaceContainerHigh');
    final textColor = theme.getThemeColor('onSurface');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getStatusText(),
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getStatusDescription(),
                style: TextStyle(color: textColor.withValues(alpha: 0.8)),
              ),
              if (widget.status == MessageStatusType.failed)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onRetry?.call();
                    },
                    child: const Text('重新发送'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showStatusTooltip(context),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showStatusTooltip(context);
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _showTooltip = true),
        onExit: (_) => setState(() => _showTooltip = false),
        child: Tooltip(
          message: _getStatusDescription(),
          preferBelow: false,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _showTooltip ? 0.8 : 1.0,
            child: _buildStatusIcon(),
          ),
        ),
      ),
    );
  }
}
