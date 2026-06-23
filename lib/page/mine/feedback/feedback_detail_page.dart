import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_spacing.dart';
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
import 'package:imboy/theme/default/font_types.dart';

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
        padding: AppSpacing.allRegular,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.verticalSmall,

            // 反馈基本信息卡片
            Container(
              width: double.infinity,
              padding: AppSpacing.allLarge,
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
                        padding: AppSpacing.allMedium,
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
                      AppSpacing.horizontalRegular,
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
                              style: context.textStyle(
                                FontSizeType.large,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            AppSpacing.verticalTiny,
                            Text(
                              '${t.common.submittedAt} ${DateTimeHelper.lastTimeFmt(widget.model.createdAt)}',
                              style: context.textStyle(
                                FontSizeType.normal,
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
                          style: context.textStyle(
                            FontSizeType.normal,
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

                  AppSpacing.verticalLarge,

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
                                  AppSpacing.horizontalSmall,
                                  Text(
                                    t.chat.viewAttachments,
                                    style: context.textStyle(
                                      FontSizeType.normal,
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

            AppSpacing.verticalRegular,

            // 评分信息卡片（如果有评分）
            if (widget.model.rating.isNotEmpty)
              Container(
                width: double.infinity,
                padding: AppSpacing.allLarge,
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
                        AppSpacing.horizontalSmall,
                        Text(
                          t.chat.rating,
                          style: context.textStyle(
                            FontSizeType.medium,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        AppSpacing.horizontalMedium,
                        Text(
                          '${widget.model.rating} ${widget.model.ratingDesc}',
                          style: context.textStyle(
                            FontSizeType.normal,
                            color: colorScheme.onSurface.withAlpha(179),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.verticalMedium,
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

            if (widget.model.rating.isNotEmpty) AppSpacing.verticalRegular,

            // 反馈内容卡片
            Container(
              width: double.infinity,
              padding: AppSpacing.allLarge,
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
                      AppSpacing.horizontalSmall,
                      Text(
                        t.common.feedbackContent,
                        style: context.textStyle(
                          FontSizeType.medium,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.verticalRegular,
                  Container(
                    width: double.infinity,
                    padding: AppSpacing.allRegular,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withAlpha(128),
                      borderRadius: AppRadius.borderRadiusMedium,
                    ),
                    child: Text(
                      widget.model.body,
                      style: context
                          .textStyle(
                            FontSizeType.medium,
                            color: colorScheme.onSurface,
                          )
                          .copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),

            AppSpacing.verticalRegular,

            // 回复列表卡片
            Container(
              width: double.infinity,
              padding: AppSpacing.allLarge,
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
                      AppSpacing.horizontalSmall,
                      Text(
                        t.common.officialReply,
                        style: context.textStyle(
                          FontSizeType.medium,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.verticalRegular,

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
                                AppSpacing.verticalMedium,
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

            AppSpacing.verticalRegular,
          ],
        ),
      ),
    );
  }

  /// 构建回复项组件
  Widget _buildReplyItem(BuildContext context, FeedbackReplyModel replyModel) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: AppSpacing.allRegular,
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
              AppSpacing.horizontalSmall,
              Text(
                '${t.chat.repliedAt} ${DateTimeHelper.lastTimeFmt(replyModel.createdAt)}',
                style: context.textStyle(
                  FontSizeType.normal,
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
                  style: context.textStyle(
                    FontSizeType.small,
                    fontWeight: FontWeight.w500,
                    color: _getStatusColor(context, replyModel.statusDesc),
                  ),
                ),
              ),
            ],
          ),

          AppSpacing.verticalMedium,

          // 回复内容
          Container(
            width: double.infinity,
            padding: AppSpacing.allMedium,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withAlpha(51),
              borderRadius: AppRadius.borderRadiusSmall,
            ),
            child: Text(
              replyModel.body,
              style: context
                  .textStyle(
                    FontSizeType.subheadline,
                    color: colorScheme.onSurface,
                  )
                  .copyWith(height: 1.4),
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
