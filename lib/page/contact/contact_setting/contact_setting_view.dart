import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/component/ui/line.dart';

import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/page/chat/widget/select_friend.dart';
import 'package:imboy/page/mine/denylist/denylist_logic.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/denylist_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;
import 'package:xid/xid.dart';

import '../contact_setting_tag/contact_setting_tag_view.dart';
import 'contact_setting_logic.dart';

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
  String peerRemark;
  final String peerTag;

  ContactSettingPage({
    super.key,
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
  });

  final logic = Get.put(ContactSettingLogic());
  RxBool inDenylist = false.obs;

  Future<void> initData() async {
    inDenylist.value = await DenylistLogic.inDenylist(peerId);
  }

  @override
  Widget build(BuildContext context) {
    initData();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'profile_settings'.tr,
      ),
      body: SingleChildScrollView(
        child: n.Column([
          LabelRow(
            title: 'set_param'.trArgs(['remarks_tags'.tr]),
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
              )?.then((value) {
                if (value != null) {
                  peerRemark = value.toString();
                }
              });
            },
          ),
          // LabelRow(
          //   label: 'friend_permissions'.tr,
          //   onPressed: () {
          //     Get.to(
          //       () => FriendsPermissionsPage(),
          //       transition: Transition.rightToLeft,
          //       popGesture: true, // 右滑，返回上一页
          //     );
          //   },
          // ),
          n.Padding(
            left: 16,
            right: 16,
            child: HorizontalLine(height: Get.isDarkMode ? 0.5 : 1.0),
          ),
          LabelRow(
            title: 'recommend_to_friend'.tr,
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
              debugPrint("handleVisitCardSelection ${c1?.toJson().toString()}");
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
                  createdAt: DateTimeHelper.utc(),
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

                EasyLoading.showSuccess('tip_success'.tr);
              }
            },
          ),

          n.Padding(
            left: 16,
            right: 16,
            child: HorizontalLine(height: Get.isDarkMode ? 0.5 : 1.0),
          ),

          LabelRow(
            title: 'add_to_denylist'.tr,
            isLine: true,
            isRight: false,
            trailing: SizedBox(
              height: 32.0,
              child: Obx(
                () => CupertinoSwitch(
                  value: inDenylist.isTrue,
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
                        createdAt: DateTimeHelper.utc(),
                      );
                      res = await DenylistLogic().addDenylist(model);
                    }
                    if (res) {
                      inDenylist.value = val;
                    }
                  },
                ),
              ),
            ),
          ),
          // LabelRow(
          //   label: 'complaint'.tr,
          //   isLine: false,
          //   onPressed: () {},
          // ),
          n.Padding(
            left: 16,
            right: 16,
            child: HorizontalLine(height: Get.isDarkMode ? 0.5 : 1.0),
          ),
          ButtonRow(
            margin: const EdgeInsets.only(top: 10.0),
            text: '删除',
            isBorder: false,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            onPressed: () {
              Get.bottomSheet(
                backgroundColor: Get.isDarkMode
                    ? const Color.fromRGBO(80, 80, 80, 1)
                    : const Color.fromRGBO(240, 240, 240, 1),
                SizedBox(
                  width: Get.width,
                  height: Get.height * 0.25,
                  child: n.Wrap([
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 10,
                        left: 15,
                        right: 15,
                        bottom: 10,
                      ),
                      child: Text(
                        'tip_delete_contact'.trArgs([peerRemark]),
                        style: const TextStyle(
                          // color: AppColors.MainTextColor,
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
                            Get.back(times: 3);
                            Get.to(
                              () => BottomNavigationPage(),
                              arguments: {'index': 1},
                              transition: Transition.rightToLeft,
                              popGesture: true, // 右滑，返回上一页
                            );
                          }
                        },
                        child: Text(
                          'delete_contact'.tr,
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
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () => Get.close(),
                        child: Text(
                          'button_cancel'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 16.0,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                // backgroundColor: Colors.black12,
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
        ]),
      ),
    );
  }
}
