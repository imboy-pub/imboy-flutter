import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/confirm_alert.dart';
import 'package:imboy/page/scanner/scanner_result_view.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/config/const.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'people_nearby_logic.dart';

class PeopleNearbyPage extends StatelessWidget {
  const PeopleNearbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(PeopleNearbyLogic());
    final state = Get.find<PeopleNearbyLogic>().state;

    return Scaffold(
      backgroundColor: AppColors.AppBarColor,
      appBar: PageAppBar(title: '附近的人'.tr),
      body: SlidableAutoCloseBehavior(
        child: n.Column(
          [
            n.Row(
              [
                InkWell(
                  onTap: () {
                    logic.peopleNearby();
                  },
                  child: Roulette(
                    spins: 1,
                    infinite: false,
                    controller: (AnimationController c) {
                      return c;
                    },
                    manualTrigger: true,
                    child: const Icon(
                      Icons.explore,
                      size: 80,
                      color: Colors.lightBlue,
                    ),
                  ),
                )
              ],
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            ),
            n.Row(
              [
                Text(
                  '和附近的人交换联系方式，结交新朋友。'.tr,
                  style: const TextStyle(
                    color: AppColors.TipColor,
                    fontSize: 12,
                  ),
                )
              ],
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            ),
            SizedBox(
              width: Get.width,
              height: 8,
            ),
            // 附近的人
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(left: 12, right: 12),
                // padding: EdgeInsets.only(left: 10),
                child: Card(
                  child: n.Column([
                    n.Row(
                      [
                        SizedBox(
                          width: Get.width * 0.9,
                          child: TextButton(
                            onPressed: () {
                              if (state.peopleNearbyVisible.isFalse) {
                                confirmAlert(
                                  context,
                                      (isOK) {
                                    if (isOK) {
                                      // 异步处理
                                      logic.makeMyselfVisible();
                                      EasyLoading.showSuccess('操作成功'.tr);
                                    }
                                  },
                                  isWarm: true,
                                  warmStr: '显示你的资料'.tr, // Show You Profile
                                  tips:
                                  '附近的用户可以查看你的个人资料并给你发送信息。这可能会帮助你找到新朋友，但也可能会引起过多的关注。你可以随时停止分享你的个人资料。\n\n你的电话号码将会被隐藏。',
                                  // Users nearby will be able to view your profile and send you messages. This may help you find new friends, but could also attract excessive attention. You can stop sharing your profile at any time.
                                  //
                                  // Your phone number will remain hidden.
                                );
                              } else {
                                logic.makeMyselfUnvisible();
                              }
                            },
                            style: ButtonStyle(
                              overlayColor:
                              MaterialStateProperty.all(Colors.transparent),
                              backgroundColor:
                              MaterialStateProperty.resolveWith((states) {
                                return states.contains(MaterialState.pressed)
                                    ? Colors.black12
                                    : Colors.white;
                              }),
                              shape: MaterialStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            child: n.Row(
                              [
                                Obx(() => Icon(
                                  state.peopleNearbyVisible.isFalse
                                      ? Icons.location_on
                                      : Icons.location_off,
                                  size: 28.0,
                                  color: Colors.lightBlue,
                                )),
                                const SizedBox(
                                  width: 8,
                                  height: 32,
                                ),
                                Obx(() => Text(
                                  state.peopleNearbyVisible.isFalse
                                      ? '让自己可见'.tr
                                      : '让自己不可见'.tr, // Stop Showing Me
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.lightBlue,
                                  ),
                                ))
                              ],
                              mainAxisAlignment: MainAxisAlignment.start,
                            ),
                          ),
                        ),
                      ],
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    ),
                    Expanded(
                      child: n.Padding(
                        left: 10,
                        right: 10,
                        child: Obx(() {
                          return ListView.builder(
                            itemCount: state.peopleList.length,
                            itemBuilder:
                                (BuildContext context, int index) {
                              PeopleModel model =
                              state.peopleList[index];
                              return n.Column([
                                const Divider(
                                  height: 8.0,
                                  indent: 0.0,
                                  color: Colors.black26,
                                ),
                                ListTile(
                                  leading: Avatar(imgUri: model.avatar),
                                  contentPadding:
                                  const EdgeInsets.only(left: 0),
                                  title: Text(model.nickname),
                                  subtitle: Text(
                                      '${model.distince} ${model.distinceUnit}'),
                                  onTap: () {
                                    Get.to(
                                      ScannerResultPage(
                                        id: model.id,
                                        // remark: model.payload['remark'] ?? '',
                                        nickname: model.nickname,
                                        avatar: model.avatar,
                                        sign: model.sign,
                                        region: model.region,
                                        gender: model.gender,
                                        isFriend: model.isFriend,
                                      ),
                                      transition: Transition.rightToLeft,
                                      popGesture: true, // 右滑，返回上一页
                                    );
                                  },
                                )
                              ]);
                            },
                          );
                        }),
                      ),
                    ),
                  ]),
                ),
              ),
            )
            // 附近的群
          ],
          mainAxisSize: MainAxisSize.min,
        )..useParent((v) => v..bg = AppColors.AppBarColor),
      ),
    );
  }
}
