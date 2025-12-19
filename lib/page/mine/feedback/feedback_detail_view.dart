import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/ui/nodata_view.dart';

import 'package:imboy/store/model/feedback_reply_model.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/model/feedback_model.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'feedback_logic.dart';

/// 反馈详情页面
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
    var list = await logic.pageReply(model.feedbackId, page: page, size: size);
    if (list.isNotEmpty) {
      page = page + 1;
    }
    state.pageReplyList.value = list;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    initData();

    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'feedbackDetails'.tr,
      ),
      backgroundColor: colorScheme.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            
            // 反馈基本信息卡片
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withAlpha(25),
                      colorScheme.primary.withAlpha(10),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题行
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withAlpha(51),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.feedback,
                            color: colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                model.type.tr,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${'submittedAt'.tr} ${DateTimeHelper.lastTimeFmt(model.createdAt)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurface.withAlpha(179),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(context, model.statusDesc).withAlpha(51),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            model.statusDesc,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _getStatusColor(context, model.statusDesc),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // 操作按钮行
                    Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                zoomInPhotoViewGallery(model.attach);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer.withAlpha(128),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.screenshot,
                                      color: colorScheme.secondary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'viewAttachments'.tr,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 评分信息卡片（如果有评分）
            if (model.rating.isNotEmpty)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'rating'.tr,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${model.rating} ${model.ratingDesc}',
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface.withAlpha(179),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: RatingBar.builder(
                          initialRating: double.parse(model.rating),
                          minRating: 1,
                          direction: Axis.horizontal,
                          allowHalfRating: true,
                          itemCount: 5,
                          itemSize: 32,
                          itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                          itemBuilder: (context, _) =>
                              const Icon(Icons.star, color: Colors.amber),
                          onRatingUpdate: (rating) {},
                          ignoreGestures: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            if (model.rating.isNotEmpty) const SizedBox(height: 16),
            
            // 反馈内容卡片
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '反馈内容',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withAlpha(128),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        model.body,
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurface,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 回复列表卡片
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.reply,
                          color: colorScheme.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '官方回复',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // 回复列表
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: Get.height * 0.4,
                      ),
                      child: Obx(() {
                        return state.pageReplyList.isEmpty
                            ? SizedBox(
                                height: 120,
                                child: NoDataView(text: 'noReply'.tr),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: state.pageReplyList.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (BuildContext context, int index) {
                                  FeedbackReplyModel replyModel = state.pageReplyList[index];
                                  return _buildReplyItem(context, replyModel);
                                },
                              );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 构建回复项组件
  Widget _buildReplyItem(BuildContext context, FeedbackReplyModel replyModel) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withAlpha(51),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 回复时间和状态
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withAlpha(128),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.support_agent,
                  color: colorScheme.secondary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${'repliedAt'.tr} ${DateTimeHelper.lastTimeFmt(replyModel.createdAt)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(context, replyModel.statusDesc).withAlpha(51),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  replyModel.statusDesc,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _getStatusColor(context, replyModel.statusDesc),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 回复内容
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              replyModel.body,
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取状态颜色
  Color _getStatusColor(BuildContext context, String status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case '已处理':
        return Colors.green;
      case '处理中':
        return Colors.orange;
      case '已提交':
        return colorScheme.primary;
      default:
        return colorScheme.onSurface;
    }
  }
}