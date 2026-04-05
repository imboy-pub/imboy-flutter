import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/user_tag/contact_tag_list/contact_tag_list_provider.dart';
import 'package:imboy/page/user_tag/user_tag_save/user_tag_save_page.dart';
import 'package:imboy/service/assets.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:lpinyin/lpinyin.dart';

import 'contact_tag_detail_provider.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 联系人标签详情页面
class ContactTagDetailPage extends ConsumerStatefulWidget {
  final UserTagModel tag;

  const ContactTagDetailPage({super.key, required this.tag});

  @override
  ConsumerState<ContactTagDetailPage> createState() =>
      _ContactTagDetailPageState();
}

class _ContactTagDetailPageState extends ConsumerState<ContactTagDetailPage> {
  final TextEditingController _searchController = TextEditingController();
  String _kwd = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(contactTagDetailProvider.notifier)
          .loadTagData(
            tagName: widget.tag.name,
            refererTime: widget.tag.refererTime,
            tagId: widget.tag.tagId,
          );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 构建聊天列表项
  Widget _buildChatListItem(
    BuildContext context,
    ContactModel model, {
    Color? defHeaderBgColor,
  }) {
    return InkWell(
      onTap: model.onPressed,
      onLongPress: model.onLongPressed,
      child: Container(
        color: model.bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // 头像或图标
            if (model.iconData != null)
              SizedBox(width: 49, height: 49, child: model.iconData)
            else
              Avatar(imgUri: model.avatar, width: 49, height: 49),
            const Space(),
            // 名称和签名
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(model.title, style: const TextStyle(fontSize: 16)),
                  if (model.sign.isNotEmpty)
                    Text(
                      model.sign,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建悬浮标签项（A-Z 分组标题）
  Widget _buildSusItem(BuildContext context, String tag) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 32,
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16),
      alignment: Alignment.centerLeft,
      color: isDark ? Colors.grey[800] : Colors.grey[200],
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 添加联系人
  Future<void> addContact(BuildContext ctx) async {
    final detailState = ref.watch(contactTagDetailProvider);
    await Navigator.push(
      ctx,
      CupertinoPageRoute(
        builder: (_) => SelectFriendPage(
          tag: widget.tag,
          tagContactList: detailState.contactList,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(contactTagDetailProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        titleWidget: Text(
          '${detailState.tagName} (${detailState.refererTime})',
        ),
        rightDMActions: [
          InkWell(
            onTap: () {
              showModalBottomSheet(
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
                        child: TextButton(
                          child: Text(
                            t.changeParam(param: t.tags),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: isDark
                                  ? const Color.fromRGBO(80, 80, 80, 1)
                                  : const Color.fromRGBO(240, 240, 240, 1),
                              builder: (context) => UserTagSavePage(
                                tag: widget.tag,
                                scene: 'friend',
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            // 显示删除确认
                            await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                contentPadding: const EdgeInsets.fromLTRB(
                                  20,
                                  20,
                                  20,
                                  0,
                                ),
                                content: Text(t.deleteTagTips),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(t.buttonCancel),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      const String scene = 'friend';
                                      bool res = await ref
                                          .read(contactTagListProvider.notifier)
                                          .deleteTag(
                                            tagId: widget.tag.tagId,
                                            tagName: widget.tag.name,
                                            scene: scene,
                                          );
                                      if (res) {
                                        await ref
                                            .read(
                                              contactTagListProvider.notifier,
                                            )
                                            .replaceObjectTag(
                                              scene: scene,
                                              oldName: widget.tag.name,
                                              newName: '',
                                            );
                                        Navigator.pop(context, true);
                                        if (mounted) Navigator.pop(context);
                                        EasyLoading.showSuccess(t.tipSuccess);
                                      } else {
                                        Navigator.pop(context, false);
                                        EasyLoading.showError(t.tipFailed);
                                      }
                                    },
                                    child: Text(t.buttonConfirm),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Text(
                            t.buttonDelete,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
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
                            style: const TextStyle(
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Icon(
                Icons.more_horiz,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
                child: searchBar(
                  context,
                  leading: InkWell(
                    onTap: () {
                      ref
                          .read(contactTagDetailProvider.notifier)
                          .doSearch(
                            onRefresh: false,
                            query: _kwd,
                            tagId: widget.tag.tagId,
                          );
                    },
                    child: const Icon(Icons.search),
                  ),
                  trailing: _kwd.isEmpty
                      ? [
                          InkWell(
                            onTap: () {
                              addContact(context);
                            },
                            child: const Icon(Icons.add_box_outlined),
                          ),
                        ]
                      : [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _kwd = '';
                                _searchController.text = '';
                              });
                              ref
                                  .read(contactTagDetailProvider.notifier)
                                  .doSearch(
                                    onRefresh: false,
                                    query: _kwd,
                                    tagId: widget.tag.tagId,
                                  );
                            },
                            child: const Icon(Icons.close),
                          ),
                        ],
                  controller: _searchController,
                  searchLabel: t.search,
                  hintText: t.search,
                  onChanged: (query) {
                    setState(() {
                      _kwd = query;
                    });
                    ref
                        .read(contactTagDetailProvider.notifier)
                        .doSearch(
                          onRefresh: false,
                          query: _kwd,
                          tagId: widget.tag.tagId,
                        );
                  },
                  doSearch: (query) {
                    return ref
                        .read(contactTagDetailProvider.notifier)
                        .doSearch(
                          onRefresh: false,
                          query: _kwd,
                          tagId: widget.tag.tagId,
                        );
                  },
                ),
              ),
              detailState.contactList.isEmpty
                  ? const SizedBox.shrink()
                  : Expanded(
                      child: AzListView(
                        data: detailState.contactList,
                        itemCount: detailState.contactList.length,
                        itemBuilder: (BuildContext context, int index) {
                          ContactModel model = detailState.contactList[index];
                          return Slidable(
                            key: ValueKey(model.peerId),
                            groupTag: '0',
                            closeOnScroll: true,
                            endActionPane: ActionPane(
                              extentRatio: 0.25,
                              motion: const StretchMotion(),
                              children: [
                                SlidableAction(
                                  key: ValueKey("delete_$index"),
                                  flex: 1,
                                  backgroundColor: Colors.red,
                                  onPressed: (_) async {
                                    await showDialog<bool>(
                                      context: context,
                                      builder: (context) => SizedBox(
                                        width: MediaQuery.of(
                                          context,
                                        ).size.width,
                                        height: 102,
                                        child: Column(
                                          children: [
                                            Center(
                                              child: TextButton(
                                                onPressed: () async {
                                                  const String scene = 'friend';
                                                  bool res = await ref
                                                      .read(
                                                        contactTagDetailProvider
                                                            .notifier,
                                                      )
                                                      .removeRelation(
                                                        tagId: widget.tag.tagId,
                                                        tagName:
                                                            widget.tag.name,
                                                        objectId: model.peerId,
                                                        scene: scene,
                                                      );
                                                  if (res) {
                                                    await ref
                                                        .read(
                                                          contactTagListProvider
                                                              .notifier,
                                                        )
                                                        .replaceTagSubtitle(
                                                          tag: widget.tag,
                                                          oldName: model.title,
                                                          newName: '',
                                                        );

                                                    final newContactList =
                                                        List<ContactModel>.from(
                                                          detailState
                                                              .contactList,
                                                        );
                                                    final index1 =
                                                        newContactList
                                                            .indexWhere(
                                                              (e) =>
                                                                  e.peerId ==
                                                                  model.peerId,
                                                            );
                                                    if (index1 > -1) {
                                                      newContactList.removeAt(
                                                        index1,
                                                      );
                                                    }
                                                    ref
                                                        .read(
                                                          contactTagDetailProvider
                                                              .notifier,
                                                        )
                                                        .handleList(
                                                          newContactList,
                                                        );

                                                    // DONE(2026-04-04): 更新 refererTime
                                                    ref
                                                        .read(
                                                          contactTagDetailProvider
                                                              .notifier,
                                                        )
                                                        .decrementRefererTime();
                                                    final currentRefererTime = ref
                                                        .read(
                                                          contactTagDetailProvider,
                                                        )
                                                        .refererTime;

                                                    // 更新标签列表中的标签
                                                    UserTagModel
                                                    updatedTag = UserTagModel(
                                                      userId: widget.tag.userId,
                                                      tagId: widget.tag.tagId,
                                                      scene: widget.tag.scene,
                                                      name: widget.tag.name,
                                                      subtitle:
                                                          '${widget.tag.subtitle.replaceFirst('${model.title},', '')},',
                                                      refererTime:
                                                          currentRefererTime,
                                                      updatedAt:
                                                          widget.tag.updatedAt,
                                                      createdAt:
                                                          widget.tag.createdAt,
                                                    );
                                                    ref
                                                        .read(
                                                          contactTagListProvider
                                                              .notifier,
                                                        )
                                                        .updateTag(updatedTag);

                                                    Navigator.pop(
                                                      context,
                                                      true,
                                                    );
                                                    EasyLoading.showSuccess(
                                                      t.tipSuccess,
                                                    );
                                                  } else {
                                                    Navigator.pop(
                                                      context,
                                                      false,
                                                    );
                                                    EasyLoading.showError(
                                                      t.tipFailed,
                                                    );
                                                  }
                                                },
                                                child: Text(
                                                  t.removeContactFromTag,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 16.0,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const HorizontalLine(height: 6),
                                            Center(
                                              child: TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: Text(
                                                  t.buttonCancel,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 16.0,
                                                    fontWeight:
                                                        FontWeight.normal,
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
                            child: _buildChatListItem(
                              context,
                              model,
                              defHeaderBgColor: const Color(0xFFE5E5E5),
                            ),
                          );
                        },
                        physics: const AlwaysScrollableScrollPhysics(),
                        susItemBuilder: (BuildContext context, int index) {
                          ContactModel model = detailState.contactList[index];
                          if ('↑' == model.getSuspensionTag()) {
                            return Container();
                          }
                          return _buildSusItem(
                            context,
                            model.getSuspensionTag(),
                          );
                        },
                        indexBarData: detailState.contactList.isNotEmpty
                            ? ['↑', ...detailState.currIndexBarData]
                            : [],
                        indexBarOptions: IndexBarOptions(
                          needRebuild: true,
                          ignoreDragCancel: true,
                          downTextStyle: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                          downItemDecoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green,
                          ),
                          indexHintWidth: 128 / 2,
                          indexHintHeight: 128 / 2,
                          indexHintDecoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage(
                                AssetsService.getImgPath(
                                  'index_bar_bubble_gray',
                                ),
                              ),
                              fit: BoxFit.contain,
                            ),
                          ),
                          indexHintAlignment: Alignment.centerRight,
                          indexHintChildAlignment: const Alignment(-0.25, 0.0),
                          indexHintOffset: const Offset(-20, 0),
                        ),
                      ),
                    ),
            ],
          ),
          if (detailState.contactList.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.tag.refererTime == 0)
                    NoDataView(text: t.noMembersInCurrentTag),
                  ElevatedButton(
                    onPressed: () async {
                      addContact(context);
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all<Color>(
                        Theme.of(context).colorScheme.surface,
                      ),
                      minimumSize: WidgetStateProperty.all(const Size(60, 40)),
                      visualDensity: VisualDensity.compact,
                      padding: WidgetStateProperty.all(EdgeInsets.zero),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        t.buttonAdd,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 16.0,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 选择好友页面
class SelectFriendPage extends ConsumerStatefulWidget {
  final UserTagModel tag;
  final List<ContactModel> tagContactList;

  const SelectFriendPage({
    super.key,
    required this.tag,
    required this.tagContactList,
  });

  @override
  ConsumerState<SelectFriendPage> createState() => _SelectFriendPageState();
}

class _SelectFriendPageState extends ConsumerState<SelectFriendPage> {
  final int _itemHeight = 60;
  List<ContactModel> contactList = [];
  List<ContactModel> selectedContact = [];
  Set<dynamic> currIndexBarData = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    selectedContact = List<ContactModel>.from(widget.tagContactList);
    // 使用 ContactRepo 直接获取好友列表
    contactList = await ContactRepo().findFriend();
    _handleList(contactList);
    setState(() {});
  }

  void _handleList(List<ContactModel> list) {
    for (int i = 0; i < list.length; i++) {
      String pinyin = PinyinHelper.getPinyinE(list[i].title);
      String tag = pinyin.substring(0, 1).toUpperCase();
      list[i].namePinyin = pinyin;
      if (RegExp("[A-Z]").hasMatch(tag)) {
        list[i].nameIndex = tag;
        currIndexBarData.add(tag);
      } else {
        list[i].nameIndex = "#";
      }
    }
    currIndexBarData.add('#');
    SuspensionUtil.sortListBySuspensionTag(contactList);
    SuspensionUtil.setShowSuspensionStatus(contactList);
  }

  Widget _buildListItem(ContactModel model) {
    // 检查是否在已选列表中
    bool isSelected = widget.tagContactList.any(
      (e) => e.peerId == model.peerId,
    );
    model.selected = isSelected;

    return Column(
      children: [
        SizedBox(
          height: _itemHeight.toDouble(),
          child: InkWell(
            onTap: () {
              setState(() {
                model.selected = !model.selected;
                if (model.selected) {
                  selectedContact.insert(0, model);
                } else {
                  selectedContact.removeWhere((e) => e.peerId == model.peerId);
                }
              });
            },
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    model.selected
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.check_mark_circled,
                    color: model.selected ? Colors.green : Colors.grey,
                  ),
                ),
                Avatar(imgUri: model.avatar, width: 49, height: 49),
                const Space(),
                Expanded(
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(right: 30),
                    height: _itemHeight.toDouble(),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(width: 0.2)),
                    ),
                    child: Text(
                      model.title,
                      style: const TextStyle(fontSize: 14.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建悬浮标签项（A-Z 分组标题）
  Widget _buildSusItem(BuildContext context, String tag) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 32,
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16),
      alignment: Alignment.centerLeft,
      color: isDark ? Colors.grey[800] : Colors.grey[200],
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        title: t.selectFriends,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: const Icon(Icons.close),
          ),
        ),
        rightDMActions: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: RoundedElevatedButton(
              text:
                  t.buttonAdd +
                  (selectedContact.isEmpty
                      ? ""
                      : " (${selectedContact.length})    "),
              highlighted: selectedContact.isNotEmpty,
              onPressed: () async {
                Navigator.of(context).pop();
                const String scene = 'friend';
                bool res = await ref
                    .read(contactTagDetailProvider.notifier)
                    .setObject(
                      scene: scene,
                      tagId: widget.tag.tagId,
                      tagName: widget.tag.name,
                      selectedContact: selectedContact,
                      tagContactList: widget.tagContactList,
                    );
                if (res) {
                  UserTagModel updatedTag = UserTagModel(
                    userId: widget.tag.userId,
                    tagId: widget.tag.tagId,
                    scene: widget.tag.scene,
                    name: widget.tag.name,
                    subtitle: widget.tag.subtitle,
                    refererTime: selectedContact.length,
                    updatedAt: widget.tag.updatedAt,
                    createdAt: widget.tag.createdAt,
                  );
                  ref
                      .read(contactTagListProvider.notifier)
                      .updateTag(updatedTag);
                  EasyLoading.showSuccess(t.tipSuccess);
                } else {
                  EasyLoading.showError(t.tipFailed);
                }
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              // 使用 ContactRepo 直接获取好友列表
              List<ContactModel> contact = await ContactRepo().findFriend();
              if (contact.isNotEmpty) {
                contactList = contact;
                _handleList(contactList);
                setState(() {});
              }
            },
            child: AzListView(
              data: contactList,
              itemCount: contactList.length,
              itemBuilder: (context, i) => _buildListItem(contactList[i]),
              physics: const AlwaysScrollableScrollPhysics(),
              susItemBuilder: (BuildContext context, int index) {
                ContactModel model = contactList[index];
                if ('↑' == model.getSuspensionTag()) {
                  return Container();
                }
                return _buildSusItem(context, model.getSuspensionTag());
              },
              indexBarData: contactList.isNotEmpty
                  ? ['↑', ...currIndexBarData]
                  : [],
              indexBarOptions: IndexBarOptions(
                needRebuild: true,
                ignoreDragCancel: true,
                downTextStyle: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                ),
                downItemDecoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                ),
                indexHintWidth: 128 / 2,
                indexHintHeight: 128 / 2,
                indexHintDecoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(
                      AssetsService.getImgPath('index_bar_bubble_gray'),
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
                indexHintAlignment: Alignment.centerRight,
                indexHintChildAlignment: const Alignment(-0.25, 0.0),
                indexHintOffset: const Offset(-20, 0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
