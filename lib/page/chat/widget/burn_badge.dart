/// 阅后即焚消息徽章组件
///
/// 显示消息剩余阅读时间，带弧形进度环动画
library;

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 阅后即焚徽章 — 带平滑进度弧动画
///
/// - 未开始阅读（burnReadAtMs <= 0）：显示"阅后"静态徽章
/// - 阅读中：进度弧从满 → 空，颜色绿→橙→红随剩余比例变化
class BurnBadge extends StatefulWidget {
  const BurnBadge({
    super.key,
    required this.isSentByMe,
    required this.burnAfterMs,
    required this.burnReadAtMs,
    required this.burnTicker,
  });

  final bool isSentByMe;
  final int burnAfterMs;
  final int burnReadAtMs;

  /// 外部每秒推送一次的 tick stream（用于更新文字倒计时）
  final Stream<int> burnTicker;

  @override
  State<BurnBadge> createState() => _BurnBadgeState();
}

class _BurnBadgeState extends State<BurnBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arc;
  StreamSubscription<int>? _tickSub;
  int _remainSec = 0;

  @override
  void initState() {
    super.initState();
    _arc = AnimationController(vsync: this);
    _initArc();
    _tickSub = widget.burnTicker.listen((_) => _onTick());
  }

  void _initArc() {
    if (widget.burnReadAtMs <= 0 || widget.burnAfterMs <= 0) return;
    final now = DateTimeHelper.millisecond();
    final expireAt = widget.burnReadAtMs + widget.burnAfterMs;
    final remainMs = (expireAt - now).clamp(0, widget.burnAfterMs);
    _remainSec = (remainMs / 1000).ceil();
    final fraction = remainMs / widget.burnAfterMs;
    _arc.value = fraction.clamp(0.0, 1.0);
    if (remainMs > 0) {
      _arc.animateTo(
        0.0,
        duration: Duration(milliseconds: remainMs),
        curve: Curves.linear,
      );
    }
  }

  void _onTick() {
    if (!mounted) return;
    if (widget.burnReadAtMs <= 0 || widget.burnAfterMs <= 0) return;
    final now = DateTimeHelper.millisecond();
    final expireAt = widget.burnReadAtMs + widget.burnAfterMs;
    final remainMs = expireAt - now;
    setState(() {
      _remainSec = remainMs <= 0 ? 0 : (remainMs / 1000).ceil();
    });
  }

  @override
  void dispose() {
    _tickSub?.cancel();
    _arc.dispose();
    super.dispose();
  }

  Color _arcColor(BuildContext context, double fraction) {
    if (fraction > 0.5) return AppColors.iosGreen;
    if (fraction > 0.25) return AppColors.iosOrange;
    return AppColors.getIosRed(Theme.of(context).brightness);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.burnReadAtMs <= 0 || widget.burnAfterMs <= 0) {
      final color = AppColors.getIosRed(Theme.of(context).brightness);
      return _buildBadge(
        context: context,
        color: color,
        fraction: null,
        text: t.chat.burnReadBadge,
      );
    }

    return AnimatedBuilder(
      animation: _arc,
      builder: (ctx, _) {
        final f = _arc.value;
        final text = _remainSec <= 0 ? '0s' : '${_remainSec}s';
        return _buildBadge(
          context: ctx,
          color: _arcColor(ctx, f),
          fraction: f,
          text: text,
        );
      },
    );
  }

  Widget _buildBadge({
    required BuildContext context,
    required Color color,
    required double? fraction,
    required String text,
  }) {
    final bg = Theme.of(context).colorScheme.surface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: fraction,
                  strokeWidth: 1.6,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                  strokeCap: StrokeCap.round,
                ),
                Icon(Icons.local_fire_department, size: 8, color: color),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: color,
              height: 1.0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
