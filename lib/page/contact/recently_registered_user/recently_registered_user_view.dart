import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/contact/people_info/people_info_view.dart';
import 'package:imboy/store/model/people_model.dart';

import 'recently_registered_user_logic.dart';

class RecentlyRegisteredUserPage extends StatelessWidget {
  RecentlyRegisteredUserPage({super.key});

  final logic = Get.put(RecentlyRegisteredUserLogic());
  final state = Get.find<RecentlyRegisteredUserLogic>().state;

  void initData() async {
    state.page = 1;
    var list = await logic.page(
      page: state.page,
      size: state.size,
      kwd: state.kwd.value,
    );
    if (list.isNotEmpty) {
      state.peopleList.value = list;
      state.page += 1;
    }

    /*
    controller.addListener(() async {
      double pixels = controller.position.pixels;
      double maxScrollExtent = controller.position.maxScrollExtent;
      // debugPrint("RefreshIndicator_collect_ $pixels; $maxScrollExtent; ");
      // 滑动到底部，执行加载更多操作
      if (pixels == maxScrollExtent) {
        var list = await logic.page(
          page: state.page,
          size: state.size,
          kwd: state.kwd.value,
        );
        if (list.isNotEmpty) {
          state.items.addAll(list);
          state.page = state.page + 1;
        } else {
          EasyLoading.showToast('no_more_data'.tr);
        }
      }
    });
    */
  }

  @override
  Widget build(BuildContext context) {
    initData();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'newly_registered_people'.tr,
      ),
      body: SlidableAutoCloseBehavior(
          child: n.Column([
        Expanded(
          child: n.Padding(
            left: 10,
            right: 10,
            child: Obx(() => ListView.builder(
                  itemCount: state.peopleList.length,
                  itemBuilder: (BuildContext context, int index) {
                    PeopleModel model = state.peopleList[index];
                    return n.Column([
                      if (index > 0)
                        const Divider(
                          height: 8.0,
                          indent: 0.0,
                          color: Colors.black26,
                        ),
                      ListTile(
                        leading: Avatar(imgUri: model.avatar),
                        contentPadding: const EdgeInsets.only(left: 0),
                        title: Text(model.nickname.isEmpty
                            ? model.account
                            : model.nickname),
                        subtitle: n.Row([
                          if (model.createdAt > 0) Text(
                            "${DateTimeHelper.lastTimeFmt(model.createdAtLocal)}  ",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              // color: AppColors.MainTextColor,
                              fontSize: 14.0,
                            ),
                          ),
                          Expanded(
                              child: Text(
                            model.sign,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )),
                        ]),
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
                )),
          ),
        ),
      ])
            ..mainAxisSize = MainAxisSize.min
          // ..useParent((v) => v..bg = AppColors.AppBarColor),
          ),
    );
  }
}
