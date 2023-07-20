import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/page/single/people_info.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';

import 'recently_registered_user_logic.dart';

class RecentlyRegisteredUserPage extends StatelessWidget {
  RecentlyRegisteredUserPage({super.key});

  final logic = Get.put(RecentlyRegisteredUserLogic());
  final state = Get.find<RecentlyRegisteredUserLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.BgColor,
      appBar: PageAppBar(title: '新注册的朋友'.tr),
      body: SlidableAutoCloseBehavior(
          child: n.Column(
        [
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
                        contentPadding: const EdgeInsets.only(left: 0),
                        title: Text(model.nickname),
                        subtitle: Text(
                            '${model.distance.toStringAsFixed(3)} ${model.distanceUnit}'),
                        onTap: () {
                          Get.to(
                            () => PeopleInfoPage(
                              id: model.id,
                              scene: 'recently_user',
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
        ],
        mainAxisSize: MainAxisSize.min,
      )
          // ..useParent((v) => v..bg = AppColors.AppBarColor),
          ),
    );
  }
}
