/// 坐席会话页（§12.5.1 / CSM-02）
///
/// claimed/active 会话的企业会话通道：
/// - 历史 after_id 增量 + 下拉刷新；发送（幂等 client_msg_id）；delivery
///   ACK（delivery-only，不删真源）；企业附件 presign→PUT→confirm 上传与
///   content 代理预览（EB-D06，禁止个人 C2C/attachment fallback）；
/// - transfer：目标只列同 Org active customer_service identity；CAS +
///   409 冲突刷新（不做乐观伪成功）；
/// - close：确认弹层 + 可选 reason（白名单/限长）；关闭后输入禁用 →
///   评分等待状态展示（评分是访客侧动作，坐席端只显示 rating 状态）；
/// - suspend / assignment 结束 / seat disabled / offboarding：下一个失败
///   请求即清写入口、停后台发送、显示可解释只读态（cs_seat_gate 语义扩展）。
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_gate.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_session_machine.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_actions.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_flow.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class CsSessionPage extends StatefulWidget {
  final String orgId;
  final String sessionId;

  /// 会话绑定的企业会话（服务端 detail 可补齐；持续缺失时显示可解释
  /// 「通道不可用」态，不 fallback 个人 IM）。
  final String conversationId;
  final String identityId;
  final String contactName;

  const CsSessionPage({
    super.key,
    required this.orgId,
    required this.sessionId,
    this.conversationId = '',
    this.identityId = '',
    this.contactName = '',
  });

  @override
  State<CsSessionPage> createState() => _CsSessionPageState();
}

