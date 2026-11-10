import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

typedef _PopupAppearance = ({
  CapturedThemes themes,
  MediaQueryData media,
  TextDirection direction,
});

class LoginHistoryInput extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final List<String> historyList;
  final ValueChanged<String> onSelect;
  final Future<void> Function(String) onClear;
  final ValueChanged<bool>? onBusyChanged;
  final String Function(Object)? clearErrorMessage;
  final bool enabled;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final Iterable<String>? autofillHints;

  const LoginHistoryInput({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.historyList,
    required this.onSelect,
    required this.onClear,
    this.onBusyChanged,
    this.clearErrorMessage,
    this.enabled = true,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.autofillHints,
  });

  @override
  State<LoginHistoryInput> createState() => _LoginHistoryInputState();
}

class _LoginHistoryInputState extends State<LoginHistoryInput> {
  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  final _popupAppearance = ValueNotifier<_PopupAppearance?>(null);
  OverlayEntry? _overlayEntry;
  bool _confirming = false;
  bool _clearing = false;

  String? get _selectedAccount {
    final value = widget.controller.text;
    return widget.historyList.contains(value) ? value : null;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refreshOverlay);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Overlay entries and dialog routes are outside the field's local theme.
    // Recapture on changes so an already open popup never freezes that theme.
    final appearance = _captureAppearance();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _popupAppearance.value = appearance;
      }
    });
  }

  _PopupAppearance _captureAppearance() {
    Theme.of(context);
    CupertinoTheme.of(context);
    return (
      themes: InheritedTheme.capture(from: context, to: null),
      media: MediaQuery.of(context),
      direction: Directionality.of(context),
    );
  }

  Widget _withPopupAppearance(WidgetBuilder builder) =>
      ValueListenableBuilder<_PopupAppearance?>(
        valueListenable: _popupAppearance,
        builder: (popupContext, appearance, _) => appearance!.themes.wrap(
          Builder(
            builder: (themeContext) => CupertinoTheme(
              // A local Material Theme can inherit an older Cupertino theme.
              // Resolve native popup defaults from the captured Material theme.
              data: MaterialBasedCupertinoThemeData(
                materialTheme: Theme.of(themeContext),
              ),
              child: MediaQuery(
                // SafeArea and Scaffold may consume the anchor's screen insets.
                // Keep route geometry and only copy local text settings.
                data: MediaQuery.of(popupContext).copyWith(
                  textScaler: appearance.media.textScaler,
                  boldText: appearance.media.boldText,
                ),
                child: Directionality(
                  textDirection: appearance.direction,
                  child: Builder(builder: builder),
                ),
              ),
            ),
          ),
        ),
      );

  // Isolate only the displayed value; callbacks and the controller stay raw.
  String _displayAccount(String account) => '\u2068$account\u2069';

  @override
  void didUpdateWidget(covariant LoginHistoryInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refreshOverlay);
      widget.controller.addListener(_refreshOverlay);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.enabled || widget.historyList.isEmpty) {
        _removeOverlay();
      } else {
        _refreshOverlay();
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refreshOverlay);
    _focusNode.dispose();
    _removeOverlay();
    _popupAppearance.dispose();
    super.dispose();
  }

  void _refreshOverlay() => _overlayEntry?.markNeedsBuild();

  void _toggleOverlay() {
    if (!widget.enabled || _clearing || _confirming) return;
    if (_overlayEntry != null) {
      _removeOverlay();
    } else if (widget.historyList.isNotEmpty) {
      FocusScope.of(context).unfocus();
      _popupAppearance.value = _captureAppearance();
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  Future<void> _confirmClear(String account) async {
    if (_clearing || _confirming || !widget.enabled) return;
    _confirming = true;
    _removeOverlay();
    _popupAppearance.value = _captureAppearance();
    try {
      var dialogSubmitted = false;
      void closeConfirmation(BuildContext dialogContext, bool confirmed) {
        if (dialogSubmitted) return;
        dialogSubmitted = true;
        Navigator.of(dialogContext).pop(confirmed);
      }

      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (_) => _withPopupAppearance((dialogContext) {
          final t = Translations.of(dialogContext);
          return CupertinoAlertDialog(
            title: Text(t.account.loginHistoryClearTitle),
            content: Text(
              t.account.loginHistoryClearBody(
                account: _displayAccount(account),
              ),
            ),
            actions: [
              CupertinoDialogAction(
                key: const Key('login_history_clear_cancel'),
                isDefaultAction: true,
                onPressed: () => closeConfirmation(dialogContext, false),
                child: Text(t.common.buttonCancel),
              ),
              CupertinoDialogAction(
                key: const Key('login_history_clear_confirm'),
                isDestructiveAction: true,
                onPressed: () => closeConfirmation(dialogContext, true),
                child: Text(t.account.loginHistoryClearConfirm),
              ),
            ],
          );
        }),
      );
      if (confirmed != true || !mounted || !widget.enabled) return;
      // Capture the target before confirmation, never from changing input
      // while destructive asynchronous work is in flight.
      setState(() => _clearing = true);
      widget.onBusyChanged?.call(true);
      try {
        await widget.onClear(account);
        if (mounted && widget.controller.text == account) {
          widget.controller.clear();
        }
      } catch (error) {
        if (!mounted) return;
        var errorAcknowledged = false;
        await showCupertinoDialog<void>(
          context: context,
          builder: (_) => _withPopupAppearance((dialogContext) {
            final t = Translations.of(dialogContext);
            return CupertinoAlertDialog(
              title: Text(t.account.loginHistoryClearFailed),
              content: Text(
                widget.clearErrorMessage?.call(error) ??
                    t.common.operationFailedAgainLater,
              ),
              actions: [
                CupertinoDialogAction(
                  key: const Key('login_history_clear_error_close'),
                  onPressed: () {
                    if (errorAcknowledged) return;
                    errorAcknowledged = true;
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(t.common.buttonConfirm),
                ),
              ],
            );
          }),
        );
      } finally {
        if (mounted) {
          setState(() => _clearing = false);
          widget.onBusyChanged?.call(false);
        }
      }
    } finally {
      _confirming = false;
    }
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject()! as RenderBox;
    return OverlayEntry(
      builder: (_) => _withPopupAppearance((popupContext) {
        final size = renderBox.size;
        final media = MediaQuery.of(popupContext);
        final origin = renderBox.localToGlobal(Offset.zero);
        final below =
            media.size.height -
            media.viewInsets.bottom -
            media.padding.bottom -
            origin.dy -
            size.height -
            AppSpacing.small;
        final above = origin.dy - media.padding.top - AppSpacing.small;
        final showAbove = below < AppSizes.touchTarget * 3 && above > below;
        final maxHeight = math.max(
          0.0,
          math.min(AppSizes.touchTarget * 6, showAbove ? above : below),
        );
        final brightness = Theme.of(popupContext).brightness;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const Key('login_history_dismiss'),
                behavior: HitTestBehavior.opaque,
                onTap: _removeOverlay,
              ),
            ),
            Positioned(
              width: size.width,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                targetAnchor: showAbove
                    ? Alignment.topLeft
                    : Alignment.bottomLeft,
                followerAnchor: showAbove
                    ? Alignment.bottomLeft
                    : Alignment.topLeft,
                offset: Offset(
                  0,
                  showAbove ? -AppSpacing.tiny : AppSpacing.tiny,
                ),
                child: Material(
                  key: const Key('login_history_menu'),
                  elevation: 1,
                  borderRadius: AppRadius.borderRadiusCell,
                  clipBehavior: Clip.antiAlias,
                  color: brightness == Brightness.dark
                      ? AppColors.darkSurfaceContainer
                      : AppColors.lightSurface,
                  child: Builder(
                    builder: (menuContext) =>
                        _menuContent(menuContext, maxHeight),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  double _lineHeight(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  Widget _menuContent(BuildContext context, double maxHeight) {
    final t = Translations.of(context);
    final selected = _selectedAccount;
    final brightness = Theme.of(context).brightness;
    final textStyle = context.textStyle(
      FontSizeType.medium,
      color: AppColors.getTextColor(brightness),
    );
    final titleStyle = textStyle.copyWith(fontWeight: FontWeight.w600);
    final selectionStyle = context.textStyle(
      FontSizeType.small,
      color: AppColors.getTextSecondary(brightness),
    );
    final selectionText = selected == null
        ? t.account.loginHistoryChooseToClear
        : t.account.loginHistorySelected(account: _displayAccount(selected));
    final header = Padding(
      padding: const EdgeInsets.only(left: AppSpacing.regular),
      child: Row(
        // The requested clear control stays in the physical top-right corner.
        // Its text still inherits the locale's direction.
        textDirection: TextDirection.ltr,
        children: [
          Expanded(
            child: Tooltip(
              message: t.account.loginHistoryTitle,
              child: Text(
                t.account.loginHistoryTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
          ),
          Tooltip(
            message: t.account.loginHistoryClear,
            child: CupertinoButton(
              key: const Key('login_history_clear'),
              minimumSize: const Size.square(AppSizes.touchTarget),
              padding: const EdgeInsets.all(AppSpacing.small),
              onPressed: selected == null
                  ? null
                  : () => _confirmClear(selected),
              child: Icon(
                CupertinoIcons.trash,
                semanticLabel: t.account.loginHistoryClear,
                size: AppSizes.iconSizeMedium,
                color: selected == null
                    ? (brightness == Brightness.dark
                          ? AppColors.darkTextDisabled
                          : AppColors.lightTextDisabled)
                    : AppColors.getIosRed(brightness),
              ),
            ),
          ),
        ],
      ),
    );
    final selection = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      child: Tooltip(
        message: selectionText,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(
            selectionText,
            key: const Key('login_history_selection'),
            maxLines: 1,
            style: selectionStyle,
          ),
        ),
      ),
    );
    final items = [
      for (final item in widget.historyList)
        Semantics(
          selected: item == selected,
          child: Tooltip(
            message: item,
            child: CupertinoButton(
              key: ValueKey('login_history_item_$item'),
              minimumSize: const Size(0, AppSizes.touchTarget),
              padding: AppSpacing.listItemPadding,
              alignment: AlignmentDirectional.centerStart,
              onPressed: () {
                _removeOverlay();
                widget.controller.text = item;
                widget.onSelect(item);
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item,
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle,
                    ),
                  ),
                  if (item == selected) ...[
                    AppSpacing.horizontalSmall,
                    Icon(
                      CupertinoIcons.check_mark,
                      color: AppColors.getIosBlue(brightness),
                      size: AppSizes.iconSizeSmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
    ];
    final fixedHeight =
        math.max(
          AppSizes.touchTarget,
          _lineHeight(context, t.account.loginHistoryTitle, titleStyle),
        ) +
        _lineHeight(context, selectionText, selectionStyle) +
        AppSpacing.regular;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      // Keep the selected account fixed whenever there is room for a row.
      // Short viewports scroll the entire panel instead of overflowing it.
      child: maxHeight < fixedHeight + AppSizes.touchTarget
          ? SingleChildScrollView(
              key: const Key('login_history_scroll'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [header, selection, ...items],
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                selection,
                Flexible(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: items,
                  ),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final direction = Directionality.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final interactive = widget.enabled && !_clearing;
    final inputFill = isDark
        ? AppColors.darkSurfaceContainer
        : AppColors.lightSurface;
    final borderDefault = isDark ? AppColors.darkBorder : AppColors.iosGray5;
    final showHistory = widget.historyList.isNotEmpty;
    return CompositedTransformTarget(
      link: _layerLink,
      // Account identifiers and the suffix controls retain their physical order
      // while the hint and every surrounding label follow the active locale.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: TextField(
          enableSuggestions: false,
          autocorrect: false,
          enabled: interactive,
          textDirection: TextDirection.ltr,
          controller: widget.controller,
          focusNode: _focusNode,
          readOnly: !interactive,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          autofillHints: widget.autofillHints,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintTextDirection: direction,
            prefixIcon: Icon(
              widget.prefixIcon,
              color: interactive
                  ? AppColors.primary
                  : (isDark
                        ? AppColors.darkTextDisabled
                        : AppColors.lightTextDisabled),
            ),
            suffixIcon: widget.suffixIcon == null && !showHistory && !_clearing
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.suffixIcon != null) widget.suffixIcon!,
                      if (_clearing)
                        Semantics(
                          label: t.common.processingDots,
                          liveRegion: true,
                          child: const SizedBox.square(
                            dimension: AppSizes.touchTarget,
                            child: Center(child: CupertinoActivityIndicator()),
                          ),
                        )
                      else if (showHistory)
                        IconButton(
                          key: const Key('login_history_toggle'),
                          icon: Icon(
                            CupertinoIcons.chevron_down,
                            semanticLabel: t.passport.loginHistoryToggle,
                          ),
                          tooltip: t.passport.loginHistoryToggle,
                          onPressed: widget.enabled ? _toggleOverlay : null,
                        ),
                    ],
                  ),
            filled: true,
            fillColor: inputFill,
            contentPadding: const EdgeInsets.symmetric(
              vertical: AppSpacing.medium,
              horizontal: AppSpacing.regular,
            ),
            border: OutlineInputBorder(
              borderRadius: AppRadius.borderRadiusCell,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.borderRadiusCell,
              borderSide: BorderSide(color: borderDefault),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.borderRadiusCell,
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}
