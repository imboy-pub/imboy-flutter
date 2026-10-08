import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/appeal_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// R-04.1：处置与申诉页。
/// 展示针对当前用户的处置动作（含申诉状态）+ 已提交的申诉与终审结果。
/// 主动通知依赖既有通知设施（未接入前用户从此页自助查看）。
class AppealPage extends StatefulWidget {
  const AppealPage({super.key});

  @override
  State<AppealPage> createState() => _AppealPageState();
}

class _AppealPageState extends State<AppealPage> {
  final AppealApi _api = AppealApi();
  final TextEditingController _reasonController = TextEditingController();

  List<Map<String, dynamic>> _actions = [];
  List<Map<String, dynamic>> _appeals = [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final actions = await _api.myActions();
      final appeals = await _api.myAppeals();
      if (!mounted) return;
      setState(() {
        _actions = actions;
        _appeals = appeals;
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submitAppeal(Map<String, dynamic> action) async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) return;
    setState(() => _submitting = true);
    final ok = await _api.create(
      actionId: (action['id'] as num? ?? 0).toInt(),
      reason: reason,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      _reasonController.clear();
      await _load();
    } else {
      _showToast(t.appeal.submitFailed);
    }
  }

  void _showAppealDialog(Map<String, dynamic> action) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return CupertinoAlertDialog(
          title: Text(t.appeal.dialogTitle),
          content: Column(
            children: [
              const SizedBox(height: AppSpacing.small),
              Text(
                action['reason']?.toString() ?? '',
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: AppColors.iosGray,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              CupertinoTextField(
                controller: _reasonController,
                placeholder: t.appeal.reasonPlaceholder,
                maxLines: 3,
                maxLength: 1000,
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: _submitting
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: Text(t.common.cancel),
            ),
            CupertinoDialogAction(
              isDefaultAction: _submitting ? false : true,
              onPressed: _submitting
                  ? null
                  : () async {
                      final navigator = Navigator.of(dialogContext);
                      await _submitAppeal(action);
                      navigator.pop();
                    },
              child: _submitting
                  ? const CupertinoActivityIndicator()
                  : Text(t.appeal.submit),
            ),
          ],
        );
      },
    );
  }

  void _showToast(String msg) {
    AppLoading.showToast(msg);
  }

  @override
  Widget build(BuildContext context) {
    return IosPageTemplate(
      title: t.appeal.title,
      useLargeTitle: false,
      slivers: [
        if (_loading)
          const SliverFillRemaining(
            child: Center(child: CupertinoActivityIndicator()),
          )
        else if (_error != null)
          // 错误态给人话文案 + 重试入口，不渲染 e.toString() 原始串。
          SliverFillRemaining(
            hasScrollBody: false,
            child: NoDataView(
              icon: CupertinoIcons.exclamationmark_circle,
              text: t.common.errorNetwork,
              onTop: _load,
            ),
          )
        else if (_actions.isEmpty && _appeals.isEmpty)
          // 双空合并为一个「一切正常」安心空态（图标传达"无处置"的
          // 正面语义），替代原先两行互不相关的「暂无xx记录」+ 大段空白。
          SliverFillRemaining(
            hasScrollBody: false,
            child: NoDataView(
              icon: CupertinoIcons.checkmark_seal_fill,
              iconColor: AppColors.getIosGreen(Theme.of(context).brightness),
              text: t.appeal.allClearTitle,
              description: t.appeal.allClearSubtitle,
            ),
          )
        else ...[
          // 单侧为空时该 section 整体收起（header + 空字条都不渲染），
          // 只展示有内容的一侧。
          if (_actions.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(t.appeal.actionsSection),
            ),
            SliverToBoxAdapter(child: _buildActionsCard()),
          ],
          if (_appeals.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(t.appeal.appealsSection),
            ),
            SliverToBoxAdapter(child: _buildAppealsCard()),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xLarge)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.medium,
        AppSpacing.regular,
        AppSpacing.small,
      ),
      child: Text(
        text,
        style: context.textStyle(
          FontSizeType.footnote,
          color: AppColors.iosGray,
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return CupertinoListSection.insetGrouped(
      separatorColor: AppColors.iosGray.withValues(alpha: 0.15),
      backgroundColor: AppColors.transparent,
      children: [
        for (final action in _actions)
          CupertinoListTile(
            title: Text(
              '${_actionLabel(action['action']?.toString() ?? '')} · ${action['reason'] ?? ''}',
              style: context.textStyle(FontSizeType.subheadline),
            ),
            additionalInfo: Text(
              action['appealed'] == true
                  ? t.appeal.appealedTag
                  : t.appeal.appealableTag,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosGray,
              ),
            ),
            trailing: action['appealed'] == true
                ? null
                : CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _showAppealDialog(action),
                    child: Text(t.appeal.submit),
                  ),
          ),
      ],
    );
  }

  Widget _buildAppealsCard() {
    return CupertinoListSection.insetGrouped(
      separatorColor: AppColors.iosGray.withValues(alpha: 0.15),
      backgroundColor: AppColors.transparent,
      children: [
        for (final appeal in _appeals)
          CupertinoListTile(
            title: Text(
              appeal['reason']?.toString() ?? '',
              style: context.textStyle(FontSizeType.subheadline),
            ),
            additionalInfo: Text(
              _appealStatusLabel(appeal['status']?.toString() ?? ''),
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosGray,
              ),
            ),
            subtitle: appeal['review_reason']?.toString().isNotEmpty == true
                ? Text(
                    appeal['review_reason'].toString(),
                    style: context.textStyle(
                      FontSizeType.footnote,
                      color: AppColors.iosGray,
                    ),
                  )
                : null,
          ),
      ],
    );
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'warning':
        return t.appeal.actionWarning;
      case 'group_mute':
        return t.appeal.actionGroupMute;
      case 'group_kick':
        return t.appeal.actionGroupKick;
      case 'reject':
        return t.appeal.actionReject;
      case 'account_restrict':
        return t.appeal.actionAccountRestrict;
      case 'content_removal':
        return t.appeal.actionContentRemoval;
      default:
        return action;
    }
  }

  String _appealStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return t.appeal.statusPending;
      case 'accepted':
        return t.appeal.statusAccepted;
      case 'rejected':
        return t.appeal.statusRejected;
      default:
        return status;
    }
  }
}
