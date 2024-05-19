import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_view.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/config/const.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/contact/people_nearby/people_nearby_view.dart';
import 'package:imboy/page/contact/recently_registered_user/recently_registered_user_view.dart';
import 'package:imboy/page/scanner/scanner_view.dart';
import 'package:imboy/page/qrcode/qrcode_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../new_friend/new_friend_logic.dart';
import 'add_friend_logic.dart';

// ignore: must_be_immutable
class AddFriendPage extends StatelessWidget {
  bool isSearch = false;
  final AddFriendLogic logic = Get.put(AddFriendLogic());

  AddFriendPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: NavAppBar(
        title: 'add_friend'.tr,
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        child: Container(
            width: Get.width,
            height: Get.height,
            color: Theme.of(context).colorScheme.background,
            child: n.Column(
              [
                n.Padding(
                  left: 8,
                  top: 10,
                  right: 8,
                  bottom: 10,
                  child: searchBar(
                    context,
                    hintText: '微信号/手机号',
                    doSearch: ((query) async {
                      // debugPrint(
                      //     "> on search doSearch ${query.toString()}");
                      // return logic.search(kwd: query);
                      return [];
                    }),
                    onTapForItem: (value) {
                      isSearch = true;
                      Get.find<NewFriendLogic>().searchF.requestFocus();
                    },
                  ),
                ),
                n.Padding(
                  child: n.Row(
                    [
                      Text("${'my_account'.tr}："),
                      Text(UserRepoLocal.to.current.account),
                      const Space(),
                      InkWell(
                        onTap: () {
                          Get.to(
                            () => UserQrCodePage(),
                            transition: Transition.rightToLeft,
                            popGesture: true, // 右滑，返回上一页
                          );
                        },
                        child: const Icon(
                          Icons.qr_code_2,
                          color: Colors.teal,
                        ),
                      )
                    ],
                    mainAxisAlignment: MainAxisAlignment.center,
                  ),
                ),
                const Space(),
                Container(
                  color: Theme.of(context).colorScheme.background,
                  child: n.Column([
                    n.ListTile(
                      leading: const Icon(
                        Icons.explore_rounded,
                        color: Colors.lightBlue,
                        size: 40,
                      ),
                      title: Transform(
                        transform: Matrix4.translationValues(0, 0.0, 0.0),
                        child: Text('people_nearby'.tr),
                      ),
                      subtitle: Text(
                        'nearby_people_tips'.tr,
                        style: const TextStyle(
                          // color: AppColors.TipColor,
                          fontSize: 12,
                        ),
                      ),
                      dense: true,
                      trailing: navigateNextIcon,
                      onTap: () {
                        Get.to(
                          () => PeopleNearbyPage(),
                          transition: Transition.rightToLeft,
                          popGesture: true, // 右滑，返回上一页
                        );
                      },
                    ),
                    n.Padding(
                      left: 72,
                      child: const Divider(),
                    ),
                    n.ListTile(
                      leading: const Icon(
                        Icons.group,
                        color: Colors.purple,
                        size: 40,
                      ),
                      title: Transform(
                        transform: Matrix4.translationValues(0, 0.0, 0.0),
                        child: Text('create_group_f2f'.tr),
                      ),
                      subtitle: Text(
                        'enter_same_group'.tr,
                        style: const TextStyle(
                          // color: AppColors.TipColor,
                          fontSize: 12,
                        ),
                      ),
                      trailing: navigateNextIcon,
                      onTap: () {
                        Get.to(
                          () => FaceToFacePage(),
                          transition: Transition.rightToLeft,
                          popGesture: true, // 右滑，返回上一页
                        );
                      },
                    ),
                    n.Padding(
                      left: 72,
                      child: const Divider(),
                    ),
                    n.ListTile(
                      leading: const Icon(
                        Icons.qr_code_scanner_outlined,
                        color: Colors.blue,
                        size: 40,
                      ),
                      title: Transform(
                        transform: Matrix4.translationValues(0, 0.0, 0.0),
                        child: Text('scan_qr_code'.tr),
                      ),
                      subtitle: Text(
                        'scan_qr_code_business_card'.tr,
                        style: const TextStyle(
                          // color: AppColors.TipColor,
                          fontSize: 12,
                        ),
                      ),
                      trailing: navigateNextIcon,
                      onTap: () {
                        Get.to(
                          () => const ScannerPage(),
                          transition: Transition.rightToLeft,
                          popGesture: true, // 右滑，返回上一页
                        );
                      },
                    ),
                    n.Padding(
                      left: 72,
                      child: const Divider(),
                    ),
                    n.ListTile(
                      leading: const Icon(
                        Icons.person,
                        color: Colors.lightGreen,
                        size: 40,
                      ),
                      title: Transform(
                        transform: Matrix4.translationValues(0, 0.0, 0.0),
                        child: Text('newly_registered_people'.tr),
                      ),
                      subtitle: Text(
                        // 最近新注册的并且允许被搜索到的朋友
                        'allowed_be_searched'.tr,
                        style: const TextStyle(
                          // color: AppColors.TipColor,
                          fontSize: 12,
                        ),
                      ),
                      trailing: navigateNextIcon,
                      onTap: () {
                        Get.to(
                          () => RecentlyRegisteredUserPage(),
                          transition: Transition.rightToLeft,
                          popGesture: true, // 右滑，返回上一页
                        );
                      },
                    ),
                  ]),
                )
              ],
              mainAxisAlignment: MainAxisAlignment.start,
            )),
      ),
    );
  }
}
