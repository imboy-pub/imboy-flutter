part of 'set_region_page.dart';

/// 「完成」歧义提示：省/市/区三级里，选到第二级「完成」就已可点，
/// 用户不知道是不是必须选到第三级。这里显式播报"当前选到第几级 + 可以直接完成"，
/// 不改变可完成的层级（仍是选中任意叶子即可完成），只把状态说清楚。
class _SelectionLevelHint extends StatelessWidget {
  const _SelectionLevelHint({
    required this.region,
    required this.level,
    this.fontFamilyFallback,
  });

  final String region;
  final int level;
  final List<String>? fontFamilyFallback;

  @override
  Widget build(BuildContext context) {
    if (region.isEmpty || level <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        t.common.regionSelectedLevelHint(region: region, level: level),
        style: context
            .textStyle(FontSizeType.footnote, color: AppColors.iosGray)
            .copyWith(fontFamilyFallback: fontFamilyFallback),
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
