import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

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
    super.dispose();
  }

  void _refreshOverlay() => _overlayEntry?.markNeedsBuild();

  void _toggleOverlay() {
    if (!widget.enabled || _clearing || _confirming) return;
    if (_overlayEntry != null) {
      _removeOverlay();
    } else if (widget.historyList.isNotEmpty) {
      FocusScope.of(context).unfocus();
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
    try {
      var dialogSubmitted = false;
      void closeConfirmation(BuildContext dialogContext, bool confirmed) {
        if (dialogSubmitted) return;
        dialogSubmitted = true;
        Navigator.of(dialogContext).pop(confirmed);
      }

      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: Text(t.account.loginHistoryClearTitle),
          content: Text(t.account.loginHistoryClearBody(account: account)),
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
        ),
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
          builder: (dialogContext) => CupertinoAlertDialog(
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
          ),
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
      builder: (overlayContext) {
        final size = renderBox.size;
        final media = MediaQuery.of(overlayContext);
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
          AppSizes.touchTarget,
          math.min(AppSizes.touchTarget * 6, showAbove ? above : below),
        );
        final selected = _selectedAccount;
        final brightness = Theme.of(overlayContext).brightness;
        final isDark = brightness == Brightness.dark;
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
                  color: isDark
                      ? AppColors.darkSurfaceContainer
                      : AppColors.lightSurface,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: AppSpacing.regular,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t.account.loginHistoryTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.textStyle(
                                    FontSizeType.medium,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Tooltip(
                                message: t.account.loginHistoryClear,
                                child: CupertinoButton(
                                  key: const Key('login_history_clear'),
                                  minimumSize: const Size.square(
                                    AppSizes.touchTarget,
                                  ),
                                  padding: const EdgeInsets.all(
                                    AppSpacing.medium,
                                  ),
                                  onPressed: selected == null
                                      ? null
                                      : () => _confirmClear(selected),
                                  child: Icon(
                                    CupertinoIcons.trash,
                                    semanticLabel: t.account.loginHistoryClear,
                                    size: AppSizes.iconSizeMedium,
                                    color: selected == null
                                        ? (isDark
                                              ? AppColors.darkTextDisabled
                                              : AppColors.lightTextDisabled)
                                        : AppColors.getIosRed(brightness),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.regular,
                            vertical: AppSpacing.small,
                          ),
                          child: Tooltip(
                            message: selected == null
                                ? t.account.loginHistoryChooseToClear
                                : t.account.loginHistorySelected(
                                    account: selected,
                                  ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Text(
                                selected == null
                                    ? t.account.loginHistoryChooseToClear
                                    : t.account.loginHistorySelected(
                                        account: selected,
                                      ),
                                key: const Key('login_history_selection'),
                                maxLines: 1,
                                style: context.textStyle(FontSizeType.small),
                              ),
                            ),
                          ),
                        ),
                        Flexible(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children: [
                              for (final item in widget.historyList)
                                Semantics(
                                  selected: item == selected,
                                  child: CupertinoButton(
                                    key: ValueKey('login_history_item_$item'),
                                    minimumSize: const Size(
                                      0,
                                      AppSizes.touchTarget,
                                    ),
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
                                            style: context.textStyle(
                                              FontSizeType.medium,
                                            ),
                                          ),
                                        ),
                                        if (item == selected) ...[
                                          AppSpacing.horizontalSmall,
                                          Icon(
                                            CupertinoIcons.check_mark,
                                            color: AppColors.getIosBlue(
                                              brightness,
                                            ),
                                            size: AppSizes.iconSizeSmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputFill = isDark
        ? AppColors.darkSurfaceContainer
        : AppColors.lightSurface;
    final borderDefault = isDark ? AppColors.darkBorder : AppColors.iosGray5;
    final showHistory = widget.historyList.isNotEmpty;
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        enableSuggestions: false,
        autocorrect: false,
        controller: widget.controller,
        focusNode: _focusNode,
        readOnly: !widget.enabled || _clearing,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        autofillHints: widget.autofillHints,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: Icon(widget.prefixIcon, color: AppColors.primary),
          suffixIcon: widget.suffixIcon == null && !showHistory && !_clearing
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.suffixIcon != null) widget.suffixIcon!,
                    if (_clearing)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.medium),
                        child: CupertinoActivityIndicator(),
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
    );
  }
}
