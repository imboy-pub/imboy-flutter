import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/enum.dart';
import 'package:imboy/page/single/people_info.dart';
import 'package:imboy/store/model/new_friend_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:jiffy/jiffy.dart';
import 'package:niku/namespace.dart' as n;

import 'add_friend_view.dart';
import 'confirm_new_friend_view.dart';
import 'new_friend_logic.dart';

// ignore: must_be_immutable
class NewFriendPage extends StatelessWidget {
  final NewFriendLogic logic = Get.find();

  bool isSearch = false;
  bool showBtn = false;
  bool isResult = false;

  NewFriendPage({Key? key}) : super(key: key);

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
      backgroundColor: AppColors.ChatBg,
      appBar: PageAppBar(
        title: '新的朋友'.tr,
        rightDMActions: [
          TextButton(
            onPressed: () {
              Get.to(()=>
                AddFriendPage(),
                transition: Transition.rightToLeft,
                popGesture: true, // 右滑，返回上一页
              );
            },
            child: Text(
              '添加朋友'.tr,
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height,
          color: AppColors.ChatBg,
          child: n.Column(
            [
              n.Padding(
                left: 8,
                top: 10,
                right: 8,
                bottom: 10,
                child: SearchBar(
                  hintText: '微信号/手机号',
                  // isBorder: true,
                  onTap: () {
                    isSearch = true;
                    logic.searchF.requestFocus();
                  },
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
              //     label: '添加手机联系人'.tr,
              //   ),
              // ),
              // Spacer(),
              Expanded(
                child: SlidableAutoCloseBehavior(child: Obx(() {
                  return logic.items.isEmpty
                      ? NoDataView(text: '没有新的好友'.tr)
                      : ListView.builder(
                          itemBuilder: (BuildContext context, int index) {
                            NewFriendModel model = logic.items[index];
                            debugPrint(
                                "NewFriendModel model ${model.toJson().toString()}");
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
                                model.createTime,
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
                                Text('等待验证'.tr),
                              );
                            } else if (model.status ==
                                NewFriendStatus.waiting_for_validation.index) {
                              rightWidget.add(TextButton(
                                onPressed: () {
                                  Get.to(()=>
                                    ConfirmNewFriendPage(
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
                                  foregroundColor: AppColors.primaryElement,
                                  backgroundColor:
                                      AppColors.ChatInputBackgroundColor,
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                child: Text('接受'.tr),
                              ));
                            } else if (model.status ==
                                NewFriendStatus.added.index) {
                              rightWidget.add(
                                Text('已添加'.tr),
                              );
                            } else if (model.status ==
                                NewFriendStatus.expired.index) {
                              rightWidget.add(
                                Text('已过期'.tr),
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
                                    key: ValueKey("delete_$index"),
                                    backgroundColor: Colors.red,
                                    onPressed: (_) async {
                                      await logic.delete(model.from, model.to);
                                    },
                                    label: "删除",
                                    spacing: 1,
                                  ),
                                ],
                              ),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
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
                                    Get.to(()=>
                                      PeopleInfoPage(
                                        id: UserRepoLocal.to.currentUid ==
                                                model.to
                                            ? model.from
                                            : model.to,
                                        sence: model.source,
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
                        );
                })),
              ),
            ],
            mainAxisSize: MainAxisSize.min,
          ),
        ),
      ),
    );
  }
}
