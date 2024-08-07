import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/ui/nodata_view.dart';

import 'package:imboy/store/model/feedback_reply_model.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/store/model/feedback_model.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'feedback_logic.dart';

//ignore: must_be_immutable
class FeedbackDetailPage extends StatelessWidget {
  final FeedbackModel model;

  FeedbackDetailPage({super.key, required this.model});

  int page = 1;
  final int size = 1000;
  final logic = Get.put(FeedbackLogic());
  final state = Get.find<FeedbackLogic>().state;

  void initData() async {
    page = 1;
    state.pageReplyList.value = [];
    var list = await logic.pageReply(
      model.feedbackId,
      page: page,
      size: size,
    );
    if (list.isNotEmpty) {
      page = page + 1;
    }
    state.pageReplyList.value = list;
  }

  @override
  Widget build(BuildContext context) {
    initData();

    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'feedback_details'.tr,
      ),
      body: SingleChildScrollView(
        child: n.Padding(
          left: 16,
          right: 16,
          top: 10,
          child: n.Column([
            n.Row([
              Text(model.type.tr, maxLines: 1, overflow: TextOverflow.ellipsis),
              const Expanded(child: SizedBox()),
              Text('submitted_at'.tr),
              const Space(width: 10),
              Text(
                DateTimeHelper.lastTimeFmt(model.createdAtLocal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
            n.Row([
              Text('status'.tr),
              Text(': ${model.statusDesc}'),
              const Expanded(child: SizedBox()),
              const Space(width: 10),
              InkWell(
                child: n.Row([
                  Text('view_attachments'.tr),
                  const Icon(
                    Icons.screenshot,
                    size: 40,
                  ),
                ]),
                onTap: () {
                  zoomInPhotoViewGallery(model.attach);
                  // zoomInPhotoView(model.attach[0]);
                  // TODO open screenshot
                },
              ),
            ]),
            if (model.rating.isNotEmpty)
              n.Row([
                Text('rating'.tr),
                Text(': ${model.rating}    '),
                Text(model.ratingDesc),
              ]),
            if (model.rating.isNotEmpty)
              n.Row([
                RatingBar.builder(
                  initialRating: double.parse(model.rating),
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                  itemBuilder: (context, _) => const Icon(
                    Icons.star,
                    color: Colors.amber,
                  ),
                  onRatingUpdate: (rating) {
                    // print(rating);
                  },
                ),
              ])
                // 内容居中
                ..mainAxisAlignment = MainAxisAlignment.center,
            n.Padding(
              top: 8,
              bottom: 20,
              child: const HorizontalLine(height: 1.0),
            ),
            n.Row([
              Expanded(
                child: Text(
                  // 会话对象标题
                  model.body,
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.normal,
                  ),
                  maxLines: 80,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            ]),
            n.Padding(
              top: 8,
              bottom: 20,
              child: const HorizontalLine(height: 1.0),
            ),
            n.Row([
              SingleChildScrollView(
                child: Container(
                  width: Get.width - 32,
                  height: Get.height,
                  color: Theme.of(context).colorScheme.surface,
                  child: n.Column([
                    Expanded(
                      child: n.Padding(
                        left: 15,
                        right: 10,
                        child: Obx(() {
                          return state.pageReplyList.isEmpty
                              ? NoDataView(text: 'no_reply'.tr)
                              : ListView.builder(
                                  itemCount: state.pageReplyList.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    FeedbackReplyModel model =
                                        state.pageReplyList[index];
                                    return n.Column([
                                      ListTile(
                                        contentPadding:
                                            const EdgeInsets.only(left: 0),
                                        title: n.Row([
                                          Text(
                                            'replied_at'.tr,
                                            style: const TextStyle(
                                              // color: AppColors.MainTextColor,
                                              fontSize: 14.0,
                                            ),
                                          ),
                                          const Space(width: 10),
                                          Text(
                                            DateTimeHelper.lastTimeFmt(
                                                model.createdAtLocal),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              // color: AppColors.MainTextColor,
                                              fontSize: 14.0,
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
                                        // onTap: () {
                                        //   Get.to(
                                        //     () => FeedbackDetailPage(
                                        //       model: model,
                                        //     ),
                                        //     transition:
                                        //         Transition.rightToLeft,
                                        //     popGesture: true, // 右滑，返回上一页
                                        //   );
                                        // },
                                      ),
                                      const HorizontalLine(height: 1.0)
                                    ]);
                                  },
                                );
                        }),
                      ),
                    )
                  ], mainAxisSize: MainAxisSize.min),
                ),
              )
            ])
          ], mainAxisSize: MainAxisSize.min),
        ),
      ),
    );
  }
}
