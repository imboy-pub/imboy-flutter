import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/theme.dart';

import 'package:imboy/page/contact/contact/contact_logic.dart';
import 'package:imboy/page/user_tag/contact_tag_list/contact_tag_list_logic.dart';
import 'package:imboy/page/user_tag/user_tag_save/user_tag_save_view.dart';
import 'package:imboy/service/assets.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/user_tag_model.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:niku/namespace.dart' as n;

import 'contact_tag_detail_logic.dart';

// ignore: must_be_immutable
class ContactTagDetailPage extends StatelessWidget {
  UserTagModel tag;

  // ignore: prefer_const_constructors_in_immutables
  ContactTagDetailPage({super.key, required this.tag});

  final logic = Get.put(ContactTagDetailLogic());
  final state = Get.find<ContactTagDetailLogic>().state;

  void loadData() async {
    state.tagName.value = tag.name;
    state.refererTime.value = tag.refererTime;

    // 加载联系人列表
    if (tag.refererTime > 0) {
      var list = await logic.pageRelation(
        false,
        tagId: tag.tagId,
        page: state.page,
        size: state.size,
        kwd: state.kwd.value,
      );
      logic.handleList(list);
    }
  }

  @override
  Widget build(BuildContext context) {
    loadData();
    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        titleWidget: Obx(() => Text(
              '${state.tagName} (${state.refererTime})',
              style: AppStyle.navAppBarTitleStyle,
            )),
        rightDMActions: [
          InkWell(
            onTap: () {
              Get.bottomSheet(
                backgroundColor: Get.isDarkMode
                    ? const Color.fromRGBO(80, 80, 80, 1)
                    : const Color.fromRGBO(240, 240, 240, 1),
                SizedBox(
                  width: Get.width,
                  height: 172,
                  child: n.Wrap([
                    Center(
                      child: TextButton(
                        child: Text(
                          'change_tag_name'.tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            // color: Colors.white,
                            fontSize: 16.0,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        onPressed: () async {
                          Get.bottomSheet(
                            backgroundColor: Get.isDarkMode
                                ? const Color.fromRGBO(80, 80, 80, 1)
                                : const Color.fromRGBO(240, 240, 240, 1),
                            n.Padding(
                              // top: 80,
                              child: UserTagSavePage(tag: tag, scene: 'friend'),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          Get.bottomSheet(
                            SizedBox(
                              width: Get.width,
                              height: 172,
                              child: n.Wrap([
                                Center(
                                  child: n.Padding(
                                    top: 16,
                                    bottom: 16,
                                    child: Text(
                                      'delete_tag_tips'.tr,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        // color: Colors.white,
                                        fontSize: 16.0,
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
                                      bool res =
                                          await Get.find<ContactTagListLogic>()
                                              .deleteTag(
                                        tagId: tag.tagId,
                                        tagName: tag.name,
                                        scene: scene,
                                      );
                                      if (res) {
                                        Get.find<ContactTagListLogic>()
                                            .replaceObjectTag(
                                                scene: scene,
                                                oldName: tag.name,
                                                newName: '');

                                        final index =
                                            Get.find<ContactTagListLogic>()
                                                .state
                                                .items
                                                .indexWhere((e) =>
                                                    e.tagId == tag.tagId);
                                        if (index > -1) {
                                          Get.find<ContactTagListLogic>()
                                              .state
                                              .items
                                              .removeAt(index);
                                        }
                                        Get.closeAllBottomSheets();
                                        Get.back();
                                        EasyLoading.showSuccess(
                                            'tip_success'.tr);
                                      } else {
                                        EasyLoading.showError('tip_failed'.tr);
                                      }
                                    },
                                    child: Text(
                                      'button_delete'.tr,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                                const HorizontalLine(height: 6),
                                Center(
                                  child: TextButton(
                                    onPressed: () => Get.close(),
                                    child: Text(
                                      'button_cancel'.tr,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        // color: Colors.white,
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                )
                              ]),
                            ),
                            backgroundColor: Get.isDarkMode
                                ? const Color.fromRGBO(80, 80, 80, 1)
                                : const Color.fromRGBO(240, 240, 240, 1),
                            //改变shape这里即可
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(20.0),
                                topRight: Radius.circular(20.0),
                              ),
                            ),
                          );
                        },
                        child: Text(
                          'button_delete'.tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 16.0,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    const HorizontalLine(height: 6),
                    Center(
                      child: TextButton(
                        onPressed: () => Get.close(),
                        child: Text(
                          'button_cancel'.tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            // color: Colors.white,
                            fontSize: 16.0,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    )
                  ]),
                ),
                //改变shape这里即可
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    topRight: Radius.circular(20.0),
                  ),
                ),
              );
            },
            // 三点更多 more icon
            child: n.Padding(
              left: 10,
              right: 10,
              top: 10,
              bottom: 10,
              child: Icon(
                Icons.more_horiz,
                color: Theme.of(context).colorScheme.onPrimary,
                // size: 40,
              ),
            ),
          )
        ],
      ),
      body: Obx(
        () => n.Stack([
          n.Column([
            n.Padding(
              left: 8,
              top: 2,
              right: 8,
              bottom: 2,
              child: searchBar(
                context,
                leading: state.searchLeading?.value ??
                    InkWell(
                      onTap: () {
                        logic.doSearch(
                            onRefresh: false,
                            query: state.kwd.value,
                            tagId: tag.tagId);
                      },
                      child: const Icon(Icons.search),
                    ),
                trailing: state.kwd.isEmpty
                    ? [
                        InkWell(
                          onTap: () {
                            addContact(context);
                          },
                          child: const Icon(Icons.add_box_outlined),
                        )
                      ]
                    : [
                        InkWell(
                          onTap: () {
                            state.kwd.value = '';
                            state.searchController.text = '';
                            logic.doSearch(
                                onRefresh: false,
                                query: state.kwd.value,
                                tagId: tag.tagId);
                          },
                          child: const Icon(Icons.close),
                        )
                      ],
                controller: state.searchController,
                searchLabel: 'search'.tr,
                hintText: 'search'.tr,
                // queryTips: 'favorite_group_tags_etc'.tr,
                onChanged: ((query) {
                  state.kwd.value = query;
                  // debugPrint("contact_tag_view_onChanged ${query.toString()}");
                  logic.doSearch(
                      onRefresh: false,
                      query: state.kwd.value,
                      tagId: tag.tagId);
                }),
                doSearch: (query) {
                  return logic.doSearch(
                      onRefresh: false,
                      query: state.kwd.value,
                      tagId: tag.tagId);
                },
              ),
            ),
            state.contactList.isEmpty
                ? const SizedBox.shrink()
                : Expanded(
                    // flex: 1,
                    child: AzListView(
                      data: state.contactList,
                      itemCount: state.contactList.length,
                      itemBuilder: (BuildContext context, int index) {
                        ContactModel model = state.contactList[index];
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
                                // foregroundColor: Colors.white,
                                onPressed: (_) async {
                                  Get.bottomSheet(
                                    SizedBox(
                                      width: Get.width,
                                      height: 102,
                                      child: n.Wrap(
                                        [
                                          Center(
                                            child: TextButton(
                                              onPressed: () async {
                                                const String scene = 'friend';
                                                bool res =
                                                    await logic.removeRelation(
                                                        tagId: tag.tagId,
                                                        tagName: tag.name,
                                                        objectId: model.peerId,
                                                        scene: scene);
                                                if (res) {
                                                  Get.find<
                                                          ContactTagListLogic>()
                                                      .replaceTagSubtitle(
                                                          tag: tag,
                                                          oldName: model.title,
                                                          newName: '');
                                                  final index1 = state
                                                      .contactList
                                                      .indexWhere((e) =>
                                                          e.peerId ==
                                                          model.peerId);
                                                  if (index1 > -1) {
                                                    state.contactList
                                                        .removeAt(index1);
                                                  }
                                                  // ignore: invalid_use_of_protected_member
                                                  logic.handleList(
                                                      state.contactList);
                                                  if (state.refererTime.value >
                                                      0) {
                                                    state.refererTime.value -=
                                                        1;
                                                  }

                                                  final index2 = Get.find<
                                                          ContactTagListLogic>()
                                                      .state
                                                      .items
                                                      .indexWhere((e) =>
                                                          e.tagId == tag.tagId);
                                                  if (index2 > -1) {
                                                    String old =
                                                        '${tag.subtitle},';
                                                    tag.refererTime =
                                                        state.refererTime.value;
                                                    tag.subtitle =
                                                        old.replaceFirst(
                                                            '${model.title},',
                                                            '');
                                                    Get.find<
                                                            ContactTagListLogic>()
                                                        .state
                                                        .items
                                                        .replaceRange(index2,
                                                            index2 + 1, [tag]);
                                                  }
                                                  Get.back(times: 1);
                                                  EasyLoading.showSuccess(
                                                      'tip_success'.tr);
                                                } else {
                                                  EasyLoading.showError(
                                                      'tip_failed'.tr);
                                                }
                                              },
                                              child: Text(
                                                'remove_contact_from_tag'.tr,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 16.0,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const HorizontalLine(height: 6),
                                          Center(
                                            child: TextButton(
                                              onPressed: () => Get.close(),
                                              child: Text(
                                                'button_cancel'.tr,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  // color: Colors.white,
                                                  fontSize: 16.0,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                    backgroundColor: Get.isDarkMode
                                        ? const Color.fromRGBO(80, 80, 80, 1)
                                        : const Color.fromRGBO(
                                            240, 240, 240, 1),
                                    //改变shape这里即可
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(20.0),
                                        topRight: Radius.circular(20.0),
                                      ),
                                    ),
                                  );
                                },
                                // icon: Icons.delete_forever_sharp,
                                label: 'button_delete'.tr,
                                spacing: 1,
                              ),
                            ],
                          ),
                          child: Get.find<ContactLogic>().getChatListItem(
                            context,
                            model,
                            defHeaderBgColor: const Color(0xFFE5E5E5),
                          ),
                        );
                      },
                      // 解决联系人数据量少的情况下无法刷新的问题
                      // 在listview的physice属性赋值new AlwaysScrollableScrollPhysics()，保持listview任何情况都能滚动
                      physics: const AlwaysScrollableScrollPhysics(),
                      susItemBuilder: (BuildContext context, int index) {
                        ContactModel model = state.contactList[index];
                        if ('↑' == model.getSuspensionTag()) {
                          return Container();
                        }
                        return Get.find<ContactLogic>()
                            .getSusItem(context, model.getSuspensionTag());
                      },
                      indexBarData: state.contactList.isNotEmpty
                          ? ['↑', ...state.currIndexBarData]
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
                                  'ic_index_bar_bubble_gray'),
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
          ]),
          state.contactList.isEmpty
              ? n.Column([
                  if (tag.refererTime == 0)
                    n.Row([NoDataView(text: 'no_members_in_current_tag'.tr)])
                      // 内容居中
                      ..mainAxisAlignment = MainAxisAlignment.center,
                  n.Row([
                    ElevatedButton(
                      onPressed: () async {
                        addContact(context);
                      },
                      // ignore: sort_child_properties_last
                      child: n.Padding(
                        left: 40,
                        right: 40,
                        child: Text(
                          'button_add'.tr,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 16.0,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all<Color>(
                          Theme.of(context).colorScheme.surface,
                        ),
                        minimumSize:
                            WidgetStateProperty.all(const Size(60, 40)),
                        visualDensity: VisualDensity.compact,
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                      ),
                    )
                  ])
                    // 内容居中
                    ..mainAxisAlignment = MainAxisAlignment.center,
                ],
                  // 垂直居中
                  mainAxisAlignment: MainAxisAlignment.center)
              : const SizedBox.shrink(),
        ]),
      ),
    );
  }

  Future<void> addContact(BuildContext ctx) async {
    // ContactModel? c1 = await Navigator.push(
    await Navigator.push(
      ctx,
      CupertinoPageRoute(
        // “右滑返回上一页”功能
        builder: (_) => SelectFriendPage(
          tag: tag,
          tagContactList: state.contactList,
        ),
      ),
    );
  }
}

// ignore: must_be_immutable
class SelectFriendPage extends StatelessWidget {
  UserTagModel tag;
  final List<ContactModel> tagContactList;

  SelectFriendPage({
    super.key,
    required this.tag,
    required this.tagContactList,
  });

  final int _itemHeight = 60;

  RxList<ContactModel> contactList = RxList<ContactModel>();

  RxList<ContactModel> selectedContact = RxList<ContactModel>();

  // ignore: prefer_collection_literals
  RxSet currIndexBarData = Set().obs;

  void loadData() async {
    // deep copy
    selectedContact.value = List<ContactModel>.from(tagContactList);

    // 加载联系人列表
    contactList.value = await Get.find<ContactLogic>().listFriend(false);
    debugPrint(
        "_handleVisitCardSelection contactList ${contactList.toString()}");
    _handleList(contactList);
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

    // A-Z sort.
    SuspensionUtil.sortListBySuspensionTag(contactList);

    // show sus tag.
    SuspensionUtil.setShowSuspensionStatus(contactList);
  }

  Widget _buildListItem(ContactModel model) {
    for (var e in tagContactList) {
      if (model.peerId == e.peerId) {
        model.selected.value = true;
      }
    }
    return n.Column([
      Obx(() => SizedBox(
            height: _itemHeight.toDouble(),
            child: InkWell(
              onTap: () {
                // iPrint("model.selected ${model.selected}");
                model.selected.value = !model.selected.value;
                // iPrint("model.selected ${model.selected.isTrue}");
                if (model.selected.isTrue) {
                  selectedContact.insert(0, model);
                } else {
                  selectedContact.removeWhere((e) => e.peerId == model.peerId);
                }
                // iPrint("model.selected ${selectedContact.length}");
              },
              child: n.Row([
                n.Padding(
                  left: 8,
                  right: 8,
                  child: Icon(
                    model.selected.isTrue
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.check_mark_circled,
                    color: model.selected.isTrue ? Colors.green : Colors.grey,
                  ),
                ),
                Avatar(
                  imgUri: model.avatar,
                  width: 49,
                  height: 49,
                ),
                const Space(),
                Expanded(
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(right: 30),
                    height: _itemHeight.toDouble(),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          // color: AppColors.LineColor,
                          width: 0.2,
                        ),
                      ),
                    ),
                    child: Text(
                      model.title,
                      style: const TextStyle(fontSize: 14.0),
                    ),
                  ),
                ),
              ]),
            ),
          )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    loadData();
    return Scaffold(
      appBar: NavAppBar(
        title: 'select_friends'.tr,
        leading: n.Padding(
          child: InkWell(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: const Icon(Icons.close),
          ),
        ),
        rightDMActions: <Widget>[
          Obx(
            () => n.Padding(
              left: 8,
              top: 8,
              right: 8,
              bottom: 8,
              child: RoundedElevatedButton(
              text: 'button_add'.tr +
                      (selectedContact.isEmpty
                          ? ""
                          : " (${selectedContact.length})    "),
              highlighted: selectedContact.isNotEmpty,
                onPressed: () async {
                  Navigator.of(context).pop();
                  const String scene = 'friend';
                  bool res = await Get.find<ContactTagDetailLogic>().setObject(
                    scene: scene,
                    tagId: tag.tagId,
                    tagName: tag.name,
                    selectedContact: selectedContact,
                    tagContactList: tagContactList,
                  );
                  if (res) {
                    tag.refererTime = selectedContact.length;
                    Get.find<ContactTagListLogic>().updateTag(tag);
                    Get.find<ContactTagDetailLogic>().state.contactList.value =
                        selectedContact;
                    Get.find<ContactTagDetailLogic>().state.refererTime.value =
                        selectedContact.length;
                    EasyLoading.showSuccess('tip_success'.tr);
                  } else {
                    EasyLoading.showError('tip_failed'.tr);
                  }
                }),
            ),
          )
        ],
      ),
      body: Obx(
        () => n.Stack([
          RefreshIndicator(
            onRefresh: () async {
              debugPrint(">>> contact onRefresh");
              List<ContactModel> contact =
                  await Get.find<ContactLogic>().listFriend(true);
              if (contact.isNotEmpty) {
                contactList.value = contact;
                // contactIsEmpty.value = contactList.isEmpty;
                _handleList(contactList);
              }
            },
            child: AzListView(
              data: contactList,
              itemCount: contactList.length,
              itemBuilder: (context, i) => _buildListItem(contactList[i]),
              // 解决联系人数据量少的情况下无法刷新的问题
              // 在listview的physice属性赋值new AlwaysScrollableScrollPhysics()，保持listview任何情况都能滚动
              physics: const AlwaysScrollableScrollPhysics(),
              susItemBuilder: (BuildContext context, int index) {
                ContactModel model = contactList[index];
                if ('↑' == model.getSuspensionTag()) {
                  return Container();
                }

                return Get.find<ContactLogic>()
                    .getSusItem(context, model.getSuspensionTag());
              },
              // indexBarData: const ['↑', ...kIndexBarData],
              indexBarData:
                  contactList.isNotEmpty ? ['↑', ...currIndexBarData] : [],
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
                      AssetsService.getImgPath('ic_index_bar_bubble_gray'),
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
                indexHintAlignment: Alignment.centerRight,
                indexHintChildAlignment: const Alignment(-0.25, 0.0),
                indexHintOffset: const Offset(-20, 0),
              ),
            ),
          )
        ]),
      ),
    );
  }
}
