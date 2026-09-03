import 'package:flutter/material.dart';

import 'package:imboy/theme/default/app_radius.dart';

/// 为 [showCupertinoModalPopup] 中的自定义内容提供不透明主题表面。
class CupertinoModalSurface extends StatelessWidget {
  const CupertinoModalSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: AppRadius.bottomSheet,
      clipBehavior: Clip.antiAlias,
      child: SafeArea(top: false, child: child),
    );
  }
}
