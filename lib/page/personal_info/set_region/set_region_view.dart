import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/theme_manager.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'set_region_logic.dart';

class SetRegionPage extends StatefulWidget {
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
  State<SetRegionPage> createState() => _SetRegionPageState();
}

class _SetRegionPageState extends State<SetRegionPage> {
  late final SetRegionLogic logic = Get.put(SetRegionLogic());
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
    // 初始化数据（不在 build 中重复调用）
    logic.initData(widget.currentValue);
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

  /// 顶层搜索变更监听（500ms 防抖）
  /// 用途：搜索关键字变化后延迟执行过滤，避免频繁刷新列表
  /// 参数：无（读取 _searchC.text）
  /// 返回：void
  /// 异常：无
  void _onTopQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final kw = _searchC.text.trim();
      logic.applyTopSearch(kw);
      setState(() {
        _highlight = -1; // 搜索变化时重置高亮
      });
    });
  }

  /// 处理键盘事件（macOS 键鼠可达性）
  /// 用途：支持上下移动高亮、Enter 选择、Esc 返回、Tab 焦点切换
  /// 参数：event 键盘事件
  /// 返回：KeyEventResult
  /// 异常：无
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Tab 键焦点切换：搜索框 <-> 列表
    if (key == LogicalKeyboardKey.tab) {
      if (_searchF.hasFocus) {
        _listF.requestFocus();
      } else {
        _searchF.requestFocus();
      }
      return KeyEventResult.handled;
    }

    // 搜索框聚焦时，仅处理 Tab 和 Esc
    if (_searchF.hasFocus) {
      if (key == LogicalKeyboardKey.escape) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // 列表焦点时的导航键
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

  /// 高亮移动
  /// 用途：在列表中按步长移动高亮项，并滚动到可视区域
  /// 参数：delta 步长（+1或-1）
  /// 返回：void
  /// 异常：无
  void _moveHighlight(int delta) {
    final total = logic.regionList.length;
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
    // 近似滚动定位到对应项
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

  /// 回车选择当前高亮项
  /// 用途：键盘 Enter 时触发与点击同样的选择/下钻逻辑
  /// 参数：无
  /// 返回：void
  /// 异常：无
  void _onEnterSelect() {
    if (_highlight < 0 || _highlight >= logic.regionList.length) return;
    final region = logic.regionList[_highlight];
    String title = '';
    List children = [];
    if (region is String) {
      title = region;
    } else if (region is Map) {
      title = (region['title'] ?? '').toString();
      children = (region['children'] ?? []) as List;
    }
    logic.selectRegion(title, children, context, widget.onSave);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(
        Theme.of(context).brightness,
      ),
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: widget.title,
        rightDMActions: [
          Obx(
            () => Container(
              height: ThemeManager.instance.mainSpace * 4,
              margin: EdgeInsets.only(
                right: ThemeManager.instance.mainSpace * 2,
              ),
              decoration: BoxDecoration(
                color: logic.hasChanged.value
                    ? AppColors.primaryGreen
                    : (isDark
                          ? const Color(0xFF48484A)
                          : const Color(0xFFE5E5E5)),
                borderRadius: BorderRadius.circular(
                  ThemeManager.instance.mainSpace * 2,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    ThemeManager.instance.mainSpace * 2,
                  ),
                  onTap: logic.hasChanged.value
                      ? () async {
                          bool success = await widget.onSave(
                            logic.selectedRegion.value,
                          );
                          if (success) {
                            Get.back();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'operationFailedAgainLater'.tr,
                                ),
                              ),
                            );
                            logic.revertToInitial();
                          }
                        }
                      : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ThemeManager.instance.mainSpace * 2,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'buttonAccomplish'.tr,
                      style: ThemeManager.instance.getTextStyle(
                        FontSizeType.small,
                        fontWeight: FontWeight.w600,
                        color: logic.hasChanged.value
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
          ),
        ],
      ),
      body: Focus(
        focusNode: _listF,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Column(
          children: [
            // 当前选择显示区域
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(ThemeManager.instance.mainSpace * 2),
              margin: EdgeInsets.all(ThemeManager.instance.mainSpace * 2),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
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
                    'selectedRegion'.tr,
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.small,
                      color: AppColors.getTextColor(
                        Theme.of(context).brightness,
                        isSecondary: true,
                      ),
                    ),
                  ),
                  SizedBox(height: ThemeManager.instance.mainSpace * 0.8),
                  Obx(
                    () => Text(
                      logic.selectedRegion.value.isEmpty
                          ? 'pleaseSelect'.tr
                          : logic.selectedRegion.value,
                      style: ThemeManager.instance.getTextStyle(
                        FontSizeType.medium,
                        fontWeight: FontWeight.w500,
                        color: AppColors.getTextColor(
                          Theme.of(context).brightness,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 搜索框（顶层）
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Semantics(
                label: '${'searchRegion'.tr} - ${'regionSearchHint'.tr}',
                hint: 'regionSearchHint'.tr,
                textField: true,
                child: TextField(
                  controller: _searchC,
                  focusNode: _searchF,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ).copyWith(hintText: 'regionSearchHint'.tr),
                  onSubmitted: (_) => _onTopQueryChanged(),
                ),
              ),
            ),

            // 地区列表
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: ThemeManager.instance.mainSpace * 2,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
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
                child: Obx(
                  () => ListView.builder(
                    controller: _scrollC,
                    physics: const BouncingScrollPhysics(),
                    itemCount: logic.regionList.length,
                    itemBuilder: (context, index) {
                      final region = logic.regionList[index];
                      String title = '';
                      List children = [];
                      if (region is String) {
                        title = region;
                      } else if (region is Map) {
                        title = region['title'] ?? '';
                        children = region['children'] ?? [];
                      }
                      final hasChildren = children.isNotEmpty;
                      final isSelected = logic.isRegionSelected(title);
                      final isHighlight = index == _highlight;

                      return Semantics(
                        label: hasChildren
                            ? '$title - ${children.length} ${'region'.tr}'
                            : title,
                        hint: hasChildren
                            ? '${'buttonContinue'.tr}${'searchRegion'.tr}'
                            : isSelected
                            ? '${'selected'.tr}${'region'.tr}'
                            : '${'buttonConfirm'.tr}${'region'.tr}',
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
                            onTap: () => logic.selectRegion(
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
                                horizontal: ThemeManager.instance.mainSpace * 2,
                                vertical: ThemeManager.instance.mainSpace * 1.8,
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
                                // 选中时的背景颜色
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: isHighlight
                                    ? BorderRadius.circular(8.0)
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
                                      semanticLabel: 'buttonContinue'.tr,
                                    )
                                  else if (isSelected)
                                    Icon(
                                      Icons.check,
                                      color: AppColors.primaryGreen,
                                      size: 20,
                                      semanticLabel: 'selected'.tr,
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
            ),

            SizedBox(height: ThemeManager.instance.mainSpace * 2),
          ],
        ),
      ),
    );
  }
}
