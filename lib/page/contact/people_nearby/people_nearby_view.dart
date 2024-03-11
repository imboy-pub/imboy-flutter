import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/line.dart';

import 'package:imboy/page/single/people_info.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:niku/namespace.dart' as n;

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
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'people_nearby'.tr,
      ),
      body: SlidableAutoCloseBehavior(
        child: n.Column([
          n.Row([
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
                  .rotate(duration: const Duration(milliseconds: 300)),
            )
          ], mainAxisAlignment: MainAxisAlignment.spaceEvenly),
          n.Row([
            Text(
              'nearby_people_tips'.tr,
              style: const TextStyle(
                fontSize: 15,
              ),
            )
          ], mainAxisAlignment: MainAxisAlignment.spaceEvenly),
          SizedBox(
            width: Get.width,
            height: 8,
          ),
          // 附近的人
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 12, right: 12),
              child: Card(
                color: Get.isDarkMode
                    ? const Color.fromRGBO(80, 80, 80, 1)
                    : const Color.fromRGBO(240, 240, 240, 1),
                child: n.Column([
                  n.Row([
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: Get.width * 0.9,
                      child: TextButton(
                        onPressed: () {
                          if (state.peopleNearbyVisible.isFalse) {
                            // Your phone number will remain hidden.
                            Get.defaultDialog(
                              title: 'display_profile'.tr,
                              backgroundColor: Get.isDarkMode
                                  ? const Color.fromRGBO(80, 80, 80, 1)
                                  : const Color.fromRGBO(240, 240, 240, 1),
                              // Show You Profile
                              content: Text('nearby_people_explain'.tr),
                              textCancel: "  ${'button_cancel'.tr}  ",
                              textConfirm: "  ${'button_confirm'.tr}  ",
                              onConfirm: () {
                                // 异步处理
                                logic.makeMyselfVisible();
                                Get.closeAllDialogs();
                                EasyLoading.showSuccess('tip_success'.tr);
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
                            // return states.contains(MaterialState.pressed)
                            //     ? Colors.black12
                            //     : Colors.white;
                            return Theme.of(context).colorScheme.background;
                          }),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        child: n.Row([
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
                                    ? 'make_yourself_visible'.tr
                                    : 'make_yourself_invisible'.tr,
                                // Stop Showing Me
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.lightBlue,
                                ),
                              ))
                        ], mainAxisAlignment: MainAxisAlignment.start),
                      ),
                    ),
                  ])
                    ..mainAxisAlignment = MainAxisAlignment.spaceEvenly,
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
                              ListTile(
                                leading: Avatar(imgUri: model.avatar),
                                contentPadding: const EdgeInsets.only(left: 0),
                                title: Text(model.nickname),
                                subtitle: Text(
                                    '${model.distance.toStringAsFixed(3)} ${model.distanceUnit}'),
                                onTap: () {
                                  Get.to(
                                    () => PeopleInfoPage(
                                      id: model.id,
                                      scene: 'people_nearby',
                                    ),
                                    transition: Transition.rightToLeft,
                                    popGesture: true, // 右滑，返回上一页
                                  );
                                },
                              ),
                              const HorizontalLine(height: 1.0),
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
        ])
          ..mainAxisSize = MainAxisSize.min
          ..useParent((v) => v..bg = Theme.of(context).colorScheme.background),
      ),
    );
  }
}
