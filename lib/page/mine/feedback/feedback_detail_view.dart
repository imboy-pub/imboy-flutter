import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/store/model/feedback_model.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';

import 'feedback_logic.dart';

class FeedbackDetailPage extends StatelessWidget {
  final FeedbackModel model;
  FeedbackDetailPage({super.key, required this.model});

  final logic = Get.put(FeedbackLogic());
  final state = Get.find<FeedbackLogic>().state;

  void initData() async {}

  @override
  Widget build(BuildContext context) {
    initData();

    return Scaffold(
      appBar: PageAppBar(
        title: '反馈建议明细'.tr,
        // rightDMActions: [
        //   TextButton(
        //     onPressed: () {
        //       // Get.to(()=>
        //       //   AddFriendPage(),
        //       //   transition: Transition.rightToLeft,
        //       //   popGesture: true, // 右滑，返回上一页
        //       // );
        //     },
        //     child: Text(
        //       '编辑'.tr,
        //     ),
        //   )
        // ],
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height,
          color: AppColors.primaryBackground,
          child: n.Column([
            Expanded(
              child: n.Padding(
                left: 15,
                right: 10,
                child: Obx(() {
                  return state.itemList.isEmpty
                      ? NoDataView(text: '暂无数据'.tr)
                      : ListView.builder(
                          itemCount: state.itemList.length,
                          itemBuilder: (BuildContext context, int index) {
                            FeedbackModel model = state.itemList[index];
                            return n.Column([
                              Slidable(
                                key: ValueKey(model.feedbackId),
                                groupTag: '0',
                                closeOnScroll: true,
                                endActionPane: ActionPane(
                                  extentRatio: 0.25,
                                  motion: const BehindMotion(),
                                  children: [
                                    SlidableAction(
                                      key: ValueKey("delete_$index"),
                                      flex: 2,
                                      backgroundColor: Colors.red,
                                      // foregroundColor: Colors.white,
                                      onPressed: (_) async {
                                        String tips =
                                            '删除后，下次在该设备登录时需要进行安全验证。'.tr;
                                        final alert = n.Alert()
                                          ..content = SizedBox(
                                            height: 40,
                                            child: Center(child: Text(tips)),
                                          )
                                          ..actions = [
                                            n.Button('取消'.tr.n)
                                              ..style = n.NikuButtonStyle(
                                                  foregroundColor:
                                                      AppColors.ItemOnColor)
                                              ..onPressed = () {
                                                Get.close(1);
                                              },
                                            n.Button('删除'.tr.n)
                                              ..onPressed = () async {
                                                bool res = await logic.remove(
                                                  model.feedbackId,
                                                );
                                                Get.close(2);
                                                if (res) {
                                                  state.itemList.removeAt(
                                                    state.itemList.indexWhere(
                                                        (e) =>
                                                            e.feedbackId ==
                                                            model.feedbackId),
                                                  );
                                                  EasyLoading.showSuccess(
                                                      '操作成功'.tr);
                                                } else {
                                                  EasyLoading.showError(
                                                      '操作失败'.tr);
                                                }
                                              },
                                          ];

                                        n.showDialog(
                                          context: Get.context!,
                                          builder: (context) => alert,
                                          barrierDismissible: true,
                                        );
                                      },
                                      label: "删除".tr,
                                      spacing: 1,
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.only(left: 0),
                                  title: n.Row([
                                    Text(model.title),
                                    // const Space(width: 10),
                                  ]),
                                  subtitle: n.Row([
                                    Text(model.body),
                                  ]),
                                  trailing: Icon(
                                    Icons.navigate_next,
                                    color: AppColors.MainTextColor.withOpacity(
                                        0.5),
                                  ),
                                  onTap: () {
                                    Get.to(
                                      () => FeedbackDetailPage(
                                        model: model,
                                      ),
                                      transition: Transition.rightToLeft,
                                      popGesture: true, // 右滑，返回上一页
                                    );
                                  },
                                ),
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
