import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show Message;
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 多选标题栏：退出和清空分别保留原有行为。
class MessageMultiSelectHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const MessageMultiSelectHeader({
    super.key,
    required this.count,
    required this.onCancel,
    this.onClearSelection,
    this.stacked = false,
    this.toolbarHeight = kToolbarHeight + 16,
    this.cancelWidth = 60,
    this.titleStyle,
  });

  factory MessageMultiSelectHeader.adaptive(
    BuildContext context, {
    required int count,
    required VoidCallback onCancel,
    required double containerWidth,
    VoidCallback? onClearSelection,
  }) {
    final scale = MediaQuery.textScalerOf(context);
    TextStyle effectiveStyle(TextStyle style) => style.merge(
      TextStyle(
        fontWeight: MediaQuery.boldTextOf(context) ? FontWeight.bold : null,
        height: MediaQuery.maybeLineHeightScaleFactorOverrideOf(context),
        letterSpacing: MediaQuery.maybeLetterSpacingOverrideOf(context),
        wordSpacing: MediaQuery.maybeWordSpacingOverrideOf(context),
      ),
    );
    // CupertinoButton installs actionTextStyle as its DefaultTextStyle.
    final actionStyle = effectiveStyle(
      CupertinoTheme.of(context).textTheme.actionTextStyle,
    );
    // Supply this exact resolved style to Text so measurement does not depend
    // on a different DefaultTextStyle below the Scaffold's Material.
    final titleStyle = effectiveStyle(
      (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).merge(
        context.textStyle(FontSizeType.body, fontWeight: FontWeight.w600),
      ),
    ).copyWith(inherit: false);
    double width(String text, TextStyle style) => TextPainter.computeWidth(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: scale,
      locale: Localizations.maybeLocaleOf(context),
    );
    final cancelWidth =
        width(context.t.chat.multiSelectCancel, actionStyle) +
        AppSpacing.medium * 2;
    final clearWidth = onClearSelection == null
        ? 0.0
        : width(context.t.chat.multiSelectDeselectAll, actionStyle) +
              AppSpacing.medium * 2;
    final titleWidth = width(
      context.t.chat.multiSelectCount(count: count),
      titleStyle,
    );
    final availableWidth = containerWidth - AppSpacing.regular * 2;
    double height(String text, TextStyle style, double maxWidth) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scale,
        locale: Localizations.maybeLocaleOf(context),
      )..layout(maxWidth: maxWidth.clamp(1, double.infinity));
      final result = painter.height;
      painter.dispose();
      return result;
    }

    final actionMaxWidth = onClearSelection == null
        ? availableWidth
        : availableWidth / 2;
    final actionHeight = [
      height(context.t.chat.multiSelectCancel, actionStyle, actionMaxWidth),
      if (onClearSelection != null)
        height(
          context.t.chat.multiSelectDeselectAll,
          actionStyle,
          actionMaxWidth,
        ),
      44.0,
    ].reduce((a, b) => a > b ? a : b);
    final titleHeight = height(
      context.t.chat.multiSelectCount(count: count),
      titleStyle,
      availableWidth,
    );
    final stacked =
        cancelWidth + clearWidth + titleWidth + AppSpacing.regular * 4 >
            containerWidth ||
        titleHeight > kToolbarHeight ||
        actionHeight > kToolbarHeight;
    return MessageMultiSelectHeader(
      count: count,
      onCancel: onCancel,
      onClearSelection: onClearSelection,
      stacked: stacked,
      titleStyle: titleStyle,
      cancelWidth: cancelWidth < 44 ? 44 : cancelWidth,
      toolbarHeight: stacked
          ? titleHeight + actionHeight + AppSpacing.regular * 2
          : kToolbarHeight + 16,
    );
  }

  final int count;
  final VoidCallback onCancel;
  final VoidCallback? onClearSelection;
  final bool stacked;
  final double toolbarHeight;
  final double cancelWidth;
  final TextStyle? titleStyle;

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final cancel = CupertinoButton(
      key: const ValueKey('multi_select_cancel'),
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: onCancel,
      child: Text(t.chat.multiSelectCancel),
    );
    final clear = onClearSelection == null
        ? null
        : CupertinoButton(
            key: const ValueKey('multi_select_clear'),
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
            onPressed: count > 0 ? onClearSelection : null,
            child: Text(t.chat.multiSelectDeselectAll),
          );
    final title = Text(
      t.chat.multiSelectCount(count: count),
      key: const ValueKey('multi_select_count'),
      textAlign: TextAlign.center,
      style:
          titleStyle ??
          context.textStyle(FontSizeType.body, fontWeight: FontWeight.w600),
    );
    if (stacked) {
      return Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(header: true, child: title),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: cancel),
                    if (clear != null) Expanded(child: clear),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return GlassAppBar(
      toolbarHeight: toolbarHeight,
      leadingWidth: cancelWidth,
      leading: cancel,
      titleWidget: title,
      rightDMActions: clear == null ? null : [clear],
    );
  }
}

/// 底部统一转发入口与已有导出入口。
class MessageMultiSelectActionBar extends StatelessWidget {
  const MessageMultiSelectActionBar({
    super.key,
    required this.selectedMessages,
    this.onForwardEach,
    this.onForwardBundle,
    this.onExport,
  });

  final List<Message> selectedMessages;
  final void Function(List<Message>)? onForwardEach;
  final void Function(List<Message>)? onForwardBundle;
  final void Function(List<Message>)? onExport;

  void _showForwardOptions(BuildContext context) {
    final t = context.t;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          _forwardOption(
            sheetContext,
            key: const ValueKey('multi_select_forward_each'),
            label: t.chat.multiSelectForwardEach,
            callback: onForwardEach,
          ),
          _forwardOption(
            sheetContext,
            key: const ValueKey('multi_select_forward_bundle'),
            label: t.chat.multiSelectForwardBundle,
            callback: onForwardBundle,
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          key: const ValueKey('multi_select_forward_cancel'),
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(t.common.buttonCancel),
        ),
      ),
    );
  }

  Widget _forwardOption(
    BuildContext context, {
    required Key key,
    required String label,
    required void Function(List<Message>)? callback,
  }) {
    if (callback == null) {
      return CupertinoButton(
        key: key,
        minimumSize: const Size(44, 44),
        onPressed: null,
        child: Text(label),
      );
    }
    return CupertinoActionSheetAction(
      key: key,
      onPressed: () {
        Navigator.pop(context);
        callback(selectedMessages);
      },
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = Theme.of(context).colorScheme;
    final hasSelection = selectedMessages.isNotEmpty;
    final canForward =
        hasSelection && (onForwardEach != null || onForwardBundle != null);
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          padding: AppSpacing.allSmall,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _action(
                  context,
                  key: const ValueKey('multi_select_forward'),
                  icon: CupertinoIcons.arrowshape_turn_up_right,
                  label: t.chat.forward,
                  onPressed: canForward
                      ? () => _showForwardOptions(context)
                      : null,
                ),
              ),
              Expanded(
                child: _action(
                  context,
                  key: const ValueKey('multi_select_export'),
                  icon: CupertinoIcons.share,
                  label: t.chat.multiSelectExport,
                  onPressed: hasSelection && onExport != null
                      ? () => onExport!(selectedMessages)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return CupertinoButton(
      key: key,
      minimumSize: const Size(44, 44),
      padding: AppSpacing.allSmall,
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconSizeSmall),
          AppSpacing.verticalTiny,
          Text(label, style: context.textStyle(FontSizeType.caption2)),
        ],
      ),
    );
  }
}
