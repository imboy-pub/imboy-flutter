import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/cell_pressable.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/store/model/feedback_model.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/store/api/attachment_api.dart' show AttachmentApi;
import 'package:imboy/store/api/feedback_api.dart' show FeedbackApi;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:feedback/feedback.dart';
import 'package:imboy/page/mine/feedback/feedback_provider.dart';

/// 意见反馈页面
class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  int page = 1;
  final int size = 1000;
  bool _isInitialized = false;

  // 防抖状态
  bool _isSubmittingFeedback = false;

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

    final list = await ref
        .read(feedbackPageProvider.notifier)
        .page(page: page, size: size);
    ref.read(feedbackPageProvider.notifier).setItemList(list);
    page = page + 1;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(feedbackPageProvider);

    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.common.feedback,
        rightDMActions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppRadius.borderRadiusMedium,
                onTap: _isSubmittingFeedback
                    ? null
                    : () {
                        BetterFeedback.of(context).show((
                          UserFeedback feedback,
                        ) async {
                          if (feedback.text.isEmpty) {
                            EasyLoading.showError(
                              t.common.feedbackContentRequired,
                            );
                            return;
                          }

                          // 防抖：设置提交状态
                          setState(() => _isSubmittingFeedback = true);

                          try {
                            img.Image image = img.decodeImage(
                              feedback.screenshot,
                            )!;
                            final result = img.encodeJpg(image, quality: 70);

                            await AttachmentApi.uploadBytes(
                              "feedback",
                              result,
                              (Map<String, dynamic> resp, String uri) async {
                                FeedbackApi p = FeedbackApi();
                                var type =
                                    feedback.extra?['feedback_type'] ?? '';
                                var rating = feedback.extra?['rating'] ?? '';

                                Map<String, dynamic> data = {
                                  'rating': rating,
                                  'type': type
                                      .toString()
                                      .split('.')
                                      .last
                                      .replaceAll('_', ' '),
                                  'contact_detail':
                                      feedback.extra?['contact_detail'] ?? '',
                                  'description': feedback.text,
                                  'screenshot': [uri],
                                };
                                bool res = await p.add(data);
                                if (res) {
                                  EasyLoading.showSuccess(
                                    t.common.feedbackSuccessMsg,
                                  );
                                  _initData(); // 刷新列表
                                } else {
                                  EasyLoading.showError(t.common.tipFailed);
                                }
                              },
                              (Error error) {
                                if (kDebugMode) {
                                  debugPrint(
                                    "> on upload error: ${error.runtimeType}",
                                  );
                                }
                              },
                              process: false,
                            );
                          } finally {
                            // 恢复提交状态
                            if (mounted) {
                              setState(() => _isSubmittingFeedback = false);
                            }
                          }
                        });
                      },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(51),
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                  child: Icon(Icons.add, color: colorScheme.primary, size: 24),
                ),
              ),
            ),
          ),
        ],
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

            // 反馈说明卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.borderRadiusRegular,
              ),
              child: Row(
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
                          t.common.feedback,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.common.feedbackSlogan,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withAlpha(179),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: AppRadius.borderRadiusSmall,
                      onTap: _isSubmittingFeedback
                          ? null
                          : () {
                              BetterFeedback.of(context).show((
                                UserFeedback feedback,
                              ) async {
                                if (feedback.text.isEmpty) {
                                  EasyLoading.showError(
                                    t.common.feedbackContentRequired,
                                  );
                                  return;
                                }

                                // 防抖：设置提交状态
                                setState(() => _isSubmittingFeedback = true);

                                try {
                                  img.Image image = img.decodeImage(
                                    feedback.screenshot,
                                  )!;
                                  final result = img.encodeJpg(
                                    image,
                                    quality: 70,
                                  );

                                  await AttachmentApi.uploadBytes(
                                    "feedback",
                                    result,
                                    (
                                      Map<String, dynamic> resp,
                                      String uri,
                                    ) async {
                                      FeedbackApi p = FeedbackApi();
                                      var type =
                                          feedback.extra?['feedback_type'] ??
                                          '';
                                      var rating =
                                          feedback.extra?['rating'] ?? '';

                                      Map<String, dynamic> data = {
                                        'rating': rating,
                                        'type': type
                                            .toString()
                                            .split('.')
                                            .last
                                            .replaceAll('_', ' '),
                                        'contact_detail':
                                            feedback.extra?['contact_detail'] ??
                                            '',
                                        'description': feedback.text,
                                        'screenshot': [uri],
                                      };
                                      bool res = await p.add(data);
                                      if (res) {
                                        EasyLoading.showSuccess(
                                          t.common.feedbackSuccessMsg,
                                        );
                                        _initData();
                                      } else {
                                        EasyLoading.showError(
                                          t.common.tipFailed,
                                        );
                                      }
                                    },
                                    (Error error) {
                                      if (kDebugMode) {
                                        debugPrint(
                                          "> on upload error: ${error.runtimeType}",
                                        );
                                      }
                                    },
                                    process: false,
                                  );
                                } finally {
                                  // 恢复提交状态
                                  if (mounted) {
                                    setState(
                                      () => _isSubmittingFeedback = false,
                                    );
                                  }
                                }
                              });
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: AppRadius.borderRadiusSmall,
                        ),
                        child: Text(
                          t.common.newFeedback,
                          style: TextStyle(
                            color: colorScheme.onPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 反馈列表卡片
            Container(
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
                      Icon(Icons.history, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        t.common.feedbackHistory,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 反馈列表
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.6,
                    ),
                    child: state.itemList.isEmpty
                        ? SizedBox(
                            height: 200,
                            child: NoDataView(text: t.common.noData),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: state.itemList.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (BuildContext context, int index) {
                              FeedbackModel model = state.itemList[index];
                              return Slidable(
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
                                      backgroundColor: AppColors.getIosRed(
                                        Theme.of(context).brightness,
                                      ),
                                      foregroundColor: Colors.white,
                                      borderRadius:
                                          AppRadius.borderRadiusMedium,
                                      onPressed: (_) async {
                                        _showDeleteDialog(
                                          context,
                                          model,
                                          index,
                                        );
                                      },
                                      label: t.common.buttonDelete,
                                      spacing: 1,
                                    ),
                                  ],
                                ),
                                child: _buildFeedbackItem(context, model),
                              );
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

  /// 构建反馈项组件
  Widget _buildFeedbackItem(BuildContext context, FeedbackModel model) {
    final colorScheme = Theme.of(context).colorScheme;

    // ClipRRect 让 CellPressable 按下高亮按卡片圆角裁切，避免溢出
    return ClipRRect(
      borderRadius: AppRadius.borderRadiusMedium,
      child: CellPressable(
        onTap: () {
          context.push(
            '/feedback/detail/${model.feedbackId}',
            extra: {'model': model},
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: AppRadius.borderRadiusMedium,
            border: Border.all(color: colorScheme.outline.withAlpha(51)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题和状态
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withAlpha(128),
                      borderRadius: AppRadius.borderRadiusSmall,
                    ),
                    child: Text(
                      model.type,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        context,
                        model.statusDesc,
                      ).withAlpha(51),
                      borderRadius: AppRadius.borderRadiusSmall,
                    ),
                    child: Text(
                      model.statusDesc,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _getStatusColor(context, model.statusDesc),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 反馈内容（DESIGN.md §3.2：Body 16pt / w400，不用 w500 次强调）
              Text(
                model.body,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // 提交时间
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: colorScheme.onSurface.withAlpha(128),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${t.common.submittedAt} ${DateTimeHelper.lastTimeFmt(model.createdAt)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withAlpha(179),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: colorScheme.onSurface.withAlpha(128),
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
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

  /// 显示删除确认对话框
  void _showDeleteDialog(BuildContext context, FeedbackModel model, int index) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.common.confirmDelete),
        content: Text(t.common.sureDeleteData),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              bool res = await ref
                  .read(feedbackPageProvider.notifier)
                  .remove(model.feedbackId);
              if (res) {
                final newList = List<FeedbackModel>.from(
                  ref.read(feedbackPageProvider).itemList,
                );
                newList.removeWhere((e) => e.feedbackId == model.feedbackId);
                ref.read(feedbackPageProvider.notifier).setItemList(newList);
                EasyLoading.showSuccess(t.common.tipSuccess);
              } else {
                EasyLoading.showError(t.common.tipFailed);
              }
            },
            child: Text(t.common.buttonDelete),
          ),
        ],
      ),
    );
  }
}
