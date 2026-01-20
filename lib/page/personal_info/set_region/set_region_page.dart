import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'set_region_provider.dart';

class SetRegionPage extends ConsumerStatefulWidget {
  final String title;
  final String currentValue;
  final Future<bool> Function(String) onSave;

  const SetRegionPage({
    super.key,
    required this.title,
    required this.currentValue,
    required this.onSave,
  });

  @override
  ConsumerState<SetRegionPage> createState() => _SetRegionPageState();
}

class _SetRegionPageState extends ConsumerState<SetRegionPage> {
  final TextEditingController _searchC = TextEditingController();
  final FocusNode _searchF = FocusNode();
  final FocusNode _listF = FocusNode();
  final ScrollController _scrollC = ScrollController();
  Timer? _debounce;
  int _highlight = -1;

  static const double _kItemExtent = 56.0;

  @override
  void initState() {
    super.initState();
    ref.read(setRegionProvider.notifier).initData(widget.currentValue);
    _searchC.addListener(_onTopQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.removeListener(_onTopQueryChanged);
    _searchC.dispose();
    _searchF.dispose();
    _listF.dispose();
    _scrollC.dispose();
    super.dispose();
  }

  void _onTopQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final kw = _searchC.text.trim();
      ref.read(setRegionProvider.notifier).applyTopSearch(kw);
      setState(() {
        _highlight = -1;
      });
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.tab) {
      if (_searchF.hasFocus) {
        _listF.requestFocus();
      } else {
        _searchF.requestFocus();
      }
      return KeyEventResult.handled;
    }

