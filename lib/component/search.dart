import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: depend_on_referenced_packages
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/line.dart';

import 'package:niku/namespace.dart' as n;

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
  return SearchBar(
    leading: leading ?? const Icon(Icons.search),
    trailing: trailing,
    hintText: hintText,
    // 取消阴影效果
    elevation: WidgetStateProperty.all(0),
    // 圆角效果
    shape: WidgetStateProperty.all(const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10.0)),
    )),
    hintStyle: WidgetStateProperty.all(const TextStyle(
      fontSize: 14,
      // color: AppColors.LineColor.withOpacity(0.7),
    )),
    backgroundColor:
        WidgetStatePropertyAll<Color>(Theme.of(context).colorScheme.primary),
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
  }) : super(
          searchFieldLabel: searchLabel,
        );

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      AnimatedOpacity(
        opacity: query.isEmpty ? 0.0 : 1.0,
        duration: kThemeAnimationDuration,
        curve: Curves.easeInOutCubic,
        child: IconButton(
          tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
          icon: const Center(
              child: Icon(
            Icons.clear,
            size: 28,
          )),
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
      tooltip: 'button_back'.tr,
      icon: AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: transitionAnimation,
      ),
      onPressed: () {
        // close(context, null);
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
    // if (int.parse(query) >= 100) {
    //   return Center(child: Text('请输入小于 100 的数字'));
    // }
    if (query.isEmpty) {
      return Center(
        // child: Text('Filter people by name, surname or age'),
        child: Text(queryTips ?? ''),
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
              return Center(child: Text('search_no_found'.tr));
            }
            return n.Padding(
              top: 16,
              child: ListView(
                children: <Widget>[
                  for (int i = 0; i < items.length; i++)
                    n.Column([
                      n.ListTile(
                        // selected: true,
                        onTap: () {
                          onTapForItem(items[i]);
                        },
                        leading: Avatar(
                          imgUri: items[i].avatar,
                          onTap: () {},
                        ),
                        title: n.Row([
                          Expanded(
                            child: Text(
                              // 会话对象标题
                              items[i].title,
                              style: const TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.normal,
                              ),
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ),
                      n.Padding(
                        left: 16,
                        right: 16,
                        bottom: 10,
                        child: const HorizontalLine(height: 1.0),
                      ),
                    ]),
                ],
              ),
            );
          }
        }

        return const Center(
          child: CircularProgressIndicator(),
          // child: Text('Filter people by name, surname or age'),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Center(
      // child: Text('Filter people by name, surname or age'),
      child: Text(queryTips ?? ''),
    );
    // return ListView(
    //   children: <Widget>[
    //     ListTile(title: Text('Suggest 01')),
    //     ListTile(title: Text('Suggest 02')),
    //     ListTile(title: Text('Suggest 03')),
    //     ListTile(title: Text('Suggest 04')),
    //     ListTile(title: Text('Suggest 05')),
    //   ],
    // );
  }
}
