import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/user_tag/contact_tag_detail/contact_tag_detail_page.dart';
import 'package:imboy/page/user_tag/user_tag_save/user_tag_save_page.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'contact_tag_list_provider.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 联系人标签列表页面
class ContactTagListPage extends ConsumerStatefulWidget {
  const ContactTagListPage({super.key});

  @override
  ConsumerState<ContactTagListPage> createState() => _ContactTagListPageState();
}

class _ContactTagListPageState extends ConsumerState<ContactTagListPage> {
  final ScrollController _controller = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _kwd = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contactTagListProvider.notifier).loadData();
      _initScrollListener();
    });
  }

  void _initScrollListener() {
    _controller.addListener(() async {
      double pixels = _controller.position.pixels;
      double maxScrollExtent = _controller.position.maxScrollExtent;
      if (pixels == maxScrollExtent) {
        await ref.read(contactTagListProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 构建标签项
  Widget buildItem(int index, UserTagModel obj) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Slidable(
      key: ValueKey(obj.tagId),
      groupTag: '0',
      closeOnScroll: true,
      endActionPane: ActionPane(
        extentRatio: 0.75,
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            key: ValueKey("change_name_$index"),
            flex: 2,
            backgroundColor: Colors.black87,
            onPressed: (_) async {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: isDark
                    ? const Color.fromRGBO(80, 80, 80, 1)
                    : const Color.fromRGBO(240, 240, 240, 1),
                builder: (context) =>
                    UserTagSavePage(tag: obj, scene: 'friend'),
              );
            },
            label: t.changeParam(param: t.name),
            spacing: 1,
          ),
          SlidableAction(
            key: ValueKey("delete_$index"),
            flex: 1,
            backgroundColor: AppColors.iosRed,
            onPressed: (_) async {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: isDark
                    ? const Color.fromRGBO(80, 80, 80, 1)
                    : const Color.fromRGBO(240, 240, 240, 1),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    topRight: Radius.circular(20.0),
                  ),
                ),
                builder: (context) => SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: 172,
                  child: Column(
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            t.deleteTagTips,
                            textAlign: TextAlign.center,
                            style: context.textStyle(
                              FontSizeType.normal,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      const Divider(),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            const String scene = 'friend';
                            bool res = await ref
                                .read(contactTagListProvider.notifier)
                                .deleteTag(
                                  tagId: obj.tagId,
                                  tagName: obj.name,
                                  scene: scene,
                                );
                            if (res) {
                              Navigator.of(context).pop();
                              EasyLoading.showSuccess(t.tipSuccess);
                            } else {
                              EasyLoading.showError(t.tipFailed);
                            }
                          },
                          child: Text(
                            t.buttonDelete,
                            textAlign: TextAlign.center,
                            style: context.textStyle(
                              FontSizeType.normal,
                              color: Colors.red,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      const HorizontalLine(height: 6),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            t.buttonCancel,
                            textAlign: TextAlign.center,
                            style: context.textStyle(
                              FontSizeType.normal,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            label: t.buttonDelete,
            spacing: 1,
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 2),
        padding: const EdgeInsets.all(10),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute<dynamic>(
                builder: (context) => ContactTagDetailPage(tag: obj),
              ),
            );
          },
          child: Column(
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      obj.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(' (${obj.refererTime})'),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      obj.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const HorizontalLine(height: 1.0),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(contactTagListProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.contactTags,
        rightDMActions: <Widget>[
          InkWell(
            child: const SizedBox(
              width: 46.0,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Icon(Icons.add),
              ),
            ),
            onTap: () {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color.fromRGBO(80, 80, 80, 1)
                    : const Color.fromRGBO(240, 240, 240, 1),
                builder: (context) => UserTagSavePage(scene: 'friend'),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(contactTagListProvider.notifier).refresh();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
              child: searchBar(
                context,
                leading: InkWell(
                  onTap: () {
                    ref.read(contactTagListProvider.notifier).doSearch(_kwd);
                  },
                  child: const Icon(Icons.search),
                ),
                trailing: _kwd.isEmpty
                    ? null
                    : [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _kwd = '';
                              _searchController.text = '';
                            });
                            ref
                                .read(contactTagListProvider.notifier)
                                .doSearch(_kwd);
                          },
                          child: const Icon(Icons.close),
                        ),
                      ],
                controller: _searchController,
                searchLabel: t.search,
                hintText: t.search,
                onChanged: (query) async {
                  setState(() {
                    _kwd = query;
                  });
                  if (kDebugMode) debugPrint("contact_tag_view_onChanged");
                  await ref
                      .read(contactTagListProvider.notifier)
                      .doSearch(query);
                },
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SlidableAutoCloseBehavior(
                  child: listState.items.isEmpty
                      ? NoDataView(text: t.noData)
                      : ListView.builder(
                          controller: _controller,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: listState.items.length,
                          itemBuilder: (BuildContext context, int index) {
                            UserTagModel obj = listState.items[index];
                            return buildItem(index, obj);
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
