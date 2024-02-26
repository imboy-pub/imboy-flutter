import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/mine/feedback/feedback_detail_view.dart';
import 'package:imboy/store/model/feedback_model.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';

import 'feedback_logic.dart';

//ignore: must_be_immutable
class FeedbackPage extends StatelessWidget {
  FeedbackPage({super.key});

  int page = 1;
  final int size = 1000;
  final logic = Get.put(FeedbackLogic());
  final state = Get.find<FeedbackLogic>().state;

  void initData() async {
    var list = await logic.page(page: page, size: size);
    state.itemList.value = list;
    page = page + 1;
  }

  @override
  Widget build(BuildContext context) {
    initData();

    return Scaffold(
      appBar: PageAppBar(
        title: 'feedback_suggestion'.tr,
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
                      ? NoDataView(text: 'no_data'.tr)
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
                                        String tips = 'sure_delete_data'.tr;
                                        n.showDialog(
                                          context: Get.context!,
                                          builder: (context) => n.Alert()
                                            ..content = SizedBox(
                                              height: 40,
                                              child: Center(child: Text(tips)),
                                            )
                                            ..actions = [
                                              n.Button('button_cancel'.tr.n)
                                                ..style = n.NikuButtonStyle(
                                                    foregroundColor:
                                                        AppColors.ItemOnColor)
                                                ..onPressed = () {
                                                  Navigator.of(context).pop();
                                                },
                                              n.Button('button_delete'.tr.n)
                                                ..style = n.NikuButtonStyle(
                                                    foregroundColor:
                                                        AppColors.ItemOnColor)
                                                ..onPressed = () async {
                                                  Navigator.of(context).pop();
                                                  bool res = await logic.remove(
                                                    model.feedbackId,
                                                  );
                                                  if (res) {
                                                    state.itemList.removeAt(
                                                      state.itemList.indexWhere(
                                                          (e) =>
                                                              e.feedbackId ==
                                                              model.feedbackId),
                                                    );
                                                    EasyLoading.showSuccess(
                                                        'tip_success'.tr);
                                                  } else {
                                                    EasyLoading.showError(
                                                        'tip_failed'.tr);
                                                  }
                                                },
                                            ],
                                          barrierDismissible: true,
                                        );
                                      },
                                      label: 'button_delete'.tr,
                                      spacing: 1,
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.only(left: 0),
                                  title: n.Column([
                                    n.Row([
                                      Text(
                                        "${model.type.tr} | ${'submitted_at'.tr}",
                                        style: const TextStyle(
                                          color: AppColors.MainTextColor,
                                          fontSize: 14.0,
                                        ),
                                      ),
                                    ]),
                                    n.Row([
                                      Text(
                                        DateTimeHelper.lastTimeFmt(
                                            model.createdAtLocal),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.MainTextColor,
                                          fontSize: 14.0,
                                        ),
                                      ),
                                      const Expanded(child: SizedBox()),
                                      Text(
                                        model.statusDesc,
                                        style: const TextStyle(
                                          color: AppColors.MainTextColor,
                                          fontSize: 14.0,
                                        ),
                                      )
                                    ])
                                  ]),
                                  subtitle: n.Row([
                                    Expanded(
                                      child: Text(
                                        // 会话对象标题
                                        model.body,
                                        style: const TextStyle(
                                          fontSize: 18.0,
                                          fontWeight: FontWeight.normal,
                                        ),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
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
