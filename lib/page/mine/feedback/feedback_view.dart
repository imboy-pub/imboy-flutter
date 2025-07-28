import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/line.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/mine/feedback/feedback_detail_view.dart';
import 'package:imboy/store/model/feedback_model.dart';
import 'package:imboy/component/ui/common_bar.dart';

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
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'feedback'.tr,
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height,
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 15, right: 10),
                  child: Obx(() {
                    return state.itemList.isEmpty
                        ? NoDataView(text: 'no_data'.tr)
                        : ListView.builder(
                      itemCount: state.itemList.length,
                      itemBuilder: (BuildContext context, int index) {
                        FeedbackModel model = state.itemList[index];
                        return Column(
                          children: [
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
                                      showDialog(
                                        context: Get.context!,
                                        builder: (context) => AlertDialog(
                                          content: SizedBox(
                                            height: 40,
                                            child: Center(child: Text(tips)),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              style: TextButton.styleFrom(
                                                foregroundColor: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                              child: Text('button_cancel'.tr),
                                            ),
                                            TextButton(
                                              onPressed: () async {
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
                                              style: TextButton.styleFrom(
                                                foregroundColor: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                              ),
                                              child: Text('button_delete'.tr),
                                            ),
                                          ],
                                        ),
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
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            "${model.type.tr} | ${'submitted_at'.tr}",
                                            style: const TextStyle(
                                              // color: AppColors.MainTextColor,
                                              fontSize: 14.0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            DateTimeHelper.lastTimeFmt(
                                                model.createdAt),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              // color: AppColors.MainTextColor,
                                              fontSize: 14.0,
                                            ),
                                          ),
                                        ),
                                        const Expanded(child: SizedBox()),
                                        Text(
                                          model.statusDesc,
                                          style: const TextStyle(
                                            // color: AppColors.MainTextColor,
                                            fontSize: 14.0,
                                          ),
                                        )
                                      ],
                                    )
                                  ],
                                ),
                                subtitle: Row(
                                  children: [
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
                                  ],
                                ),
                                trailing: navigateNextIcon,
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
                            HorizontalLine(
                              height: Get.isDarkMode ? 0.5 : 1.0,
                            ),
                          ],
                        );
                      },
                    );
                  }),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}