import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:geo_regions/geo_regions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// geo_regions 选择器（pinned 包）基于官方 flutter/material 构建，而本 app
// UI 层使用 material_ui fork——两者的 Material / MaterialLocalizations 是
// 不同运行时类型。以下 alias 导入仅供嵌入点为选择器提供真实 Material
// 祖先与本地化代理，不用于页面自身 UI（页面 UI 仍走 cupertino/material_ui）。
// 官方库的弃用提示指向 fork 替换，但 fork 类型与 pinned geo_regions
// 选择器互不兼容，此处必须用官方类型，定向豁免。
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as picker_material;
// ignore: deprecated_member_use
import 'package:flutter_localizations/flutter_localizations.dart'
    as picker_l10n;

import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/service/user_profile_service.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'set_region_provider.dart';

/// 设置地区页面 - 像素级对齐 iOS 17 Premium 风格
class SetRegionPage extends ConsumerStatefulWidget {
  final String title;
  final String currentValue;
  final Future<bool> Function(String) onSave;

  /// geo_regions 选择器数据源（pinned 数据集经 [GeoRegionDataSource]
  /// 注入）。提供后页面进入结构化模式：以数据集真实 pathIds 构造
  /// GeoSelection，保存走结构化身份协议（regionSelection），legacy
  /// `region` 字符串链路保持不变。
  final GeoRegionDataSource? geoDataSource;

  /// 结构化保存入口；缺省为 [UserProfileService.updateRegionSelection]。
  /// 仅测试注入使用，生产走默认实现。
  final Future<bool> Function(GeoSelection selection)? onSaveSelection;

  const SetRegionPage({
    super.key,
    required this.title,
    required this.currentValue,
    required this.onSave,
    this.geoDataSource,
    this.onSaveSelection,
  });

  @override
  ConsumerState<SetRegionPage> createState() => _SetRegionPageState();
}

class _SetRegionPageState extends ConsumerState<SetRegionPage> {
  final TextEditingController _searchC = TextEditingController();
  Timer? _debounce;
  bool _isSaving = false;

  Future<void> _saveAndExit(String value) =>
      _runSave(() => widget.onSave(value));

  /// 结构化保存链：只提交已确认的结构化草稿（pathIds 来自数据集），
  /// 无草稿不发起保存。默认接 UserProfileService.updateRegionSelection
  /// （结构化身份协议），注入入口仅供测试。
  Future<void> _saveSelectionAndExit() {
    final selection = ref.read(setRegionProvider).geoSelection;
    if (selection == null) return Future<void>.value();
    return _runSave(() async {
      final save =
          widget.onSaveSelection ?? UserProfileService.updateRegionSelection;
      return save(selection);
    });
  }

  /// 保存-提交-导航统一链：服务端保存成功后才提交地区缓存并从任意
  /// 递归层级退出；失败保留草稿、留在当前页面、不写缓存。
  Future<void> _runSave(Future<bool> Function() step) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final saved = await step();
      if (!saved || !mounted) return;

      // 只有服务端保存成功后才提交地区缓存，失败时保留旧缓存。
      try {
        await ref.read(setRegionProvider.notifier).persistSelection();
      } catch (error) {
        // 服务端已成功，缓存异常不能把已保存的数据伪装成保存失败。
        debugPrint('保存地区缓存失败: $error');
      }
      if (!mounted) return;