    if (_searchF.hasFocus) {
      if (key == LogicalKeyboardKey.escape) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _onEnterSelect();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveHighlight(int delta) {
    final state = ref.read(setRegionProvider);
    final total = state.regionList.length;
    if (total == 0) return;
    int next = _highlight;
    if (next < 0) {
      next = delta > 0 ? 0 : total - 1;
    } else {
      next = (next + delta).clamp(0, total - 1);
    }
    setState(() {
      _highlight = next;
    });
    final target = (_kItemExtent * next).clamp(
      0.0,
      _scrollC.position.maxScrollExtent,
    );
    _scrollC.animateTo(
      target,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  void _onEnterSelect() {
    final state = ref.read(setRegionProvider);
    if (_highlight < 0 || _highlight >= state.regionList.length) return;
    final region = state.regionList[_highlight];
    String title = '';
    List children = [];
    if (region is String) {
      title = region;
    } else if (region is Map) {
      title = (region['title'] ?? '').toString();
      children = (region['children'] ?? []) as List;
    }
    ref
        .read(setRegionProvider.notifier)
        .selectRegion(title, children, context, widget.onSave);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(setRegionProvider);

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(
        Theme.of(context).brightness,
      ),
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: widget.title,
        rightDMActions: [
          Container(
            height: AppSpacing.regular * 4,
            margin: EdgeInsets.only(right: AppSpacing.regular * 2),
            decoration: BoxDecoration(
              color: state.hasChanged
                  ? AppColors.primary
                  : (isDark
                        ? const Color(0xFF48484A)
                        : const Color(0xFFE5E5E5)),
              borderRadius: BorderRadius.circular(
                AppSpacing.regular * 2,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(
                  AppSpacing.regular * 2,
                ),
                onTap: state.hasChanged
                    ? () async {
                        final success = await widget.onSave(
                          state.selectedRegion,
                        );
                        if (!context.mounted) return;
                        if (success) {
                          Navigator.of(context).pop();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t.operationFailedAgainLater),
                            ),
                          );
                          ref
                              .read(setRegionProvider.notifier)
                              .revertToInitial();
                        }
                      }
                    : null,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.regular * 2,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    t.buttonAccomplish,
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.small,
                      fontWeight: FontWeight.w600,
                      color: state.hasChanged
                          ? Colors.white
                          : AppColors.getTextColor(
                              Theme.of(context).brightness,
                              isSecondary: true,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Focus(
        focusNode: _listF,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.regular * 2),
              margin: EdgeInsets.all(AppSpacing.regular * 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                borderRadius: AppRadius.borderRadiusMedium,
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: 0.5,
                    offset: const Offset(0, 0.5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.selectedRegion,
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.small,
                      color: AppColors.getTextColor(
                        Theme.of(context).brightness,
                        isSecondary: true,
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.regular * 0.8),
                  Text(
                    state.selectedRegion.isEmpty
                        ? t.pleaseSelect
                        : state.selectedRegion,
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.medium,
                      fontWeight: FontWeight.w500,
                      color: AppColors.getTextColor(
                        Theme.of(context).brightness,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Semantics(
                label: '${t.searchRegion} - ${t.regionSearchHint}',
                hint: t.regionSearchHint,
                textField: true,
                child: TextField(
                  controller: _searchC,
                  focusNode: _searchF,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ).copyWith(hintText: t.regionSearchHint),
                  onSubmitted: (_) => _onTopQueryChanged(),
                ),
              ),
            ),

            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: AppSpacing.regular * 2,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Colors.white,
                  borderRadius: AppRadius.borderRadiusMedium,
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.builder(
                  controller: _scrollC,
                  physics: const BouncingScrollPhysics(),
                  itemCount: state.regionList.length,
                  itemBuilder: (context, index) {
                    final region = state.regionList[index];
                    String title = '';
                    List children = [];
                    if (region is String) {
                      title = region;
                    } else if (region is Map) {
                      title = region['title'] ?? '';
                      children = region['children'] ?? [];
                    }
                    final hasChildren = children.isNotEmpty;
                    final isSelected = ref
                        .read(setRegionProvider.notifier)
                        .isRegionSelected(title);
                    final isHighlight = index == _highlight;

                    return Semantics(
                      label: hasChildren
                          ? '$title - ${children.length} ${t.region}'
                          : title,
                      hint: hasChildren
                          ? '${t.buttonContinue}${t.searchRegion}'
                          : isSelected
                          ? '${t.selected}${t.region}'
                          : '${t.buttonConfirm}${t.region}',
                      button: true,
                      selected: isSelected,
                      focusable: true,
                      child: Material(
                        color: isHighlight
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => ref
                              .read(setRegionProvider.notifier)
                              .selectRegion(
                                title,
                                children,
                                context,
                                widget.onSave,
                              ),
                          focusColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.08),
                          hoverColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.04),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.regular * 2,
                              vertical: AppSpacing.regular * 1.8,
                            ),
                            decoration: BoxDecoration(
                              border: isHighlight
                                  ? Border.all(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      width: 2.0,
                                    )
                                  : Border(
                                      bottom: BorderSide(
                                        color: AppColors.getDividerColor(
                                          Theme.of(context).brightness,
                                        ),
                                        width: 0.5,
                                      ),
                                    ),
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: isHighlight
                                  ? AppRadius.borderRadiusSmall
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: ThemeManager.instance.getTextStyle(
                                      isSelected
                                          ? FontSizeType.large
                                          : FontSizeType.medium,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: AppColors.getTextColor(
                                        Theme.of(context).brightness,
                                      ),
                                    ),
                                  ),
                                ),
                                if (hasChildren)
                                  Icon(
                                    Icons.navigate_next,
                                    color: AppColors.getTextColor(
                                      Theme.of(context).brightness,
                                      isSecondary: true,
                                    ),
                                    size: 20,
                                    semanticLabel: t.buttonContinue,
                                  )
                                else if (isSelected)
                                  Icon(
                                    Icons.check,
                                    color: AppColors.primary,
                                    size: 20,
                                    semanticLabel: t.selected,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            SizedBox(height: AppSpacing.regular * 2),
          ],
        ),
      ),
    );
  }
}
