import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/select_region/select_region_provider.dart';

/// 选择地区页面
class SelectRegionPage extends ConsumerStatefulWidget {
  final String parent;
  final List children;

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
  // 导航图标
  static const Widget navigateNextIcon = Icon(Icons.navigate_next, size: 20);

  @override
  void initState() {
    super.initState();
    // 延迟初始化，避免在 build 期间修改状态
    Future.delayed(const Duration(milliseconds: 100), () {
      ref.read(selectRegionProvider.notifier).valueOnChange(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(selectRegionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        titleWidget: Row(
          children: [
            Expanded(
              child: Text(
                t.setParam(param: t.region),
                textAlign: TextAlign.center,
              ),
            ),
            RoundedElevatedButton(
              text: t.buttonAccomplish,
              highlighted: provider.valueChanged,
              onPressed: () async {
                var nav = Navigator.of(context);
                bool res = await widget.outCallback(provider.selectedVal);
                if (res) {
                  int t = provider.selectedVal.split(" ").length;
                  for (var i = 0; i < t; i++) {
                    nav.pop();
                  }
                }
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 34.0),
            width: MediaQuery.of(context).size.width,
            height: 40.0,
            child: Text(
              provider.selectedVal.isEmpty ? t.all : provider.selectedVal,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemBuilder: (BuildContext context, int index) {
                return _buildListItem(
                  context: context,
                  parent: widget.parent,
                  model: widget.children[index],
                  margin: const EdgeInsets.only(left: 16, right: 16),
                  isDark: isDark,
                );
              },
              itemCount: widget.children.length,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建列表项
  Widget _buildListItem({
    required BuildContext context,
    required String parent,
    required dynamic model,
    required EdgeInsetsGeometry margin,
    required bool isDark,
  }) {
    final notifier = ref.read(selectRegionProvider.notifier);
    final provider = ref.watch(selectRegionProvider);

    String title = notifier.getRegionTitle(model);
    List children = notifier.getRegionChildren(model);
    bool haveChildren = children.isNotEmpty;
    title = title.trim();

    final isSelected = notifier.isRegionSelected(title);

    return Container(
      height: 52,
      margin: margin,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 1,
            color: isDark
                ? const Color.fromRGBO(68, 68, 68, 1.0)
                : const Color.fromRGBO(200, 200, 200, 1.0),
          ),
        ),
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: isSelected ? 20 : 16,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        selected: isSelected,
        onTap: () {
          if (kDebugMode) iPrint("region_item_onTap selectedVal updated");
          List<String> items = parent.split(' ');
          items.add(title);
          items = items.toSet().toList();
          notifier.updateSelectedVal(items.join(' '));
          if (kDebugMode) {
            iPrint("region_item_onTap haveChildren: $haveChildren");
          }

          if (haveChildren) {
            parent = provider.selectedVal;
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (_) => SelectRegionPage(
                  parent: parent,
                  children: children,
                  callback: widget.callback,
                  outCallback: widget.outCallback,
                ),
              ),
            );
          } else {
            if (parent == provider.selectedVal) {
              notifier.valueOnChange(false);
            } else {
              widget.callback(parent, title);
              notifier.regionSelectedTitle(title);
              notifier.valueOnChange(true);
            }
          }
        },
        trailing: haveChildren
            ? navigateNextIcon
            : (isSelected && provider.regionSelected[title] != null
                  ? provider.regionSelected[title]!['trailing']
                  : null),
      ),
    );
  }
}