      // 从任意递归层级统一退出整个地区编辑流程，回到调用方（MorePage）。
      final navigator = Navigator.of(context);
      final rootRoute = ModalRoute.of(context);
      if (rootRoute == null) return;
      navigator.popUntil((route) => identical(route, rootRoute));
      if (rootRoute.isActive) navigator.pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(setRegionProvider.notifier).initData(widget.currentValue);
      }
    });
    _searchC.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(setRegionProvider.notifier).applyTopSearch(_searchC.text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(setRegionProvider);
    final brightness = Theme.of(context).brightness;
    final selectedPath = state.regionPath;
    final geoMode = widget.geoDataSource != null;

    return IosPageTemplate(
      title: widget.title,
      useLargeTitle: false,
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: state.hasChanged && !_isSaving
              ? (geoMode
                    ? _saveSelectionAndExit
                    : () => _saveAndExit(state.selectedRegion))
              : null,
          child: Text(
            t.common.buttonAccomplish,
            style: TextStyle(
              fontWeight: state.hasChanged ? FontWeight.w600 : FontWeight.w400,
              color: state.hasChanged
                  ? AppColors.getIosBlue(brightness)
                  : AppColors.iosGray,
            ),
          ),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: _SelectionLevelHint(
            region: state.selectedRegion,
            level: selectedPath.length,
          ),
        ),

        // 当前选择回显 Section - 增强视觉提示
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            header: Text(t.common.selectedRegion.toUpperCase()),
            children: [
              ImBoySettingsTile(
                title: Text(
                  state.selectedRegion.isEmpty
                      ? t.main.pleaseSelect
                      : state.selectedRegion,
                  style: TextStyle(
                    color: state.selectedRegion.isEmpty
                        ? AppColors.iosGray
                        : AppColors.primary,
                    fontWeight: state.selectedRegion.isEmpty
                        ? FontWeight.normal
                        : FontWeight.w600,
                  ),
                ),
                trailing: state.hasChanged
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Icon(
                          CupertinoIcons.refresh,
                          size: 20,
                          semanticLabel: t.common.reset,
                        ),
                        onPressed: () => ref
                            .read(setRegionProvider.notifier)
                            .revertToInitial(),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),

        // 结构化模式：geo_regions 选择器承载下钻/搜索/确认，
        // 页面只负责保存事务、缓存与导航（PROTOCOL §8）。
        // 选择器内部是官方 flutter/material 控件，嵌入点需提供真实
        // Material 祖先与 MaterialLocalizations（fork 类型互不兼容）；
        // transparency 材质不改变 iOS 页面观感。expandBody:false 使
        // 选择器 shrink-wrap 进宿主 CustomScrollView（包内嵌入约定）。
        if (geoMode)
          SliverToBoxAdapter(
            child: picker_material.Localizations(
              locale: LocaleSettings.currentLocale.flutterLocale,
              delegates: const [
                // fork 的 GlobalMaterialLocalizations 与官方 MaterialLocalizations
                // 类型不兼容，选择器需要官方类型，定向豁免弃用提示。
                // ignore: deprecated_member_use
                picker_l10n.GlobalMaterialLocalizations.delegate,
                picker_material.DefaultWidgetsLocalizations.delegate,
              ],
              child: picker_material.Material(
                type: picker_material.MaterialType.transparency,
                child: GeoRegionPicker(
                  dataSource: widget.geoDataSource!,
                  displayLocale: _geoDisplayLocale(),
                  policy: GeoSelectionPolicy.requireLeafWithinDeclared,
                  onConfirmed: (selection) => ref
                      .read(setRegionProvider.notifier)
                      .updateSelectionFromGeo(selection),
                  expandBody: false,
                ),
              ),
            ),
          )
        else ...[
          // 搜索栏
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: CupertinoSearchTextField(
                controller: _searchC,
                placeholder: t.common.regionSearchHint,
              ),
            ),
          ),

          // 地区列表 Section
          if (state.regionList.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: NoDataView(text: t.common.searchNoResults),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 40),
              sliver: SliverToBoxAdapter(
                child: ImBoySettingsSection(
                  header: Text(t.account.region.toUpperCase()),
                  children: state.regionList.map((region) {
                    String title = '';
                    List<dynamic> children = [];
                    if (region is String) {
                      title = region;
                    } else if (region is Map) {
                      title = region['title'] as String? ?? '';
                      children = region['children'] as List<dynamic>? ?? [];
                    }

                    final hasChildren = children.isNotEmpty;
                    final isSelected = selectedPath.contains(title);

                    return Semantics(
                      selected: !hasChildren && isSelected,
                      child: ImBoySettingsTile(
                        title: Text(
                          title,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        trailing: hasChildren
                            ? const CupertinoListTileChevron()
                            : (isSelected
                                  ? Icon(
                                      CupertinoIcons.check_mark,
                                      color: AppColors.getIosBlue(brightness),
                                      size: 18,
                                    )
                                  : const SizedBox.shrink()),
                        onTap: () => _handleSelection(context, title, children),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// 当前 slang locale 到 geo_regions 选择器 displayLocale 的显式映射
  /// （locale 映射不隐式猜测：脚本缺省用语言-地区拼写）。
  String _geoDisplayLocale() {
    final locale = LocaleSettings.currentLocale;
    final script = locale.scriptCode;
    if (script != null && script.isNotEmpty) {
      return '${locale.languageCode}-$script';
    }
    final country = locale.countryCode;
    if (country == null || country.isEmpty) {
      return locale.languageCode;
    }
    return '${locale.languageCode}-$country';
  }

  void _handleSelection(
    BuildContext context,
    String title,
    List<dynamic> children,
  ) {
    if (children.isNotEmpty) {
      Navigator.push(
        context,
        CupertinoPageRoute<dynamic>(
          builder: (_) => _SubRegionPage(
            title: title,
            children: children,
            parentPath: [title],
            onSaveAndExit: _saveAndExit,
          ),
        ),
      );
    } else {
      // 叶子节点：构建完整路径并更新
      ref
          .read(setRegionProvider.notifier)
          .updateSelection(buildRegionPath(const [], title));
    }
  }
}

/// 「完成」歧义提示：省/市/区三级里，选到第二级「完成」就已可点，
/// 用户不知道是不是必须选到第三级。这里显式播报"当前选到第几级 + 可以直接完成"，
/// 不改变可完成的层级（仍是选中任意叶子即可完成），只把状态说清楚。
class _SelectionLevelHint extends StatelessWidget {
  const _SelectionLevelHint({required this.region, required this.level});

  final String region;
  final int level;

  @override
  Widget build(BuildContext context) {
    if (region.isEmpty || level <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        t.common.regionSelectedLevelHint(region: region, level: level),
        style: context.textStyle(
          FontSizeType.footnote,
          color: AppColors.iosGray,
        ),
      ),
    );
  }
}

/// 子级地区页面 - 保持一致的高级质感
class _SubRegionPage extends ConsumerStatefulWidget {
  final String title;
  final List<dynamic> children;
  final List<String> parentPath;
  final Future<void> Function(String) onSaveAndExit;

  const _SubRegionPage({
    required this.title,
    required this.children,
    required this.parentPath,
    required this.onSaveAndExit,
  });

  @override
  ConsumerState<_SubRegionPage> createState() => _SubRegionPageState();
}

class _SubRegionPageState extends ConsumerState<_SubRegionPage> {
  final TextEditingController _searchC = TextEditingController();
  List<dynamic> _displayList = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _displayList = widget.children;
    _searchC.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final kw = _searchC.text.trim().toLowerCase();
      if (!mounted) return;
      setState(() {
        if (kw.isEmpty) {
          _displayList = widget.children;
        } else {
          _displayList = widget.children.where((item) {
            final t = (item is String ? item : (item as Map)['title'] as String)
                .toLowerCase();
            return t.contains(kw);
          }).toList();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(setRegionProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: widget.title,
      useLargeTitle: false,
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: state.hasChanged
              ? () => widget.onSaveAndExit(state.selectedRegion)
              : null,
          child: Text(
            t.common.buttonAccomplish,
            style: TextStyle(
              fontWeight: state.hasChanged ? FontWeight.w600 : FontWeight.w400,
              color: state.hasChanged
                  ? AppColors.getIosBlue(brightness)
                  : AppColors.iosGray,
            ),
          ),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CupertinoSearchTextField(
              controller: _searchC,
              placeholder: t.common.search,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _SelectionLevelHint(
            region: state.selectedRegion,
            level: state.regionPath.length,
          ),
        ),
        if (_displayList.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: NoDataView(text: t.common.searchNoResults),
          )
        else
          SliverToBoxAdapter(
            child: ImBoySettingsSection(
              children: _displayList.map((item) {
                String title = '';
                List<dynamic> children = [];
                if (item is String) {
                  title = item;
                } else if (item is Map) {
                  title = item['title'] as String? ?? '';
                  children = item['children'] as List<dynamic>? ?? [];
                }

                final hasChildren = children.isNotEmpty;
                final isSelected = ref
                    .read(setRegionProvider.notifier)
                    .isRegionSelected(title);

                return Semantics(
                  selected: !hasChildren && isSelected,
                  child: ImBoySettingsTile(
                    title: Text(
                      title,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    trailing: hasChildren
                        ? const CupertinoListTileChevron()
                        : (isSelected
                              ? Icon(
                                  CupertinoIcons.check_mark,
                                  color: AppColors.getIosBlue(brightness),
                                  size: 18,
                                )
                              : const SizedBox.shrink()),
                    onTap: () {
                      if (hasChildren) {
                        Navigator.push(
                          context,
                          CupertinoPageRoute<dynamic>(
                            builder: (_) => _SubRegionPage(
                              title: title,
                              children: children,
                              parentPath: buildRegionPath(
                                widget.parentPath,
                                title,
                              ),
                              onSaveAndExit: widget.onSaveAndExit,
                            ),
                          ),
                        );
                      } else {
                        ref
                            .read(setRegionProvider.notifier)
                            .updateSelection(
                              buildRegionPath(widget.parentPath, title),
                            );
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