class _CsSessionPageState extends State<CsSessionPage> {
  late final CsSessionFlow _flow;
  final TextEditingController _input = TextEditingController();
  final CsApi _csApi = CsApi();

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _flow = CsSessionFlow(
      orgId: widget.orgId,
      sessionId: widget.sessionId,
      conversationId: widget.conversationId,
      identityId: widget.identityId,
      contactMaskedName: csMaskContactName(widget.contactName),
    );
    _bootstrap();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _busy = true);
    await _flow.refreshSessionState();
    await _flow.loadIncremental();
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _refresh() async {
    await _flow.refreshSessionState();
    await _flow.loadIncremental();
    if (mounted) {
      setState(() {});
    }
  }

  void _toast(String msg) => AppLoading.showToast(msg);

  /// 失败分类 → 文案（仅 conflict 在 flow 内已刷新真实状态）。
  void _toastFailure(CsSeatFailureKind kind) {
    final t = context.t.customerService;
    switch (kind) {
      case CsSeatFailureKind.conflict:
        _toast(t.transferConflict);
      case CsSeatFailureKind.suspended:
        _toast(t.claimForbidden);
      case CsSeatFailureKind.offboarding:
        _toast(t.claimOffboardingRequired);
      case CsSeatFailureKind.other:
        _toast(t.claimFailed);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    final ok = await _flow.send(text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _input.clear();
    } else {
      _toast(context.t.customerService.claimFailed);
    }
  }

  Future<void> _attach() async {
    if (_busy || !_flow.machine.canSend) return;
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty) return;
    final picked = files.single;
    final path = picked.path;
    if (path == null) return;
    final file = File(path);
    final name = picked.name;
    final mime = name.endsWith('.txt')
        ? 'text/plain'
        : 'application/octet-stream';
    setState(() => _busy = true);
    try {
      final assetId = await _flow.uploadAsset(
        fileName: name,
        mime: mime,
        size: file.lengthSync(),
        byteStream: file.openRead(),
      );
      if (!mounted) return;
      if (assetId.isEmpty) {
        _toast(context.t.customerService.claimFailed);
        return;
      }
      final ok = await _flow.send('[$name]');
      if (!mounted) return;
      if (ok) {
        _toast(context.t.customerService.attachUploaded);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _viewAsset(EnterpriseMessage message) async {
    try {
      final preview = await _flow.viewAsset(message.assetId);
      if (!mounted) return;
      // null = 已降级（flow 已同步状态机）：刷新 UI 呈现只读态，不弹预览
      if (preview == null) {
        setState(() {});
        return;
      }
      final t = context.t.customerService;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(t.attachPreviewTitle),
          content: SingleChildScrollView(child: Text(preview)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.t.common.buttonOk),
            ),
          ],
        ),
      );
    } on EnterpriseApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = '${e.message} (code=${e.code})');
      if (e.isForbidden) _flow.machine.markSuspended();
      if (e.isOffboardingRequired) _flow.machine.markOffboarding();
    }
  }

  // ==================== 转接 ====================

  Future<void> _openTransfer() async {
    final t = context.t.customerService;
    try {
      // 转接目标 = api-surface-freeze 权威端点（同 Org 坐席最小投影，
      // 服务端排除调用者本人；不复用治理 identity 列表）。
      final page = await _csApi.transferTargets(
        widget.orgId,
        limit: kCsQueuePageSize,
      );
      if (!mounted) return;
      final targets = csTransferTargetOptions(
        page.items,
        excludeIdentityId: _flow.identityId,
      );
      if (targets.isEmpty) {
        _toast(t.transferEmpty);
        return;
      }
      final picked = await showDialog<CsTransferTarget>(
        context: context,
        builder: (_) => SimpleDialog(
          title: Text(t.transferTitle),
          children: [
            for (final target in targets)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(target),
                child: ListTile(
                  leading: const Icon(CupertinoIcons.person_2),
                  title: Text(
                    target.displayName.isEmpty
                        ? target.identityId
                        : target.displayName,
                  ),
                  subtitle: Text(
                    target.available ? t.targetAvailable : t.targetBusy,
                  ),
                ),
              ),
          ],
        ),
      );
      if (picked == null || !mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(t.transferConfirmTitle),
          content: Text(
            t.transferConfirmBody(
              name: picked.displayName.isEmpty
                  ? picked.identityId
                  : picked.displayName,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.t.common.buttonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(t.transferAction),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _busy = true);
      final failure = await _flow.transferTo(picked.identityId);
      if (!mounted) return;
      setState(() => _busy = false);
      if (failure == null) {
        _toast(t.transferSuccess);
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      } else if (failure != CsSeatFailureKind.conflict) {
        _toastFailure(failure);
      } else {
        _toastFailure(CsSeatFailureKind.conflict);
      }
    } on CsApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = '${e.message} (code=${e.code})');
      if (e.isForbidden) _flow.machine.markSuspended();
      if (e.isOffboardingRequired) _flow.machine.markOffboarding();
    }
  }

  // ==================== 关闭 ====================

  Future<void> _openClose() async {
    final t = context.t.customerService;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.closeTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.closeBody),
            const SizedBox(height: AppSpacing.medium),
            TextField(
              controller: reasonController,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: t.closeReasonLabel,
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.t.common.buttonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.closeAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final reason = csSanitizeCloseReason(reasonController.text);
    setState(() => _busy = true);
    final failure = await _flow.closeSession(reason: reason);
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure == null) {
      _toast(t.closeSuccess);
    } else {
      _toast(
        failure == CsSeatFailureKind.conflict ? t.closeConflict : t.closeFailed,
      );
    }
  }

  // ==================== UI ====================

  String? _explainText() {
    final t = context.t.customerService;
    switch (_flow.machine.phase) {
      case CsSeatSessionPhase.readOnlySuspended:
        return t.readOnlySuspended;
      case CsSeatSessionPhase.offboardingRequired:
        return t.offboardingRequired;
      case CsSeatSessionPhase.closed:
        return t.closedReadonly;
      case CsSeatSessionPhase.rated:
        return t.ratedReadonly;
      case CsSeatSessionPhase.writable:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.customerService;
    final machine = _flow.machine;
    final explain = _explainText();
    final canWrite = machine.canSend;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.contactName.isEmpty
              ? t.sessionTitle
              : csMaskContactName(widget.contactName),
        ),
        actions: [
          if (canWrite) ...[
            IconButton(
              onPressed: _busy ? null : _openTransfer,
              tooltip: t.transferAction,
              icon: const Icon(CupertinoIcons.arrow_2_squarepath),
            ),
            IconButton(
              onPressed: _busy ? null : _openClose,
              tooltip: t.closeAction,
              icon: const Icon(CupertinoIcons.xmark_circle),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (explain != null)
            Material(
              color: AppColors.warning.withValues(alpha: 0.15),
              child: ListTile(
                dense: true,
                leading: Icon(
                  CupertinoIcons.lock,
                  color: AppColors.warning,
                  size: AppSizes.iconSizeSmall,
                ),
                title: Text(
                  explain,
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ),
          if (_flow.conversationId.isEmpty)
            ListTile(
              dense: true,
              leading: const Icon(CupertinoIcons.info_circle),
              title: Text(t.channelUnavailable),
            ),
          // 评分状态（访客侧动作；坐席端只展示状态，不代评）
          _buildRatingBanner(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.small),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkError
                      : AppColors.lightError,
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _messagesList(),
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  onPressed: canWrite && !_busy ? _attach : null,
                  tooltip: t.attachAction,
                  icon: const Icon(CupertinoIcons.paperclip),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.small,
                    ),
                    child: TextField(
                      controller: _input,
                      enabled: canWrite && !_busy,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(hintText: t.inputHint),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: canWrite && !_busy ? _send : null,
                  tooltip: t.seatLabel,
                  icon: const Icon(CupertinoIcons.paperplane_fill),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBanner() {
    final machine = _flow.machine;
    final rating = _flow.detail?.rating ?? 0;
    if (machine.phase == CsSeatSessionPhase.rated && rating > 0) {
      return ListTile(
        dense: true,
        leading: const Icon(
          CupertinoIcons.star_fill,
          color: AppColors.iosOrange,
        ),
        title: Text(
          context.t.customerService.ratingScoreLabel(score: rating),
          style: context.textStyle(FontSizeType.footnote),
        ),
        subtitle: Text(
          context.t.customerService.ratedTitle,
          style: context.textStyle(
            FontSizeType.caption2,
            color: AppColors.iosGray,
          ),
        ),
      );
    }
    if (machine.phase == CsSeatSessionPhase.closed ||
        machine.phase == CsSeatSessionPhase.rated) {
      return ListTile(
        dense: true,
        leading: const Icon(CupertinoIcons.hourglass, color: AppColors.iosGray),
        title: Text(
          context.t.customerService.waitingRatingTitle,
          style: context.textStyle(FontSizeType.footnote),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _messagesList() {
    if (_busy && _flow.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_flow.messages.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 96),
            child: Center(
              child: Text(
                context.t.customerService.queuedEmptyTitle,
                style: context.textStyle(
                  FontSizeType.footnote,
                  color: AppColors.iosGray,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _flow.messages.length,
      itemBuilder: (context, index) {
        final m = _flow.messages[index];
        final actor = csSenderActorView(
          m,
          contactMaskedName: csMaskContactName(widget.contactName),
        );
        return Align(
          alignment: actor.isSeat
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.medium,
              vertical: AppSpacing.tiny,
            ),
            padding: const EdgeInsets.all(AppSpacing.medium),
            constraints: const BoxConstraints(
              maxWidth: AppSizes.messageBubbleMaxWidth,
            ),
            decoration: BoxDecoration(
              color: actor.isSeat
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.borderRadiusMedium,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(m.content),
                // sender-actor 展示：业务身份名（非自然人好友，EB-D03/D05）
                Text(
                  actor.label,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (m.assetId.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _viewAsset(m),
                    icon: const Icon(
                      CupertinoIcons.paperclip,
                      size: AppSizes.iconSizeXSmall,
                    ),
                    label: Text(context.t.customerService.attachAction),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
