import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/page/mine/select_region/select_region_provider.dart';

/// 选择地区页面 - 像素级对齐 iOS 17 Premium 风格
class SelectRegionPage extends ConsumerStatefulWidget {
  final String parent;
  final List<dynamic> children;
  final Future<bool> Function(String, String) callback;
  final Future<bool> Function(String) outCallback;

  const SelectRegionPage({
    super.key,
    required this.parent,
    required this.children,
    required this.callback,
    required this.outCallback,
  });

  @override
  ConsumerState<SelectRegionPage> createState() => _SelectRegionPageState();
}

class _SelectRegionPageState extends ConsumerState<SelectRegionPage> {
  final TextEditingController _searchC = TextEditingController();
  List<dynamic> _displayList = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _displayList = widget.children;
    _searchC.addListener(_onSearchChanged);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) ref.read(selectRegionProvider.notifier).valueOnChange(false);
    });
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
      if (!mounted) return;
      final kw = _searchC.text.trim().toLowerCase();
      final notifier = ref.read(selectRegionProvider.notifier);
      setState(() {
        if (kw.isEmpty) {
          _displayList = widget.children;
        } else {
          _displayList = widget.children.where((item) {
            final t = notifier.getRegionTitle(item).toLowerCase();
            return t.contains(kw);
          }).toList();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(selectRegionProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.main.setParam(param: t.account.region),
      useLargeTitle: false,
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: provider.valueChanged
              ? () async {
                  var nav = Navigator.of(context);
                  if (await widget.outCallback(provider.selectedVal)) {
                    int steps = provider.selectedVal.split(" ").length;
                    for (var i = 0; i < steps; i++) {
                      nav.pop();
                    }
                  }
                }
              : null,
          child: Text(
            t.common.buttonAccomplish,
            style: TextStyle(
              fontWeight: provider.valueChanged
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: provider.valueChanged
                  ? AppColors.getIosBlue(brightness)
                  : AppColors.iosGray,
            ),
          ),
        ),
      ],
      slivers: [
        // 搜索框
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.regular,
              AppSpacing.medium,
              AppSpacing.regular,
              AppSpacing.small,
            ),
            child: CupertinoSearchTextField(
              controller: _searchC,
              placeholder: t.common.search,
            ),
          ),
        ),

        // 路径回显 Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              28,
              AppSpacing.tiny,
              AppSpacing.regular,
              AppSpacing.tiny,
            ),
            child: Text(
              provider.selectedVal.isEmpty
                  ? t.common.all
                  : provider.selectedVal,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosGray,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        // 列表 Section
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            children: _displayList
                .map(
                  (model) =>
                      _buildListItem(context, widget.parent, model, brightness),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildListItem(
    BuildContext context,
    String parent,
    dynamic model,
    Brightness brightness,
  ) {
    final notifier = ref.read(selectRegionProvider.notifier);
    ref.watch(selectRegionProvider);
    String title = notifier.getRegionTitle(model).trim();
    List<dynamic> children = notifier.getRegionChildren(model);
    bool haveChildren = children.isNotEmpty;
    final isSelected = notifier.isRegionSelected(title);

    return ImBoySettingsTile(
      title: Text(
        title,
        style: context.textStyle(
          FontSizeType.body,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: haveChildren
          ? const CupertinoListTileChevron()
          : (isSelected
                ? Icon(
                    CupertinoIcons.check_mark,
                    size: 18,
                    color: AppColors.getIosBlue(brightness),
                  )
                : const SizedBox.shrink()),
      onTap: () {
        List<String> items = parent.split(' ')..add(title);
        final selectedVal = items.toSet().toList().join(' ').trim();
        notifier.updateSelectedVal(selectedVal);
        if (haveChildren) {
          Navigator.push(
            context,
            CupertinoPageRoute<void>(
              builder: (_) => SelectRegionPage(
                parent: selectedVal,
                children: children,
                callback: widget.callback,
                outCallback: widget.outCallback,
              ),
            ),
          );
        } else {
          if (parent != selectedVal) {
            widget.callback(parent, title);
            notifier.regionSelectedTitle(title);
            notifier.valueOnChange(true);
          } else {
            notifier.valueOnChange(false);
          }
        }
      },
    );
  }
}
