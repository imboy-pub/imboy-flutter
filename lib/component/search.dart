import 'package:flutter/material.dart';

import 'package:niku/namespace.dart' as n;
import 'package:get/get.dart';

// ignore: depend_on_referenced_packages
import 'package:imboy/component/ui/avatar.dart';

class LocalSearchBarDelegate extends SearchDelegate {
  /// This text will be shown in the [AppBar] when
  /// current query is empty.
  final String? searchLabel;
  final String? queryTips;

  final Future<dynamic> Function(dynamic arg1) doSearch;

  /// 点击搜索结果项是触发的方法
  /// Clicking on a search result item is the trigger method
  final void Function(dynamic arg1) onTapForItem;

  LocalSearchBarDelegate({
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
