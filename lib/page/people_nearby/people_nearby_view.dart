import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/page/single/people_info.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/config/const.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'people_nearby_logic.dart';

// ignore: must_be_immutable
class PeopleNearbyPage extends StatelessWidget {
  PeopleNearbyPage({super.key});

  ValueAdapter adapter = ValueAdapter(0.0, animated: true);
  bool changedAdapter = true;

  rotateCompass() {
    adapter.value = changedAdapter ? 1.0 : 0.0;
    changedAdapter = !changedAdapter;
  }

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(PeopleNearbyLogic());
    final state = Get.find<PeopleNearbyLogic>().state;

    Future.delayed(const Duration(milliseconds: 200), () {
      rotateCompass();
    });

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
                    rotateCompass();
                    logic.peopleNearby();
                  },
                  child: const Icon(
                    Icons.explore,
                    color: Colors.lightBlue,
                    size: 80,
                  )
                      .animate(adapter: adapter)
                      .rotate(duration: const Duration(milliseconds: 200)),
                )
              ],
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            ),
            n.Row(
              [
                Text(
                  '和附近的人交换联系方式，结交新朋友'.tr,
                  style: const TextStyle(
                    color: AppColors.TipColor,
                    fontSize: 15,
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
                                String tips =
                                    '附近的用户可以查看你的个人资料并给你发送信息。这可能会帮助你找到新朋友，但也可能会引起过多的关注。你可以随时停止分享你的个人资料。\n\n你的电话号码将会被隐藏。'
                                        .tr;
                                // Users nearby will be able to view your profile and send you messages. This may help you find new friends, but could also attract excessive attention. You can stop sharing your profile at any time.
                                //
                                // Your phone number will remain hidden.

                                Get.defaultDialog(
                                  title: '显示你的资料'.tr,
                                  // Show You Profile
                                  content: Text(tips),
                                  textCancel: "  ${'取消'.tr}  ",
                                  textConfirm: "  ${'确定'.tr}  ",
                                  confirmTextColor:
                                      AppColors.primaryElementText,
                                  onConfirm: () {
                                    // 异步处理
                                    logic.makeMyselfVisible();
                                    Get.back();
                                    EasyLoading.showSuccess('操作成功'.tr);
                                  },
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
                            itemBuilder: (BuildContext context, int index) {
                              PeopleModel model = state.peopleList[index];
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
                                      PeopleInfoPage(
                                        id: model.id,
                                        sence: 'people_nearby',
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
