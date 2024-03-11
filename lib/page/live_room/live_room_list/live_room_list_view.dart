import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';

import 'package:imboy/config/const.dart';

// import 'package:imboy/page/live_room/publisher/publisher_view.dart';
// import 'package:imboy/page/live_room/subscriber/subscriber_view.dart';
import 'package:imboy/store/model/live_room_model.dart';
import 'package:niku/namespace.dart' as n;

import 'live_room_list_logic.dart';

class LiveRoomListPage extends StatelessWidget {
  final logic = Get.put(LiveRoomListLogic());
  final state = Get.find<LiveRoomListLogic>().state;

  LiveRoomListPage({super.key});

  void initData() async {
    // currentDid.value = deviceId;
    // var list = await logic.page(page: page, size: size);
    var list = [];
    list.add(LiveRoomModel(
      userId: "1",
      tagId: 1,
      scene: 1,
      name: "name",
      subtitle: "subtitle",
      refererTime: 0,
      updatedAt: 0,
      createdAt: 0,
    ));
    state.items.value = list;
  }

  @override
  Widget build(BuildContext context) {
    //
    initData();

    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'my_live'.tr,
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height,
          color: Theme.of(context).colorScheme.background,
          child: n.Column([
            Expanded(
              child: n.Padding(
                left: 15,
                right: 10,
                child: Obx(() {
                  return state.items.isEmpty
                      ? NoDataView(text: 'no_data'.tr)
                      : ListView.builder(
                          itemCount: state.items.length,
                          itemBuilder: (BuildContext context, int index) {
                            // LiveRoomModel model = state.items[index];
                            return n.Column([
                              ListTile(
                                contentPadding: const EdgeInsets.only(left: 0),
                                title: n.Row([
                                  Text('live_broadcast'.tr),
                                  const Space(width: 10),
                                ]),
                                subtitle: n.Row([
                                  Text('PublisherPage'.tr),
                                ]),
                                trailing: navigateNextIcon,
                                onTap: () {
                                  // Get.to(
                                  //   () => const PublisherPage(),
                                  //   transition: Transition.rightToLeft,
                                  //   popGesture: true, // 右滑，返回上一页
                                  // );
                                  // Get.to(
                                  //   () => LiveRoomPage(
                                  //     room: model,
                                  //   ),
                                  //   transition: Transition.rightToLeft,
                                  //   popGesture: true, // 右滑，返回上一页
                                  // );
                                },
                              ),
                              const Divider(
                                height: 8.0,
                                indent: 0.0,
                                color: Colors.black26,
                              ),
                              ListTile(
                                contentPadding: const EdgeInsets.only(left: 0),
                                title: n.Row([
                                  Text('live_broadcast'.tr),
                                  const Space(width: 10),
                                ]),
                                subtitle: n.Row([
                                  Text('Subscriber'.tr),
                                ]),
                                trailing: navigateNextIcon,
                                onTap: () {
                                  // Get.to(
                                  //   () => const SubscriberPage(),
                                  //   transition: Transition.rightToLeft,
                                  //   popGesture: true, // 右滑，返回上一页
                                  // );
                                  // Get.to(
                                  //   () => LiveRoomPage(
                                  //     room: model,
                                  //   ),
                                  //   transition: Transition.rightToLeft,
                                  //   popGesture: true, // 右滑，返回上一页
                                  // );
                                },
                              ),
                              const Divider(
                                height: 8.0,
                                indent: 0.0,
                                color: Colors.black26,
                              ),
                            ]);
                          },
                        );
                }),
              ),
            )
          ], mainAxisSize: MainAxisSize.min),
        ),
      ),
    );
  }
}
