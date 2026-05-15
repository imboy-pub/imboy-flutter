import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/page/mine/select_region/select_region_provider.dart';

/// 选择地区页面 - 像素级对齐 iOS 设置风
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
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) ref.read(selectRegionProvider.notifier).valueOnChange(false);
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
          onPressed: () async {
            var nav = Navigator.of(context);
            if (await widget.outCallback(provider.selectedVal)) {
              int steps = provider.selectedVal.split(" ").length;
              for (var i = 0; i < steps; i++) nav.pop();
            }
          },
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 12, 16, 4),
            child: Text(
              provider.selectedVal.isEmpty
                  ? t.common.all
                  : provider.selectedVal,
              style: const TextStyle(fontSize: 13, color: AppColors.iosGray),
            ),
          ),
          ImBoySettingsSection(
            children: widget.children
                .map(
                  (model) =>
                      _buildListItem(context, widget.parent, model, brightness),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(
    BuildContext context,
    String parent,
    dynamic model,
    Brightness brightness,
  ) {
    final notifier = ref.read(selectRegionProvider.notifier);
    final provider = ref.watch(selectRegionProvider);
    String title = notifier.getRegionTitle(model).trim();
    List<dynamic> children = notifier.getRegionChildren(model);
    bool haveChildren = children.isNotEmpty;
    final isSelected = notifier.isRegionSelected(title);

    return ImBoySettingsTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: haveChildren
          ? const CupertinoListTileChevron()
          : (isSelected && provider.regionSelected[title] != null
                ? (provider.regionSelected[title]!['trailing'] as Widget? ??
                      Icon(
                        CupertinoIcons.check_mark,
                        size: 18,
                        color: AppColors.getIosBlue(brightness),
                      ))
                : const SizedBox.shrink()),
      onTap: () {
        List<String> items = parent.split(' ')..add(title);
        final selectedVal = items.toSet().toList().join(' ');
        notifier.updateSelectedVal(selectedVal);
        if (haveChildren) {
          Navigator.push(
            context,
            CupertinoPageRoute(
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
          } else
            notifier.valueOnChange(false);
        }
      },
    );
  }
}
