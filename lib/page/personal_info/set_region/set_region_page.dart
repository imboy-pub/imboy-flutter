import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'set_region_provider.dart';

/// 选择地区页面 - 像素级对齐 iOS 17 高效表单
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
  final ScrollController _scrollC = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(setRegionProvider.notifier).initData(widget.currentValue);
    });
    _searchC.addListener(_onTopQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    _searchF.dispose();
    _scrollC.dispose();
    super.dispose();
  }

  void _onTopQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final kw = _searchC.text.trim();
      ref.read(setRegionProvider.notifier).applyTopSearch(kw);
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
            final success = await widget.onSave(state.selectedRegion);
            if (success && context.mounted) Navigator.of(context).pop();
          } : null,
          child: Text(t.common.buttonAccomplish, style: TextStyle(fontWeight: state.hasChanged ? FontWeight.w600 : FontWeight.w400, color: state.hasChanged ? AppColors.getIosBlue(brightness) : AppColors.iosGray)),
        ),
      ],
      slivers: [
        // 搜索框
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CupertinoSearchTextField(
              controller: _searchC,
              focusNode: _searchF,
              placeholder: t.common.regionSearchHint,
              onSubmitted: (v) => _onTopQueryChanged(),
            ),
          ),
        ),

        // 当前选择 Section
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            header: Text(t.common.selectedRegion.toUpperCase()),
            children: [
              ImBoySettingsTile(
                title: Text(state.selectedRegion.isEmpty ? t.main.pleaseSelect : state.selectedRegion),
                trailing: const SizedBox.shrink(),
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
                  onTap: () => ref.read(setRegionProvider.notifier).selectRegion(title, children, context, widget.onSave),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
