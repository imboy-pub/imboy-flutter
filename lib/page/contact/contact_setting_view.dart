import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/page/chat/chat_logic.dart';
import 'package:imboy/page/chat/widget/select_friend.dart';
import 'package:imboy/page/friend/denylist_logic.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/denylist_model.dart';

import 'package:imboy/store/repository/user_repo_local.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:xid/xid.dart';

import 'contact_setting_logic.dart';
import 'contact_setting_tag_view.dart';

// ignore: must_be_immutable
class ContactSettingPage extends StatelessWidget {
  final String peerId; // 用户ID
  final String peerAccount;
  final String peerAvatar;
  final String peerTitle;
  final String peerNickname;
  final int peerGender;
  final String peerSign;
  final String peerRegion;
  final String peerSource;
  final String peerRemark;
  final String peerTag;

  ContactSettingPage({
    Key? key,
    required this.peerId,
    required this.peerAccount,
    required this.peerAvatar,
    required this.peerNickname,
    required this.peerGender,
    required this.peerTitle,
    required this.peerSign,
    required this.peerRegion,
    required this.peerSource,
    required this.peerRemark,
    required this.peerTag,
  }) : super(key: key);

  final logic = Get.put(ContactSettingLogic());
  RxBool inDenylist = false.obs;

  Future<void> initData() async {
    inDenylist.value = await DenylistLogic.inDenylist(peerId);
  }

  @override
  Widget build(BuildContext context) {
    initData();
    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: PageAppBar(
        title: '资料设置'.tr,
      ),
      body: SingleChildScrollView(
        child: n.Column(
          [
            LabelRow(
              label: '设置备注和标签'.tr,
              isLine: true,
              onPressed: () {
                Get.to(
                  () => ContactSettingTagPage(
                    peerId: peerId,
                    peerAvatar: peerAvatar,
                    peerAccount: peerAccount,
                    peerNickname: peerNickname,
                    peerGender: peerGender,
                    peerTitle: peerTitle,
                    peerSign: peerSign,
                    peerRegion: peerRegion,
                    peerSource: peerSource,
                    peerRemark: peerRemark,
                    peerTag: peerTag.obs,
                  ),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页
                );
              },
            ),
            // LabelRow(
            //   label: '朋友权限'.tr,
            //   onPressed: () {
            //     Get.to(
            //       () => FriendsPermissionsPage(),
            //       transition: Transition.rightToLeft,
            //       popGesture: true, // 右滑，返回上一页
            //     );
            //   },
            // ),
            const Space(),
            LabelRow(
              label: '把他推荐给朋友'.tr,
              // isLine: false,
              isLine: false,
              onPressed: () async {
                Map<String, String> peer = {
                  'peerId': peerId,
                  'avatar': peerAvatar,
                  'title': peerTitle,
                  'nickname': peerNickname,
                };

                ContactModel? c1 = await Navigator.push(
                  context,
                  CupertinoPageRoute(
                    // “右滑返回上一页”功能
                    builder: (_) => SelectFriendPage(
                      peer: peer,
                      peerIsReceiver: true,
                    ),
                  ),
                );
                debugPrint(
                    "handleVisitCardSelection ${c1?.toJson().toString()}");
                if (c1 != null) {
                  Map<String, dynamic> metadata = {
                    'custom_type': 'visit_card',
                    'uid': peerId,
                    'title': peerTitle,
                    'avatar': peerAvatar,
                  };
                  debugPrint("> location metadata: ${metadata.toString()}");
                  final message = types.CustomMessage(
                    author: types.User(
                      id: UserRepoLocal.to.currentUid,
                      firstName: UserRepoLocal.to.current.nickname,
                      imageUrl: UserRepoLocal.to.current.avatar,
                    ),
                    createdAt: DateTimeHelper.currentTimeMillis(),
                    id: Xid().toString(),
                    remoteId: c1.peerId,
                    status: types.Status.sending,
                    metadata: metadata,
                  );
                  final logic2 = Get.put(ChatLogic());
                  await logic2.addMessage(
                    UserRepoLocal.to.currentUid,
                    c1.peerId,
                    c1.avatar,
                    c1.title,
                    'C2C',
                    message,
                  );

                  EasyLoading.showSuccess('发送成功'.tr);
                }
              },
            ),
            const Space(),
            Container(
              color: Colors.white,
              child: Container(
                padding: const EdgeInsets.only(
                  left: 0,
                  top: 0.0,
                  bottom: 0.0,
                  right: 0.0,
                ),
                margin: const EdgeInsets.only(left: 15.0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: AppColors.LineColor, width: 0.2),
                  ),
                ),
                child: Obx(() => SwitchListTile(
                      title: Text('加入黑名单'.tr),
                      // value: false,
                      value: inDenylist.isTrue,
                      contentPadding: const EdgeInsets.only(
                        left: 0,
                        top: 0.0,
                        bottom: 0.0,
                        right: 0.0,
                      ),
                      activeColor: AppColors.primaryElement,
                      onChanged: (val) async {
                        debugPrint("addDenylist val $val, $inDenylist");

                        bool res;
                        if (inDenylist.isTrue) {
                          res = await DenylistLogic().removeDenylist(peerId);
                        } else {
                          DenylistModel model = DenylistModel(
                            deniedUid: peerId,
                            nickname: peerNickname,
                            account: peerAccount,
                            remark: peerRemark,
                            sign: peerSign,
                            source: peerSource,
                            avatar: peerAvatar,
                            region: peerRegion,
                            gender: peerGender,
                            createdAt: DateTimeHelper.currentTimeMillis(),
                          );
                          res = await DenylistLogic().addDenylist(model);
                        }
                        if (res) {
                          inDenylist.value = val;
                        }
                      },
                    )),
              ),
            ),
            // LabelRow(
            //   label: '投诉'.tr,
            //   isLine: false,
            //   onPressed: () {},
            // ),
            // const Space(),
            ButtonRow(
              margin: const EdgeInsets.only(top: 10.0),
              text: '删除',
              isBorder: false,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              onPressed: () {
                Get.bottomSheet(
                  SizedBox(
                    width: Get.width,
                    height: Get.height * 0.25,
                    child: n.Wrap(
                      [
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 10,
                            left: 15,
                            right: 15,
                            bottom: 10,
                          ),
                          child: Text(
                            '将联系人"$peerRemark"删除，同时删除与该联系人的聊天记录'.tr,
                            style: const TextStyle(
                              color: AppColors.MainTextColor,
                              fontSize: 14.0,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Center(
                          child: TextButton(
                            onPressed: () async {
                              bool res = await logic.deleteContact(peerId);
                              if (res) {
                                EasyLoading.showSuccess("操作成功");
                                Get.close(3);
                                Get.to(
                                  () => BottomNavigationPage(),
                                  arguments: {'index': 1},
                                  transition: Transition.rightToLeft,
                                  popGesture: true, // 右滑，返回上一页
                                );
                              }
                            },
                            child: Text(
                              '删除联系人'.tr,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 16.0,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: Get.width,
                          height: 6,
                          color: AppColors.AppBarColor,
                        ),
                        Center(
                          child: TextButton(
                            onPressed: () => Get.back(),
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
                        ),
                      ],
                    ),
                  ),
                  // backgroundColor: Colors.black12,
                  backgroundColor: Colors.white,
                  //改变shape这里即可
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20.0),
                      topRight: Radius.circular(20.0),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
