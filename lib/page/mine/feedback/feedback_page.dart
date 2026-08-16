import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/async_state_view.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/store/model/feedback_model.dart';
import 'package:imboy/store/api/attachment_api.dart' show AttachmentApi;
import 'package:imboy/store/api/feedback_api.dart' show FeedbackApi;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:feedback/feedback.dart';
import 'package:imboy/page/mine/feedback/feedback_provider.dart';

/// 意见反馈页面 - 像素级对齐 iOS 设置风
class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  int page = 1;
  final int size = 1000;
  bool _isInitialized = false;
  bool _isSubmittingFeedback = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
  }

  Future<void> _initData() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await _loadFeedbackList();
  }

  /// 加载反馈列表（走 provider.loadData，统一维护 isLoading/error）
  /// 本页无分页 UI（size=1000 一次拉全量），page 恒为 1；
  /// 提交成功后的刷新必须从第 1 页重取，否则新提交的反馈看不到。
  Future<void> _loadFeedbackList() async {
    await ref
        .read(feedbackPageProvider.notifier)
        .loadData(page: page, size: size);
  }

  void _showFeedbackEditor() {
    if (_isSubmittingFeedback) return;
    BetterFeedback.of(context).show((UserFeedback feedback) async {
      if (feedback.text.isEmpty) {
        AppLoading.showError(t.common.feedbackContentRequired);
        return;
      }
      setState(() => _isSubmittingFeedback = true);
      try {
        // 截图字节可能无法解码：强解包会抛异常且本方法只有 try/finally
        // 无 catch，会静默逃逸让用户得不到任何反馈。显式空判并明确报错。
        final img.Image? image = img.decodeImage(feedback.screenshot);
        if (image == null) {
          AppLoading.showError(t.common.operationFailedAgainLater);
          return;
        }
        final result = img.encodeJpg(image, quality: 70);
        await AttachmentApi.uploadBytesViaPresignCompat(
          "feedback",
          result,
          (Map<String, dynamic> resp, String uri) async {
            FeedbackApi p = FeedbackApi();
            // 编辑器无类型/评分 UI 时 extra 里没有对应键，传 '' 会撞服务端
            // feedback 表 CHECK 约束（type 仅 bugReport/featureRequest，
            // rating 仅 bad/neutral/good）导致 INSERT 必失败；省略键让服务端
            // 回落合法默认值（type=bugReport / rating=neutral）。
            Map<String, dynamic> data = {
              'contact_detail': feedback.extra?['contact_detail'] ?? '',
              'description': feedback.text,
              'screenshot': [uri],
            };
            final rating = feedback.extra?['rating'];
            if (rating != null && rating.toString().isNotEmpty) {
              data['rating'] = rating.toString();
            }
            final feedbackType = feedback.extra?['feedback_type'];
            if (feedbackType != null && feedbackType.toString().isNotEmpty) {
              data['type'] = feedbackType
                  .toString()
                  .split('.')
                  .last
                  .replaceAll('_', ' ');
            }
            if (await p.add(data)) {
              AppLoading.showSuccess(t.common.feedbackSuccessMsg);
              await _loadFeedbackList();
            } else {
              AppLoading.showError(t.common.tipFailed);
            }
          },
          (Object e) {
            // BUG#133 诊断：uploadBytesViaPresignCompat 的 on Object catch
            // 会把回调内任何异常静默吞掉（errorCallback 空函数），导致
            // add=true 后 _loadFeedbackList 未执行的异常无痕。先打日志定位。
            debugPrint('FEEDBACK_SUBMIT_CALLBACK_ERROR: $e');
          },
          process: false,
        );
      } finally {
        if (mounted) setState(() => _isSubmittingFeedback = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedbackPageProvider);
    final brightness = Theme.of(context).brightness;

    return IosPageTemplate(
      title: t.common.feedback,
      useLargeTitle: false,
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showFeedbackEditor,
          child: const Icon(CupertinoIcons.add, size: 22),
        ),
      ],
      slivers: [
        // 说明 Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.regular,
              AppSpacing.medium,
              AppSpacing.regular,
              0,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.regular),
              decoration: BoxDecoration(
                color: AppColors.getIosBlue(brightness).withValues(alpha: 0.1),
                borderRadius: AppRadius.borderRadiusCell,
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.heart_circle,
                    color: AppColors.getIosBlue(brightness),
                    size: 32,
                  ),
                  AppSpacing.horizontalMedium,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.common.feedback,
                          style: context.textStyle(
                            FontSizeType.subheadline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.common.feedbackSlogan,
                          style: context.textStyle(
                            FontSizeType.footnote,
                            color: AppColors.iosGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.regular,
                    ),
                    color: AppColors.getIosBlue(brightness),
                    borderRadius: BorderRadius.circular(20),
                    onPressed: _showFeedbackEditor,
                    child: Text(
                      t.common.newFeedback,
                      style: context.textStyle(
                        FontSizeType.footnote,
                        color: AppColors.lightSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 历史列表 Section：加载 / 错误(可重试) / 空 / 数据 四态收敛为三态组件
        SliverFillRemaining(
          child: AsyncStateView(
            isLoading: state.isLoading,
            error: state.error,
            isEmpty: state.itemList.isEmpty,
            onRetry: _loadFeedbackList,
            emptyText: t.common.noHistory,
            emptyIcon: CupertinoIcons.envelope,
            child: ImBoySettingsSection(
              header: Text(t.common.feedbackHistory.toUpperCase()),
              children: state.itemList.asMap().entries.map((entry) {
                return _buildSlidableItem(
                  context,
                  entry.value,
                  entry.key,
                  brightness,
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlidableItem(
    BuildContext context,
    FeedbackModel model,
    int index,
    Brightness brightness,
  ) {
    return Slidable(
      key: ValueKey(model.feedbackId),
      endActionPane: ActionPane(
        extentRatio: 0.25,
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _showDeleteDialog(context, model, index),
            backgroundColor: AppColors.getIosRed(brightness),
            foregroundColor: AppColors.onPrimary,
            icon: CupertinoIcons.delete,
            label: t.common.buttonDelete,
          ),
        ],
      ),
      child: ImBoySettingsTile(
        onTap: () => context.push(
          '/feedback/detail/${model.feedbackId}',
          extra: {'model': model},
        ),
        title: Text(
          model.body,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textStyle(FontSizeType.medium),
        ),
        subtitle: Row(
          children: [
            Text(
              DateTimeHelper.lastTimeFmt(model.createdAt),
              style: context.textStyle(
                FontSizeType.small,
                color: AppColors.iosGray,
              ),
            ),
            AppSpacing.horizontalSmall,
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.iosGray,
                shape: BoxShape.circle,
              ),
            ),
            AppSpacing.horizontalSmall,
            Text(
              model.statusDesc,
              style: context.textStyle(
                FontSizeType.small,
                color: _getStatusColor(model.status, brightness),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.iosGray.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                model.type,
                style: context.textStyle(
                  FontSizeType.tiny,
                  color: AppColors.iosGray,
                ),
              ),
            ),
            AppSpacing.horizontalSmall,
            const CupertinoListTileChevron(),
          ],
        ),
      ),
    );
  }

  /// 按后端状态码取色，避免与本地化后的 [FeedbackModel.statusDesc] 文案比较
  /// （多语言下文案会变化，字符串比较必然落 default 失效）。
  /// 状态码语义见 [FeedbackModel.statusDesc]：1 待回复 2 已回复 3 已完结
  Color _getStatusColor(int status, Brightness brightness) {
    switch (status) {
      case 3:
        return AppColors.getIosGreen(brightness);
      case 1:
        return AppColors.getIosOrange(brightness);
      default:
        return AppColors.getIosBlue(brightness);
    }
  }

  void _showDeleteDialog(BuildContext context, FeedbackModel model, int index) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.common.confirmDelete),
        content: Text(t.common.sureDeleteData),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              if (await ref
                  .read(feedbackPageProvider.notifier)
                  .remove(model.feedbackId)) {
                final newList = List<FeedbackModel>.from(
                  ref.read(feedbackPageProvider).itemList,
                )..removeWhere((e) => e.feedbackId == model.feedbackId);
                ref.read(feedbackPageProvider.notifier).setItemList(newList);
                AppLoading.showSuccess(t.common.tipSuccess);
              } else {
                AppLoading.showError(t.common.tipFailed);
              }
            },
            child: Text(t.common.buttonDelete),
          ),
        ],
      ),
    );
  }
}
