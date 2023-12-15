import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/store/model/feedback_model.dart';
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
      ),
      body: SingleChildScrollView(
        child: n.Padding(
          left: 16,
          right: 16,
          top: 10,
          child: n.Column([
            n.Row([
              Text(
                '提交于'.tr,
                style: const TextStyle(
                  color: AppColors.MainTextColor,
                  fontSize: 14.0,
                ),
              ),
              const Space(width: 10),
              Text(
                DateTimeHelper.lastTimeFmt(model.createdAt),
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
              ),
            ]),
            n.Row([
              Text(
                model.type.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.MainTextColor,
                  fontSize: 14.0,
                ),
              ),
              const Expanded(child: SizedBox()),
              if (model.rating.isNotEmpty)
                IconButton(
                  icon: Icon(
                    model.ratingIcon,
                    color: AppColors.secondaryElementText,
                  ),
                  iconSize: 32,
                  onPressed: null,
                ),
              Text(
                model.rating.tr,
                style: const TextStyle(
                  color: AppColors.MainTextColor,
                  fontSize: 14.0,
                ),
              ),
              const Space(width: 10),
              InkWell(
                child: n.Row([
                  Text('浏览附件'.tr),
                  const Icon(Icons.screenshot),
                ]),
                onTap: () {
                  zoomInPhotoViewGallery(model.attach);
                  // zoomInPhotoView(model.attach[0]);
                  // TODO open screenshot
                },
              ),
            ]),
            n.Padding(
              top: 8,
              bottom: 20,
              child: const HorizontalLine(
                height: 2,
                color: Colors.black12,
              ),
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
            // n.Row(const [Text('回复：')]),
            // n.ListTile(),
            // n.Row([]),
          ], mainAxisSize: MainAxisSize.min),
        ),
      ),
    );
  }
}
