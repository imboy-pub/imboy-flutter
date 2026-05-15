import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'set_region_provider.dart';

/// 设置地区页面 - 像素级对齐 iOS 17 Premium 风格
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
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(setRegionProvider.notifier).initData(widget.currentValue);
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
      if (mounted) ref.read(setRegionProvider.notifier).applyTopSearch(_searchC.text);
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
          onPressed: state.hasChanged ? () async {
            if (await widget.onSave(state.selectedRegion) && context.mounted) Navigator.of(context).pop();
          } : null,
          child: Text(t.common.buttonAccomplish, style: TextStyle(fontWeight: state.hasChanged ? FontWeight.w600 : FontWeight.w400, color: state.hasChanged ? AppColors.getIosBlue(brightness) : AppColors.iosGray)),
        ),
      ],
      slivers: [
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

        // 当前选择回显 Section - 增强视觉提示
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            header: Text(t.common.selectedRegion.toUpperCase()),
            children: [
              ImBoySettingsTile(
                title: Text(state.selectedRegion.isEmpty ? t.main.pleaseSelect : state.selectedRegion, style: TextStyle(color: state.selectedRegion.isEmpty ? AppColors.iosGray : AppColors.primary, fontWeight: state.selectedRegion.isEmpty ? FontWeight.normal : FontWeight.w600)),
                trailing: state.hasChanged ? CupertinoButton(padding: EdgeInsets.zero, child: const Icon(CupertinoIcons.refresh, size: 20), onPressed: () => ref.read(setRegionProvider.notifier).revertToInitial()) : const SizedBox.shrink(),
              ),
            ],
          ),
        ),

        // 地区列表 Section
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 40),
          sliver: SliverToBoxAdapter(
            child: ImBoySettingsSection(
              header: Text(t.account.region.toUpperCase()),
              children: state.regionList.map((region) {
                String title = '';
                List<dynamic> children = [];
                if (region is String) title = region;
                else if (region is Map) { title = region['title'] as String? ?? ''; children = region['children'] as List<dynamic>? ?? []; }
                
                final hasChildren = children.isNotEmpty;
                final isSelected = ref.read(setRegionProvider.notifier).isRegionSelected(title);

                return ImBoySettingsTile(
                  title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                  trailing: hasChildren ? const CupertinoListTileChevron() : (isSelected ? Icon(CupertinoIcons.check_mark, color: AppColors.getIosBlue(brightness), size: 18) : const SizedBox.shrink()),
                  onTap: () => _handleSelection(context, title, children),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  void _handleSelection(BuildContext context, String title, List<dynamic> children) {
    if (children.isNotEmpty) {
      Navigator.push(context, CupertinoPageRoute<dynamic>(builder: (_) => _SubRegionPage(title: title, children: children, onSave: widget.onSave)));
    } else {
      // 叶子节点：构建完整路径并更新
      ref.read(setRegionProvider.notifier).updateSelection([title]);
    }
  }
}

/// 子级地区页面 - 保持一致的高级质感
class _SubRegionPage extends ConsumerStatefulWidget {
  final String title;
  final List<dynamic> children;
  final Future<bool> Function(String) onSave;

  const _SubRegionPage({required this.title, required this.children, required this.onSave});

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
        if (kw.isEmpty) _displayList = widget.children;
        else {
          _displayList = widget.children.where((item) {
            final t = (item is String ? item : (item as Map)['title'] as String).toLowerCase();
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
          onPressed: state.hasChanged ? () async {
            if (await widget.onSave(state.selectedRegion) && context.mounted) {
              Navigator.of(context)..pop()..pop(); // 返回到主设置页
            }
          } : null,
          child: Text(t.common.buttonAccomplish, style: TextStyle(fontWeight: state.hasChanged ? FontWeight.w600 : FontWeight.w400, color: state.hasChanged ? AppColors.getIosBlue(brightness) : AppColors.iosGray)),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CupertinoSearchTextField(controller: _searchC, placeholder: t.common.search),
          ),
        ),
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            children: _displayList.map((item) {
              String title = '';
              List<dynamic> children = [];
              if (item is String) title = item;
              else if (item is Map) { title = item['title'] as String? ?? ''; children = item['children'] as List<dynamic>? ?? []; }
              
              final hasChildren = children.isNotEmpty;
              final isSelected = ref.read(setRegionProvider.notifier).isRegionSelected(title);

              return ImBoySettingsTile(
                title: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                trailing: hasChildren ? const CupertinoListTileChevron() : (isSelected ? Icon(CupertinoIcons.check_mark, color: AppColors.getIosBlue(brightness), size: 18) : const SizedBox.shrink()),
                onTap: () {
                  if (hasChildren) {
                    Navigator.push(context, CupertinoPageRoute<dynamic>(builder: (_) => _SubRegionPage(title: title, children: children, onSave: widget.onSave)));
                  } else {
                    // 假设简单的二级逻辑，实际可扩展
                    final path = List<String>.from(state.regionPath);
                    // 逻辑：如果当前标题已在路径中，截断；否则追加
                    final idx = path.indexOf(widget.title);
                    final newPath = idx >= 0 ? (path.sublist(0, idx + 1)..add(title)) : [widget.title, title];
                    ref.read(setRegionProvider.notifier).updateSelection(newPath);
                  }
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
