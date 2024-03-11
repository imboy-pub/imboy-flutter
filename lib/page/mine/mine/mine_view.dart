import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/page/mine/feedback/feedback_view.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/config/const.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/ui/line.dart';

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

  MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.background,
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
              child: n.Padding(
                child: Container(
                  // color: Colors.white,
                  // 显示地区需要360的高度
                  height: c.current.region.isEmpty ? 340 : 380,
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
                                Get.to(
                                  () => const PersonalInfoPage(),
                                  transition: Transition.rightToLeft,
                                  popGesture: true, // 右滑，返回上一页
                                );
                                // EasyLoading.showInfo('请进入【个人信息页面】设置头像'.tr);
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
                      Expanded(
                          child: Container(
                        margin: const EdgeInsets.only(left: 0.0, top: 10.0),
                        width: 200.0,
                        child: n.Column([
                          Text(
                            c.current.nickname,
                            style: const TextStyle(
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
                              "${'account'.tr}：${c.current.account}",
                              // style: const TextStyle(
                              //   color: AppColors.MainTextColor,
                              // ),
                            ),
                          ),
                          strNoEmpty(c.current.region)
                              ? Text(
                                  "${'region'.tr}：${c.current.region}",
                                  // style: const TextStyle(
                                  //     color: AppColors.MainTextColor),
                                )
                              : const SizedBox.shrink(),
                        ])
                          ..mainAxisSize = MainAxisSize.min
                          ..mainAxisAlignment = MainAxisAlignment.start
                          ..crossAxisAlignment = CrossAxisAlignment.start,
                      )),
                      Container(
                        width: 20.0,
                        margin: const EdgeInsets.only(right: 10.0),
                        child: const Icon(Icons.qr_code_2),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
          HorizontalLine(
            height: 8,
            color: Theme.of(context).colorScheme.primary,
          ),
          Container(
            padding: const EdgeInsets.only(left: 0),
            // color: Colors.white,
            child: n.Column([
              /*
              n.ListTile(
                leading: const Icon(
                  Icons.video_library,
                  color: Colors.deepPurple,
                  size: 22,
                ),
                title: Transform(
                  transform: Matrix4.translationValues(-10, 0.0, 0.0),
                  child: Text('my_live'.tr),
                ),
                trailing: navigateNextIcon,
                onTap: () {
                  Get.to(
                    () => LiveRoomListPage(),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                },
              ),
              n.Padding(left: 40, child: HorizontalLine(
            height: 1.0,
            color: Theme.of(context).colorScheme.primary,
          )),
              */
              n.ListTile(
                leading: const Icon(
                  Icons.collections_bookmark,
                  color: Colors.blue,
                  size: 22,
                ),
                title: Transform(
                  transform: Matrix4.translationValues(-10, 0.0, 0.0),
                  child: Text('my_favorites'.tr),
                ),
                trailing: navigateNextIcon,
                onTap: () {
                  Get.to(
                    () => UserCollectPage(),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                },
              ),
              n.Padding(
                  left: 40,
                  child: HorizontalLine(
                    height: 1.0,
                    color: Theme.of(context).colorScheme.primary,
                  )),
              n.ListTile(
                leading: const Icon(
                  Icons.devices,
                  color: Colors.green,
                  size: 22,
                ),
                title: Transform(
                  transform: Matrix4.translationValues(-10, 0.0, 0.0),
                  child: Text('device_list'.tr),
                ),
                trailing: navigateNextIcon,
                onTap: () {
                  Get.to(
                    () => UserDevicePage(),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                },
              ),
              /*
              n.Padding(left: 40, child: HorizontalLine(
            height: 1.0,
            color: Theme.of(context).colorScheme.primary,
          )),
              n.ListTile(
                leading: const Icon(
                  Icons.restore_page,
                  color: Colors.indigo,
                  size: 22,
                ),
                title: Transform(
                  transform: Matrix4.translationValues(-10, 0.0, 0.0),
                  child: Text('storage_space_data'.tr),
                ),
                trailing: navigateNextIcon,
                onTap: () {},
              ),
              */
              n.Padding(
                  left: 40,
                  child: HorizontalLine(
                    height: 1.0,
                    color: Theme.of(context).colorScheme.primary,
                  )),
              n.ListTile(
                leading: const Icon(
                  Icons.speaker_notes_off,
                  color: Colors.grey,
                  size: 22,
                ),
                title: Transform(
                  transform: Matrix4.translationValues(-10, 0.0, 0.0),
                  child: Text('blacklist'.tr),
                ),
                trailing: navigateNextIcon,
                onTap: () {
                  Get.to(
                    () => DenylistPage(),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                },
              ),
              n.Padding(
                  left: 40,
                  child: HorizontalLine(
                    height: 1.0,
                    color: Theme.of(context).colorScheme.primary,
                  )),
              n.ListTile(
                leading: const Icon(
                  Icons.feedback_outlined,
                  color: Colors.teal,
                  size: 22,
                ),
                title: Transform(
                  transform: Matrix4.translationValues(-10, 0.0, 0.0),
                  child: n.Row([
                    Text('feedback'.tr),
                  ]),
                ),
                trailing: navigateNextIcon,
                onTap: () {
                  Get.to(
                    () => FeedbackPage(),
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
              //   title: Text('tell_friend'.tr),
              //   trailing: navigateNextIcon,
              //   onTap: () {},
              // ),
              // n.Padding(
              //   child: const Divider(height: 8),
              // ),
              HorizontalLine(
                height: 8,
                color: Theme.of(context).colorScheme.primary,
              ),
              n.ListTile(
                leading: const Icon(
                  Icons.settings,
                  color: Colors.grey,
                  size: 22,
                ),
                title: Transform(
                  transform: Matrix4.translationValues(-10, 0.0, 0.0),
                  child: Text('setting'.tr),
                ),
                trailing: navigateNextIcon,
                onTap: () {
                  Get.to(
                    () => const SettingPage(),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                },
              ),
              HorizontalLine(
                height: 8,
                color: Theme.of(context).colorScheme.primary,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
