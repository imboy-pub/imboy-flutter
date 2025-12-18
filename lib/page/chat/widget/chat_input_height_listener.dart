import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 用于监听 child（比如 ChatInput）高度变化，并自动同步到 obs 变量
/// 优化版本：添加更流畅的动画效果，让消息列表向上移动更加丝滑
class ChatInputHeightListener extends StatefulWidget {
  final Widget child;
  final RxDouble composerHeight;
  /// 高度变化动画时长（优化为更快的响应速度）
  final Duration animationDuration;
  /// 动画曲线（使用更自然的曲线）
  final Curve animationCurve;

  const ChatInputHeightListener({
    super.key,
    required this.child,
    required this.composerHeight,
    this.animationDuration = const Duration(milliseconds: 200), // 减少动画时长
    this.animationCurve = Curves.fastOutSlowIn, // 使用更自然的动画曲线
  });

  @override
  State<ChatInputHeightListener> createState() => _ChatInputHeightListenerState();
}

class _ChatInputHeightListenerState extends State<ChatInputHeightListener>
    with SingleTickerProviderStateMixin {
  final _key = GlobalKey();
  double _lastHeight = 52.0; // 默认高度，和 ChatInput 的默认高度一致
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;

  @override
  void initState() {
    super.initState();
    // 初始化动画控制器
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _heightAnimation = Tween<double>(
      begin: _lastHeight,
      end: _lastHeight,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: widget.animationCurve,
    ));
    
    // 监听动画值变化，同步到 composerHeight
    _heightAnimation.addListener(_updateHeight);
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyHeight());
  }

  @override
  void didUpdateWidget(covariant ChatInputHeightListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyHeight());
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  /// 通知高度变化，使用动画平滑过渡（优化版本：移除防抖，实时响应）
  Timer? _debounceTimer;
  
  void _notifyHeight() {
    _debounceTimer?.cancel();
    
    final ctx = _key.currentContext;
    if (ctx != null) {
      final height = ctx.size?.height ?? 0;
      if (height != _lastHeight && height > 0) {
        if (widget.animationDuration == Duration.zero) {
          _lastHeight = height;
          widget.composerHeight.value = height;
        } else {
          // 停止当前动画
          _animationController.stop();
          
          // 更新动画的起始和结束值
          _heightAnimation = Tween<double>(
            begin: _lastHeight,
            end: height,
          ).animate(CurvedAnimation(
            parent: _animationController,
            curve: widget.animationCurve,
          ));
          
          // 移除旧的监听器，添加新的监听器
          _heightAnimation.removeListener(_updateHeight);
          _heightAnimation.addListener(_updateHeight);
          
          _lastHeight = height;
          
          // 启动动画
          _animationController.reset();
          _animationController.forward();
        }
      }
    }
  }
  
  /// 更新高度的回调方法
  void _updateHeight() {
    widget.composerHeight.value = _heightAnimation.value;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _notifyHeight());
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: Container(
          key: _key,
          child: widget.child,
        ),
      ),
    );
  }
}