import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/page/live_room/live_room_list/live_room_list_view.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/mine/setting/setting_view.dart';
import 'package:imboy/page/personal_info/personal_info/personal_info_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../denylist/denylist_view.dart';
import '../user_collect/user_collect_view.dart';
import '../user_device/user_device_view.dart';
import 'mine_logic.dart';

// ignore: must_be_immutable
class MinePage extends StatelessWidget {
  final MineLogic logic = Get.put(MineLogic());

  MinePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.AppBarColor,
      child: SingleChildScrollView(
        child: n.Column([
          GetBuilder<UserRepoLocal>(
            builder: (c) => InkWell(
              onTap: () {
                Get.to(
                  () => const PersonalInfoPage(),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页
                );
              },
              child: Container(
                color: Colors.white,
                child: n.Padding(
                  child: Container(
                    color: Colors.white,
                    // 显示地区需要360的高度
                    height: c.current.region.isEmpty ? 320 : 360,
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      right: 12.0,
                      top: 32.0,
                    ),
                    margin: const EdgeInsets.only(
                      bottom: 10,
                    ),
                    child: n.Column([
                      // avatar
                      n.Row([
                        Container(
                          margin: const EdgeInsets.only(top: 32.0),
                          // color: Colors.red,
                          width: 180.0,
                          height: 180.0,
                          child: ClipRRect(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(100.0)),
                            child: InkWell(
                              onTap: () {
                                if (c.current.avatar.isEmpty) {
                                  EasyLoading.showInfo('请进入【个人信息页面】设置头像'.tr);
                                } else {
                                  zoomInPhotoView(c.current.avatar);
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.rectangle,
                                  borderRadius: BorderRadius.circular(80.0),
                                  // color: defHeaderBgColor,
                                  image: dynamicAvatar(c.current.avatar),
                                ),
                              ),
                            ),
                          ),
                        )
                      ])
                        ..mainAxisAlignment = MainAxisAlignment.center,
                      n.Row([
                        Container(
                          margin: const EdgeInsets.only(left: 0.0, top: 10.0),
                          width: 200.0,
                          child: n.Column([
                            Text(
                              c.current.nickname,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 18.0,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.left,
                            ),
                            n.Padding(
                              top: 8.0,
                              bottom: 8.0,
                              child: Text(
                                // '',
                                '账号：'.tr + c.current.account,
                                style: const TextStyle(
                                  color: AppColors.MainTextColor,
                                ),
                              ),
                            ),
                            strNoEmpty(c.current.region)
                                ? Text(
                                    '地区：'.tr + c.current.region,
                                    style: const TextStyle(
                                        color: AppColors.MainTextColor),
                                  )
                                : const SizedBox.shrink(),
                          ])
                            ..mainAxisSize = MainAxisSize.min
                            ..mainAxisAlignment = MainAxisAlignment.start
                            ..crossAxisAlignment = CrossAxisAlignment.start,
                        ),
                        const Spacer(),
                        Container(
                          width: 18.0,
                          margin: const EdgeInsets.only(right: 10.0),
                          child: const Icon(Icons.qr_code_2),
                        ),
                      ]),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          const HorizontalLine(height: 8),
          Container(
            padding: const EdgeInsets.only(left: 0),
            color: Colors.white,
            child: n.Column([
              /*
              n.ListTile(
                leading: const Icon(
                  Icons.video_library,
                  color: Colors.deepPurple,
                  size: 22,
                ),
                title: Transform(
                  transform: Matrix4.translationValues(-30, 0.0, 0.0),
                  child: Text('我的直播'.tr),
                ),
                trailing: Icon(
                  Icons.navigate_next,
                  color: AppColors.MainTextColor.withOpacity(0.5),
                ),
                onTap: () {
                  Get.to(
                    () => LiveRoomListPage(),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                },
              ),
              n.Padding(left: 40, child: const Divider()),
              */
              n.ListTile(
                leading: const Icon(
                  Icons.collections_bookmark,
                  color: Colors.blue,
                  size: 22,
                ),
                title: Transform(
                  transform: Matrix4.translationValues(-30, 0.0, 0.0),
                  child: Text('我的收藏'.tr),
                ),
                trailing: Icon(
                  Icons.navigate_next,
                  color: AppColors.MainTextColor.withOpacity(0.5),
                ),
                onTap: () {
                  Get.to(
                    () => UserCollectPage(),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                },
              ),
              n.Padding(left: 40, child: const Divider()),
              n.ListTile(
                leading: const Icon(
                  Icons.devices,
                  color: Colors.green,
                  size: 22,
                ),
                title: Transform(
                  transform: Matrix4.translationValues(-30, 0.0, 0.0),
                  child: Text('设备列表'.tr),
                ),
                trailing: Icon(
                  Icons.navigate_next,
                  color: AppColors.MainTextColor.withOpacity(0.5),
                ),
                onTap: () {
                  Get.to(
                    () => UserDevicePage(),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                },
              ),
              /*
              n.Padding(left: 40, child: const Divider()),
              n.ListTile(
                leading: const Icon(
                  Icons.restore_page,
                  color: Colors.indigo,
                  size: 22,
                ),
                title: Transform(
                  transform: Matrix4.translationValues(-30, 0.0, 0.0),
                  child: Text('存储空间和数据'.tr),
                ),
                trailing: Icon(
                  Icons.navigate_next,
                  color: AppColors.MainTextColor.withOpacity(0.5),
                ),
                onTap: () {},
              ),
              */
              n.Padding(left: 40, child: const Divider()),
              n.ListTile(
                leading: const Icon(
                  Icons.speaker_notes_off,
                  color: Colors.grey,
                  size: 22,
                ),
                title: Transform(
                  transform: Matrix4.translationValues(-30, 0.0, 0.0),
                  child: Text('黑名单'.tr),
                ),
                trailing: Icon(
                  Icons.navigate_next,
                  color: AppColors.MainTextColor.withOpacity(0.5),
                ),
                onTap: () {
                  Get.to(
                    () => DenylistPage(),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                },
              ),
              // n.ListTile(
              //   leading: const Icon(
              //     Icons.speaker_notes_off,
              //     color: Colors.grey,
              //     size: 22,
              //   ),
              //   title: Text('告诉朋友'.tr),
              //   trailing: Icon(
              //     Icons.navigate_next,
              //     color: AppColors.MainTextColor.withOpacity(0.5),
              //   ),
              //   onTap: () {},
              // ),
              // n.Padding(
              //   child: const Divider(height: 8),
              // ),
              const HorizontalLine(height: 8),
              n.ListTile(
                leading: const Icon(
                  Icons.settings,
                  color: Colors.grey,
                  size: 22,
                ),
                title: Transform(
                  transform: Matrix4.translationValues(-30, 0.0, 0.0),
                  child: Text('设置'.tr),
                ),
                trailing: Icon(
                  Icons.navigate_next,
                  color: AppColors.MainTextColor.withOpacity(0.5),
                ),
                onTap: () {
                  Get.to(
                    () => const SettingPage(),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                },
              ),
              const HorizontalLine(height: 8),
            ]),
          ),
        ]),
      ),
    );
  }
}
