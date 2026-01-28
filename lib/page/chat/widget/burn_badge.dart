/// 阅后即焚消息徽章组件
///
/// 显示消息剩余阅读时间，带有倒计时功能
library;

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 阅后即焚徽章组件
class BurnBadge extends StatelessWidget {
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
  final Stream<int> burnTicker;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    final bg = Theme.of(context).colorScheme.surface;

    if (burnReadAtMs <= 0 || burnAfterMs <= 0) {
      return _buildBadge(
        color: color,
        bg: bg,
        text: '阅后',
        icon: Icons.local_fire_department,
      );
    }

    return StreamBuilder<int>(
      stream: burnTicker,
      builder: (context, snapshot) {
        final now = DateTimeHelper.millisecond();
        final expireAt = burnReadAtMs + burnAfterMs;
        final remainMs = expireAt - now;
        final remainSec = (remainMs / 1000).ceil();
        final text = remainSec <= 0 ? '0s' : '${remainSec}s';
        return _buildBadge(
          color: color,
          bg: bg,
          text: text,
          icon: Icons.local_fire_department,
        );
      },
    );
  }

  /// 构建徽章 UI
  Widget _buildBadge({
    required Color color,
    required Color bg,
    required String text,
    required IconData icon,
  }) {
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
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(text, style: TextStyle(fontSize: 10, color: color, height: 1.0)),
        ],
      ),
    );
  }
}
