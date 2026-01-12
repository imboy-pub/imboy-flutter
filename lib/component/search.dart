import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 搜索栏组件 - 使用新的主题系统
Widget searchBar(
  BuildContext context, {
  String? hintText,
  String? queryTips,
  String? searchLabel,
  Widget? leading,

  /// A list of Widgets to display in a row after the text field.
  ///
  /// Typically these actions can represent additional modes of searching
  /// (like voice search), an avatar, a separate high-level action (such as
  /// current location) or an overflow menu. There should not be more than
  /// two trailing actions.
  final Iterable<Widget>? trailing,

  /// Controls the text being edited in the search bar's text field.
  ///
  /// If null, this widget will create its own [TextEditingController].
  final TextEditingController? controller,

  /// {@macro flutter.widgets.Focus.focusNode}
  final FocusNode? focusNode,

  /// Invoked upon user input.
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
      hintText: hintText ?? '搜索',
      // 使用新的搜索主题配置
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
        BorderSide(color: ThemeManager.instance.getThemeColor('border'), width: 0.5),
      ),
      hintStyle: WidgetStateProperty.all(
        TextStyle(
          color: ThemeManager.instance.getThemeColor('textSecondary'),
          fontSize: ThemeManager.instance.getFontSize(FontSizeType.medium, context: context),
          height: 1.4,
        ),
      ),
      textStyle: WidgetStateProperty.all(
        TextStyle(
          color: ThemeManager.instance.getThemeColor('textPrimary'),
          fontSize: ThemeManager.instance.getFontSize(FontSizeType.medium, context: context),
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
  /// This text will be shown in the [AppBar] when
  /// current query is empty.
  final String? searchLabel;
  final String? queryTips;

  final Future<dynamic> Function(dynamic arg1)? doSearch;
  final Widget Function(List<dynamic>)? doBuildResults;

  /// 点击搜索结果项是触发的方法
  /// Clicking on a search result item is the trigger method
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
          onPressed: () {
            query = '';
          },
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
        // 收起键盘
        FocusScope.of(context).requestFocus(FocusNode());
      },
    );
  }

  @override
  TextInputType get keyboardType => TextInputType.text;

  Future doSearchFuture() async {
    if (query.isEmpty) {
      return [];
    }
    if (doSearch == null) {
      return [];
    }
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
              .copyWith(color: ThemeManager.instance.getThemeColor('textSecondary')),
        ),
      );
    }

    return FutureBuilder(
      future: doSearchFuture(),
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {
          List<dynamic> items = snapshot.data;

          if (doBuildResults != null) {
            return doBuildResults!(items);
          } else {
            if (items.isEmpty) {
              return Center(
                child: Text(
                  t.searchNoFound,
                  style: ThemeManager.instance
                      .getTextStyle(FontSizeType.medium, context: context)
                      .copyWith(color: ThemeManager.instance.getThemeColor('textSecondary')),
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
                            onTap: () {
                              onTapForItem(items[i]);
                            },
                            leading: Avatar(
                              imgUri: items[i].avatar,
                              onTap: () {},
                              width: 40,
                              height: 40,
                            ),
                            title: Text(
                              // 会话对象标题
                              items[i].title,
                              style: ThemeManager.instance
                                  .getTextStyle(FontSizeType.large, context: context)
                                  .copyWith(
                                    fontWeight: FontWeight.normal,
                                    color: ThemeManager.instance.getThemeColor('textPrimary'),
                                    height: 1.4,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Container(
                          height: ThemeManager.instance.mainLineWidth,
                          margin: const EdgeInsets.only(left: 72),
                          color: ThemeManager.instance.getThemeColor('border'),
                        ),
                      ],
                    ),
                ],
              ),
            );
          }
        }

        return Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              ThemeManager.instance.getThemeColor('primary'),
            ),
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
              .copyWith(color: ThemeManager.instance.getThemeColor('textSecondary')),
        ),
      ),
    );
  }
}
