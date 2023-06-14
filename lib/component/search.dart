import 'package:flutter/material.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/config/const.dart';
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
  required Future<List<dynamic>> Function(dynamic query) doSearch,
}) {
  return SearchBar(
    leading: leading ?? const Icon(Icons.search),
    trailing: trailing,
    hintText: hintText,
    // 取消阴影效果
    elevation: MaterialStateProperty.all(0),
    // 圆角效果
    shape: MaterialStateProperty.all(const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10.0)),
    )),
    hintStyle: MaterialStateProperty.all(TextStyle(
      fontSize: 16,
      color: AppColors.LineColor.withOpacity(0.7),
    )),

    controller: controller,
    focusNode: focusNode,
    onChanged: onChanged,
    onTap: onTapForItem == null
        ? null
        : () {
            showSearch(
              context: context,
              // useRootNavigator: true,
              delegate: SearchBarDelegate(
                searchLabel: searchLabel,
                queryTips: queryTips,
                doSearch: doSearch,
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

  final Future<dynamic> Function(dynamic arg1) doSearch;

  /// 点击搜索结果项是触发的方法
  /// Clicking on a search result item is the trigger method
  final void Function(dynamic arg1) onTapForItem;

  SearchBarDelegate({
    required this.onTapForItem,
    required this.doSearch,
    this.searchLabel,
    this.queryTips,
  }) : super(
          searchFieldLabel: searchLabel,
        );

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      AnimatedOpacity(
        opacity: query.isNotEmpty ? 1.0 : 0.0,
        duration: kThemeAnimationDuration,
        curve: Curves.easeInOutCubic,
        child: IconButton(
          tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
          icon: const Center(child: Icon(Icons.clear)),
          onPressed: () => query = '',
        ),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: transitionAnimation,
      ),
      onPressed: () {
        // close(context, null);
        close(context, 'error');
      },
    );
  }

  @override
  TextInputType get keyboardType => TextInputType.text;

  Future doSearchFuture() async {
    if (query.isEmpty) {
      return [];
    }
    final data = doSearch(query);
    return data;
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
          if (items.isEmpty) {
            return Center(child: Text('No person found :('.tr));
          }
          return n.Padding(
            top: 16,
            child: ListView(
              children: <Widget>[
                for (int i = 0; i < items.length; i++)
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
                      )
                    ]),
                  ),
              ],
            ),
          );
        }

        return const Center(child: CircularProgressIndicator());
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
