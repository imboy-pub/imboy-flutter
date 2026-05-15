import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/store/model/feedback_model.dart';
import 'package:imboy/store/api/attachment_api.dart' show AttachmentApi;
import 'package:imboy/store/api/feedback_api.dart' show FeedbackApi;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
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
    final list = await ref.read(feedbackPageProvider.notifier).page(page: page, size: size);
    ref.read(feedbackPageProvider.notifier).setItemList(list);
    page = page + 1;
  }

  void _showFeedbackEditor() {
    if (_isSubmittingFeedback) return;
    BetterFeedback.of(context).show((UserFeedback feedback) async {
      if (feedback.text.isEmpty) {
        EasyLoading.showError(t.common.feedbackContentRequired);
        return;
      }
      setState(() => _isSubmittingFeedback = true);
      try {
        img.Image image = img.decodeImage(feedback.screenshot)!;
        final result = img.encodeJpg(image, quality: 70);
        await AttachmentApi.uploadBytes("feedback", result, (Map<String, dynamic> resp, String uri) async {
          FeedbackApi p = FeedbackApi();
          Map<String, dynamic> data = {
            'rating': feedback.extra?['rating'] ?? '',
            'type': (feedback.extra?['feedback_type'] ?? '').toString().split('.').last.replaceAll('_', ' '),
            'contact_detail': feedback.extra?['contact_detail'] ?? '',
            'description': feedback.text,
            'screenshot': [uri],
          };
          if (await p.add(data)) {
            EasyLoading.showSuccess(t.common.feedbackSuccessMsg);
            _isInitialized = false;
            _initData();
          } else EasyLoading.showError(t.common.tipFailed);
        }, (_) {}, process: false);
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
        )
      ],
      slivers: [
        // 说明 Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getIosBlue(brightness).withValues(alpha: 0.1),
                borderRadius: AppRadius.borderRadiusCell,
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.heart_circle, color: AppColors.getIosBlue(brightness), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.common.feedback, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(t.common.feedbackSlogan, style: const TextStyle(fontSize: 13, color: AppColors.iosGray)),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: AppColors.getIosBlue(brightness),
                    borderRadius: BorderRadius.circular(20),
                    onPressed: _showFeedbackEditor,
                    child: Text(t.common.newFeedback, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 历史列表 Section
        SliverToBoxAdapter(
          child: ImBoySettingsSection(
            header: Text(t.common.feedbackHistory.toUpperCase()),
            children: state.itemList.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No history')),
                    )
                  ]
                : state.itemList.asMap().entries.map((entry) {
                    return _buildSlidableItem(context, entry.value, entry.key, brightness);
                  }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSlidableItem(BuildContext context, FeedbackModel model, int index, Brightness brightness) {
    return Slidable(
      key: ValueKey(model.feedbackId),
      endActionPane: ActionPane(
        extentRatio: 0.25,
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _showDeleteDialog(context, model, index),
            backgroundColor: AppColors.getIosRed(brightness),
            foregroundColor: Colors.white,
            icon: CupertinoIcons.delete,
            label: t.common.buttonDelete,
          ),
        ],
      ),
      child: ImBoySettingsTile(
        onTap: () => context.push('/feedback/detail/${model.feedbackId}', extra: {'model': model}),
        title: Text(model.body, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
        subtitle: Row(
          children: [
            Text(DateTimeHelper.lastTimeFmt(model.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.iosGray)),
            const SizedBox(width: 8),
            Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.iosGray, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(model.statusDesc, style: TextStyle(fontSize: 12, color: _getStatusColor(model.statusDesc))),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.iosGray.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(model.type, style: const TextStyle(fontSize: 10, color: AppColors.iosGray)),
            ),
            const SizedBox(width: 8),
            const CupertinoListTileChevron(),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '已处理': return AppColors.iosGreen;
      case '处理中': return AppColors.iosOrange;
      default: return AppColors.iosBlue;
    }
  }

  void _showDeleteDialog(BuildContext context, FeedbackModel model, int index) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.common.confirmDelete),
        content: Text(t.common.sureDeleteData),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: Text(t.common.buttonCancel)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              if (await ref.read(feedbackPageProvider.notifier).remove(model.feedbackId)) {
                final newList = List<FeedbackModel>.from(ref.read(feedbackPageProvider).itemList)..removeWhere((e) => e.feedbackId == model.feedbackId);
                ref.read(feedbackPageProvider.notifier).setItemList(newList);
                EasyLoading.showSuccess(t.common.tipSuccess);
              } else EasyLoading.showError(t.common.tipFailed);
            },
            child: Text(t.common.buttonDelete),
          ),
        ],
      ),
    );
  }
}
