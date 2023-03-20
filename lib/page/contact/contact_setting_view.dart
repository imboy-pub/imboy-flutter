import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';
import 'package:imboy/page/friend_circle/friend_circle_view.dart';
import 'package:imboy/store/provider/contact_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:niku/namespace.dart' as n;

// ignore: must_be_immutable
class ContactSettingPage extends StatelessWidget {
  final String id; // 用户ID
  final String remark;

  ContactSettingPage({
    Key? key,
    required this.id,
    required this.remark,
  }) : super(key: key);

  final logic = Get.put(ContactSettingLogic());

  Future<void> initData() async {}

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
                //
              },
            ),
            LabelRow(
              label: '朋友权限'.tr,
              onPressed: () => EasyLoading.showToast('敬请期待'),
            ),
            const Space(),
            LabelRow(
              label: '把他推荐给朋友'.tr,
              isLine: false,
              onPressed: () => Get.to(
                const FriendCirclePage(),
                transition: Transition.rightToLeft,
                popGesture: true, // 右滑，返回上一页
              ),
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
                child: SwitchListTile(
                  title: Text('加入黑名单'.tr),
                  value: false,
                  contentPadding: const EdgeInsets.only(
                    left: 0,
                    top: 0.0,
                    bottom: 0.0,
                    right: 0.0,
                  ),
                  activeColor: AppColors.primaryElement,
                  onChanged: (val) {},
                ),
              ),
            ),
            LabelRow(
              label: '投诉'.tr,
              isLine: false,
              onPressed: () {},
            ),
            const Space(),
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
                    child: Wrap(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 10,
                            left: 15,
                            right: 15,
                            bottom: 10,
                          ),
                          child: ExtendedText(
                            '将联系人"$remark"删除，同时删除与该联系人的聊天记录'.tr,
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
                              bool res = await logic.deleteContact(id);
                              if (res) {
                                EasyLoading.showSuccess("操作成功");
                                Get.close(3);
                                Get.to(
                                  BottomNavigationPage(),
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

class ContactSettingLogic extends GetxController {
  /// 将联系人"$remark"删除，同时删除与该联系人的聊天记录
  Future<bool> deleteContact(String uid) async {
    bool res = await (ContactProvider()).deleteContact(uid);
    if (res) {
      await MessageRepo().deleteForUid(uid);
      await ConversationRepo().delete(uid);
      await NewFriendRepo().deleteForUid(uid);
      await ContactRepo().deleteForUid(uid);
    }
    return res;
  }
}
