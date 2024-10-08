import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';

import 'package:imboy/config/enum.dart';
import 'package:imboy/page/contact/people_info/people_info_view.dart';
import 'package:imboy/store/model/new_friend_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:jiffy/jiffy.dart';
import 'package:niku/namespace.dart' as n;

import '../confirm_new_friend/confirm_new_friend_view.dart';
import 'add_friend_view.dart';
import 'new_friend_logic.dart';

// ignore: must_be_immutable
class NewFriendPage extends StatelessWidget {
  final NewFriendLogic logic = Get.put(NewFriendLogic());

  NewFriendPage({super.key});

  /// 加载好友申请数据
  void initData() async {
    logic.items = [].obs;
    logic.items.value = await logic.listNewFriend(UserRepoLocal.to.currentUid);
    logic.update([logic.items]);
  }

  @override
  Widget build(BuildContext context) {
    initData();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'new_friend'.tr,
        rightDMActions: [
          TextButton(
            onPressed: () {
              Get.to(
                () => AddFriendPage(),
                transition: Transition.rightToLeft,
                popGesture: true, // 右滑，返回上一页
              );
            },
            child: Text(
              'add_friend'.tr,
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height,
          color: Theme.of(context).colorScheme.surface,
          child: n.Column([
            n.Padding(
              left: 8,
              top: 10,
              right: 8,
              bottom: 10,
              child: searchBar(
                context,
                hintText: 'hint_login_account'.tr,
                queryTips: 'hint_login_account'.tr,
                searchLabel: 'hint_login_account'.tr,
                doSearch: ((query) async {
                  return logic.userSearch(kwd: query);
                }),
                doBuildResults: logic.doBuildUserSearchResults,
                onTapForItem: (value) {
                  debugPrint("> on search value ${value.toString()}");
                },
                // onTap: () {
                //   isSearch = true;
                //   logic.searchF.requestFocus();
                // },
              ),
            ),
            // Padding(
            //   padding: const EdgeInsets.only(bottom: 20),
            //   child: LabelRow(
            //     headW: const Padding(
            //       padding: EdgeInsets.only(right: 15.0),
            //       child: Icon(
            //         Icons.phone,
            //         color: AppColors.primaryElement,
            //       ),
            //     ),
            // 添加手机联系人
            //     label: 'add_phone_contact'.tr,
            //   ),
            // ),
            // Spacer(),
            Expanded(
              child: SlidableAutoCloseBehavior(
                child: Obx(() => logic.items.isEmpty
                    ? NoDataView(text: 'no_new_friends'.tr)
                    : ListView.builder(
                        itemBuilder: (BuildContext ctx, int i) {
                          NewFriendModel model = logic.items[i];
                          // debugPrint(
                          //     "NewFriendModel model ${model.toJson().toString()}");
                          List<Widget> rightWidget = [];
                          bool fromSelf =
                              model.from == UserRepoLocal.to.currentUid;
                          if (fromSelf) {
                            rightWidget.add(
                              const Icon(Icons.turn_slight_right),
                            );
                          }
                          // model.status 0 待验证  1 已添加  2 已过期
                          if (model.status ==
                              NewFriendStatus.waiting_for_validation.index) {
                            Jiffy dt = Jiffy.parseFromMillisecondsSinceEpoch(
                              model.createdAtLocal,
                            );
                            int diff =
                                Jiffy.now().diff(dt, unit: Unit.day) as int;
                            if (diff > 7) {
                              model.status = NewFriendStatus.expired.index;
                            }
                          }

                          if (fromSelf &&
                              model.status ==
                                  NewFriendStatus
                                      .waiting_for_validation.index) {
                            rightWidget.add(
                              Text('awaiting_verification'.tr),
                            );
                          } else if (model.status ==
                              NewFriendStatus.waiting_for_validation.index) {
                            rightWidget.add(TextButton(
                              onPressed: () {
                                Get.to(
                                  () => ConfirmNewFriendPage(
                                    to: model.to,
                                    from: model.from,
                                    msg: model.msg,
                                    nickname: model.nickname,
                                    payload: model.payload,
                                  ),
                                  transition: Transition.rightToLeft,
                                  popGesture: true, // 右滑，返回上一页
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.only(right: 0),
                                foregroundColor:
                                    Theme.of(context).colorScheme.surface,
                                backgroundColor:
                                    Theme.of(context).colorScheme.onSurface,
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: Text('accept'.tr),
                            ));
                          } else if (model.status ==
                              NewFriendStatus.added.index) {
                            rightWidget.add(
                              Text('added'.tr),
                            );
                          } else if (model.status ==
                              NewFriendStatus.expired.index) {
                            rightWidget.add(
                              Text('expired'.tr),
                            );
                          }
                          return Slidable(
                            // key: ValueKey(model.uk),
                            groupTag: '1',
                            closeOnScroll: true,
                            endActionPane: ActionPane(
                              extentRatio: 0.25,
                              motion: const StretchMotion(),
                              children: [
                                SlidableAction(
                                  key: ValueKey("delete_$i"),
                                  backgroundColor: Colors.red,
                                  onPressed: (_) async {
                                    await logic.delete(model.from, model.to);
                                  },
                                  label: 'button_delete'.tr,
                                  spacing: 1,
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    width: 0.2,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              child: n.ListTile(
                                leading: Avatar(
                                  imgUri: model.avatar!,
                                  width: 56,
                                  height: 56,
                                ),
                                title: Text(model.nickname),
                                subtitle: Text(model.msg),
                                trailing: Container(
                                  width: 80,
                                  alignment: Alignment.centerRight,
                                  child: n.Row(
                                    rightWidget,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                  ),
                                ),
                                onTap: () {
                                  Get.to(
                                    () => PeopleInfoPage(
                                      id: UserRepoLocal.to.currentUid ==
                                              model.to
                                          ? model.from
                                          : model.to,
                                      scene: model.source,
                                    ),
                                    transition: Transition.rightToLeft,
                                    popGesture: true, // 右滑，返回上一页
                                  );
                                },
                              ),
                            ),
                          );
                        },
                        itemCount: logic.items.length,
                      )),
              ),
            ),
          ])
            ..mainAxisSize = MainAxisSize.min,
        ),
      ),
    );
  }
}
