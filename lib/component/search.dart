import 'package:flutter/material.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 搜索栏组件
Widget searchBar(
  BuildContext context, {
  String? hintText,
  String? queryTips,
  String? searchLabel,
  Widget? leading,
  final Iterable<Widget>? trailing,
  final TextEditingController? controller,
  final FocusNode? focusNode,
  final ValueChanged<String>? onChanged,
  final Null Function(dynamic value)? onTapForItem,
  Future<List<dynamic>> Function(dynamic query)? doSearch,
  Widget Function(List<dynamic>)? doBuildResults,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: SearchBar(
      leading:
          leading ??
          Icon(
            Icons.search,
            color: ThemeManager.instance.getThemeColor('textSecondary'),
            size: 20,
          ),
      trailing: trailing,
      hintText: hintText ?? t.search,
      elevation: WidgetStateProperty.all(0),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
      backgroundColor: WidgetStateProperty.all(
        Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      side: WidgetStateProperty.all(
        BorderSide(
          color: ThemeManager.instance.getThemeColor('border'),
          width: 0.5,
        ),
      ),
      hintStyle: WidgetStateProperty.all(
        TextStyle(
          color: ThemeManager.instance.getThemeColor('textSecondary'),
          fontSize: ThemeManager.instance.getFontSize(
            FontSizeType.medium,
            context: context,
          ),
          height: 1.4,
        ),
      ),
      textStyle: WidgetStateProperty.all(
        TextStyle(
          color: ThemeManager.instance.getThemeColor('textPrimary'),
          fontSize: ThemeManager.instance.getFontSize(
            FontSizeType.medium,
            context: context,
          ),
          height: 1.4,
        ),
      ),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onTap: onTapForItem == null
          ? null
          : () {
              showSearch(
                context: context,
                delegate: SearchBarDelegate(
                  searchLabel: searchLabel,
                  queryTips: queryTips,
                  doSearch: doSearch,
                  doBuildResults: doBuildResults,
                  onTapForItem: onTapForItem,
                ),
              );
            },
    ),
  );
}

class SearchBarDelegate extends SearchDelegate {
  final String? searchLabel;
  final String? queryTips;
  final Future<dynamic> Function(dynamic arg1)? doSearch;
  final Widget Function(List<dynamic>)? doBuildResults;
  final void Function(dynamic arg1) onTapForItem;

  SearchBarDelegate({
    required this.onTapForItem,
    this.doSearch,
    this.doBuildResults,
    this.searchLabel,
    this.queryTips,
  }) : super(searchFieldLabel: searchLabel);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      AnimatedOpacity(
        opacity: query.isEmpty ? 0.0 : 1.0,
        duration: kThemeAnimationDuration,
        curve: Curves.easeInOutCubic,
        child: IconButton(
          tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
          icon: Icon(
            Icons.clear,
            size: 20,
            color: ThemeManager.instance.getThemeColor('textSecondary'),
          ),
          onPressed: () => query = '',
        ),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      tooltip: t.buttonBack,
      icon: Icon(
        Icons.arrow_back_ios,
        size: 20,
        color: ThemeManager.instance.getThemeColor('textPrimary'),
      ),
      onPressed: () {
        close(context, 'error');
        FocusScope.of(context).requestFocus(FocusNode());
      },
    );
  }

  @override
  TextInputType get keyboardType => TextInputType.text;

  Future doSearchFuture() async {
    if (query.isEmpty || doSearch == null) return [];
    return doSearch!(query);
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Text(
          queryTips ?? '',
          style: ThemeManager.instance
              .getTextStyle(FontSizeType.medium, context: context)
              .copyWith(
                color: ThemeManager.instance.getThemeColor('textSecondary'),
              ),
        ),
      );
    }

    return FutureBuilder(
      future: doSearchFuture(),
      builder: (context, AsyncSnapshot snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                ThemeManager.instance.getThemeColor('primary'),
              ),
            ),
          );
        }

        List<dynamic> items = snapshot.data;

        if (doBuildResults != null) {
          return doBuildResults!(items);
        }

        if (items.isEmpty) {
          return Center(
            child: Text(
              t.searchNoFound,
              style: ThemeManager.instance
                  .getTextStyle(FontSizeType.medium, context: context)
                  .copyWith(
                    color: ThemeManager.instance.getThemeColor('textSecondary'),
                  ),
            ),
          );
        }

        return Container(
          color: ThemeManager.instance.getThemeColor('surface'),
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              for (int i = 0; i < items.length; i++)
                Column(
                  children: [
                    Container(
                      color: ThemeManager.instance.getThemeColor('surface'),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        onTap: () => onTapForItem(items[i]),
                        leading: Avatar(
                          imgUri: items[i].avatar,
                          onTap: () {},
                          width: 40,
                          height: 40,
                        ),
                        title: Text(
                          items[i].title,
                          style: ThemeManager.instance
                              .getTextStyle(
                                FontSizeType.large,
                                context: context,
                              )
                              .copyWith(
                                fontWeight: FontWeight.normal,
                                color: ThemeManager.instance.getThemeColor(
                                  'textPrimary',
                                ),
                                height: 1.4,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Container(
                      height: 0.5,
                      margin: const EdgeInsets.only(left: 72),
                      color: ThemeManager.instance.getThemeColor('border'),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container(
      color: ThemeManager.instance.getThemeColor('surface'),
      child: Center(
        child: Text(
          queryTips ?? '',
          style: ThemeManager.instance
              .getTextStyle(FontSizeType.medium, context: context)
              .copyWith(
                color: ThemeManager.instance.getThemeColor('textSecondary'),
              ),
        ),
      ),
    );
  }
}
