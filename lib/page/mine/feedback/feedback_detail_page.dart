import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/store/model/feedback_reply_model.dart';
import 'package:imboy/store/model/feedback_model.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/mine/feedback/feedback_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 反馈详情页面
class FeedbackDetailPage extends ConsumerStatefulWidget {
  final FeedbackModel model;

  const FeedbackDetailPage({super.key, required this.model});

  @override
  ConsumerState<FeedbackDetailPage> createState() => _FeedbackDetailPageState();
}

class _FeedbackDetailPageState extends ConsumerState<FeedbackDetailPage> {
  int page = 1;
  final int size = 1000;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
    });
  }

  Future<void> _initData() async {
    if (_isInitialized) return;
    _isInitialized = true;

    page = 1;
    final list = await ref
        .read(feedbackPageProvider.notifier)
        .pageReply(widget.model.feedbackId, page: page, size: size);
    if (list.isNotEmpty) {
      page = page + 1;
    }
    // 更新状态中的回复列表
    ref.read(feedbackPageProvider.notifier).setPageReplyList(list);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(feedbackPageProvider);

    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.common.feedbackDetails,
      ),
      backgroundColor: AppColors.getSurfaceGrouped(
        Theme.of(context).brightness,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // 反馈基本信息卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusRegular,
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
                          borderRadius: AppRadius.borderRadiusMedium,
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
                              widget.model.type == 'bug_report'
                                  ? t.main.bugReport
                                  : widget.model.type == 'feature_request'
                                  ? t.chat.featureRequest
                                  : widget.model.type,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${t.common.submittedAt} ${DateTimeHelper.lastTimeFmt(widget.model.createdAt)}',
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
                          color: _getStatusColor(
                            context,
                            widget.model.statusDesc,
                          ).withAlpha(51),
                          borderRadius: AppRadius.borderRadiusSmall,
                        ),
                        child: Text(
                          widget.model.statusDesc,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _getStatusColor(
                              context,
                              widget.model.statusDesc,
                            ),
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
                            borderRadius: AppRadius.borderRadiusSmall,
                            onTap: () {
                              zoomInPhotoViewGallery(
                                context,
                                widget.model.attach,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer.withAlpha(
                                  128,
                                ),
                                borderRadius: AppRadius.borderRadiusSmall,
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
                                    t.chat.viewAttachments,
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

            const SizedBox(height: 16),

            // 评分信息卡片（如果有评分）
            if (widget.model.rating.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: AppRadius.borderRadiusRegular,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: AppColors.iosYellow, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          t.chat.rating,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${widget.model.rating} ${widget.model.ratingDesc}',
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
                        initialRating: double.parse(widget.model.rating),
                        minRating: 1,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemSize: 32,
                        itemPadding: const EdgeInsets.symmetric(
                          horizontal: 4.0,
                        ),
                        itemBuilder: (context, _) =>
                            const Icon(Icons.star, color: AppColors.iosYellow),
                        onRatingUpdate: (rating) {},
                        ignoreGestures: true,
                      ),
                    ),
                  ],
                ),
              ),

            if (widget.model.rating.isNotEmpty) const SizedBox(height: 16),

            // 反馈内容卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusRegular,
              ),
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
                        t.common.feedbackContent,
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
                      borderRadius: AppRadius.borderRadiusMedium,
                    ),
                    child: Text(
                      widget.model.body,
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

            const SizedBox(height: 16),

            // 回复列表卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusRegular,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.reply, color: colorScheme.secondary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        t.common.officialReply,
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
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: state.pageReplyList.isEmpty
                        ? SizedBox(
                            height: 120,
                            child: NoDataView(text: t.common.noReply),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: state.pageReplyList.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (BuildContext context, int index) {
                              FeedbackReplyModel replyModel =
                                  state.pageReplyList[index];
                              return _buildReplyItem(context, replyModel);
                            },
                          ),
                  ),
                ],
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
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(color: colorScheme.outline.withAlpha(51)),
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
                  borderRadius: AppRadius.borderRadiusSmall,
                ),
                child: Icon(
                  Icons.support_agent,
                  color: colorScheme.secondary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${t.chat.repliedAt} ${DateTimeHelper.lastTimeFmt(replyModel.createdAt)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(
                    context,
                    replyModel.statusDesc,
                  ).withAlpha(51),
                  borderRadius: AppRadius.borderRadiusSmall,
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
              borderRadius: AppRadius.borderRadiusSmall,
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
    if (status == t.main.processed) {
      return AppColors.iosGreen;
    } else if (status == t.common.loading) {
      return AppColors.iosOrange;
    } else if (status == t.common.submitted) {
      return colorScheme.primary;
    }
    return colorScheme.onSurface;
  }
}
