import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// Keeps swipe navigation while letting translated forms determine their height.
class LoginFormTabs extends StatefulWidget {
  const LoginFormTabs({
    super.key,
    required this.controller,
    required this.labels,
    required this.children,
  }) : assert(labels.length == children.length);

  final TabController controller;
  final List<String> labels;
  final List<Widget> children;

  @override
  State<LoginFormTabs> createState() => _LoginFormTabsState();
}

class _LoginFormTabsState extends State<LoginFormTabs> {
  final Map<int, double> _heights = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_tabChanged);
  }

  @override
  void didUpdateWidget(LoginFormTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_tabChanged);
      widget.controller.addListener(_tabChanged);
      _heights.clear();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_tabChanged);
    super.dispose();
  }

  void _tabChanged() => setState(() {});

  void _heightChanged(int index, double height) {
    if (mounted && _heights[index] != height) {
      setState(() => _heights[index] = height);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = context.textStyle(
      FontSizeType.normal,
      fontWeight: FontWeight.w600,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            var widest = 0.0;
            var tallest = 0.0;
            for (final label in widget.labels) {
              final painter = TextPainter(
                text: TextSpan(text: label, style: labelStyle),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              widest = math.max(widest, painter.width);
              tallest = math.max(tallest, painter.height);
              painter.dispose();
            }
            final scrollable =
                (widest + AppSpacing.xxLarge) * widget.labels.length >
                constraints.maxWidth - AppSpacing.small;
            return Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceGrouped
                    : AppColors.lightSurfaceGrouped,
                borderRadius: AppRadius.borderRadiusCell,
              ),
              padding: AppSpacing.allTiny,
              child: TabBar(
                controller: widget.controller,
                isScrollable: scrollable,
                tabAlignment: scrollable
                    ? TabAlignment.start
                    : TabAlignment.fill,
                labelStyle: labelStyle,
                unselectedLabelStyle: labelStyle,
                labelPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.regular,
                ),
                labelColor: AppColors.primary,
                unselectedLabelColor: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceGroupedTertiary
                      : AppColors.lightSurface,
                  borderRadius: AppRadius.borderRadiusSmall,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.darkBackground.withValues(alpha: 0.05),
                      blurRadius: AppSpacing.tiny,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                tabs: [
                  for (final label in widget.labels)
                    Tab(
                      height: math.max(
                        AppSizes.touchTarget,
                        tallest + AppSpacing.regular,
                      ),
                      child: Text(label, maxLines: 1),
                    ),
                ],
              ),
            );
          },
        ),
        AppSpacing.verticalRegular,
        SizedBox(
          height: _heights[widget.controller.index] ?? 220,
          child: TabBarView(
            controller: widget.controller,
            children: [
              for (var i = 0; i < widget.children.length; i++)
                OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: _FormHeight(
                    onChanged: (height) => _heightChanged(i, height),
                    child: widget.children[i],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormHeight extends SingleChildRenderObjectWidget {
  const _FormHeight({required this.onChanged, required super.child});

  final ValueChanged<double> onChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFormHeight(onChanged);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFormHeight renderObject,
  ) {
    renderObject.onChanged = onChanged;
  }
}

class _RenderFormHeight extends RenderProxyBox {
  _RenderFormHeight(this.onChanged);

  ValueChanged<double> onChanged;
  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    if (_lastSize == size) return;
    final measured = _lastSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached && _lastSize == measured) onChanged(measured.height);
    });
  }
}
