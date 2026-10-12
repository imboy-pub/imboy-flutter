/// CS seat session: scoped history, visible reading acknowledgements and
/// authorized enterprise attachments. SSE is an invalidation hint; delivery
/// acknowledgements and visitor read receipts remain separate facts.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show ViewFocusEvent, ViewFocusState;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:mime/mime.dart' as mime;

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_gate.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_session_machine.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_actions.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_flow.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_seat_events_stream.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_timeline.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_preview_scope.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/modules/enterprise/infrastructure/enterprise_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/font_types.dart';

/// A resumed single-view host supplies the initial input-focus fact.
/// Once a view event exists, it takes precedence over the initial inference.
bool csHostViewFocused({
  required bool? eventFocused,
  required int currentViewId,
  required List<int> viewIds,
  required bool resumed,
}) =>
    resumed &&
    (eventFocused ?? (viewIds.length == 1 && viewIds.single == currentViewId));

class CsSessionPage extends StatefulWidget {
  final String orgId;
  final String sessionId;

  /// 会话绑定的企业会话（服务端 detail 可补齐；持续缺失时显示可解释
  /// 「通道不可用」态，不 fallback 个人 IM）。
  final String conversationId;
  final String identityId;

  /// Workspace 作用域（SSE 事件流 query；路由展示种子，非授权事实。
  /// 缺省由事件流经 seat-contexts 权威解析）。
  final String workspaceId;
  final String contactName;

  const CsSessionPage({
    super.key,
    required this.orgId,
    required this.sessionId,
    this.conversationId = '',
    this.identityId = '',
    this.workspaceId = '',
    this.contactName = '',
  });

  @override
  State<CsSessionPage> createState() => _CsSessionPageState();
}

class _CsSessionPageState extends State<CsSessionPage>
    with WidgetsBindingObserver {
  late CsSessionFlow _flow;
  late CsSeatEventsStream _events;
  final TextEditingController _input = TextEditingController();
  final CsApi _csApi = CsApi();
  final _inputFocus = FocusNode();
  final _user = UserRepoLocal.to;
  int _binding = 0;
  int _authGeneration = 0;
  String _uid = '';
  String _draftScope = '';
  final _previews = CsSessionPreviewScope();
  AppLifecycleState? _lifecycle;
  bool? _viewFocused;

  bool _busy = false;
  bool _sending = false;
  String? _error;

  final Map<String, Future<Uint8List?>> _assetBytesFutures =
      <String, Future<Uint8List?>>{};

  Future<Uint8List?> _cachedAssetBytes(String assetId) {
    return _assetBytesFutures.putIfAbsent(
      assetId,
      () => _flow.fetchAssetBytes(assetId),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _user.addListener(_authChanged);
    _inputFocus.addListener(_focusChanged);
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    _bind();
  }

  String _routeScope(CsSessionPage page) =>
      '${page.orgId}/${page.workspaceId}/${page.sessionId}/${page.conversationId}/${page.identityId}';

  bool _authCurrent() =>
      _uid.isNotEmpty &&
      !_user.isClearingSession &&
      _user.currentUid == _uid &&
      _user.isCurrentSession(_authGeneration);

  bool _scopeAlive(CsSessionFlow flow, int binding) =>
      mounted &&
      binding == _binding &&
      identical(flow, _flow) &&
      _authCurrent();

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  void _authChanged() {
    if (_uid == _user.currentUid &&
        _authGeneration == _user.sessionGeneration &&
        !_user.isClearingSession) {
      return;
    }
    _flow.dispose();
    _bind();
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(CsSessionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_routeScope(oldWidget) != _routeScope(widget)) {
      _flow.dispose();
      _bind();
    }
  }

  void _bind() {
    _previews.invalidate();
    final draftScope = '${_user.currentUid}/${_routeScope(widget)}';
    if (_draftScope != draftScope) _input.clear();
    _draftScope = draftScope;
    final binding = ++_binding, route = _routeScope(widget);
    _uid = _user.currentUid;
    _authGeneration = _user.sessionGeneration;
    _assetBytesFutures.clear();
    _busy = false;
    _sending = false;
    _error = null;
    _flow = CsSessionFlow(
      orgId: widget.orgId,
      sessionId: widget.sessionId,
      conversationId: widget.conversationId,
      identityId: widget.identityId,
      workspaceId: widget.workspaceId,
      contactMaskedName: csMaskContactName(widget.contactName),
      scopeCurrent: () =>
          binding == _binding && route == _routeScope(widget) && _authCurrent(),
      onChanged: () {
        if (mounted && binding == _binding) _repaint(_flow, binding);
      },
    );
    _events = CsSeatEventsStream(
      orgId: widget.orgId,
      workspaceId: widget.workspaceId,
    );
    if (_authCurrent()) {
      _flow.bindEvents(_events);
      _bootstrap();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _previews.dispose();
    _flow.dispose();
    _input.dispose();
    _user.removeListener(_authChanged);
    _inputFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (mounted) setState(() {});
    if (state == AppLifecycleState.resumed && _authCurrent()) _refresh();
  }

  @override
  void didChangeViewFocus(ViewFocusEvent event) {
    if (!mounted || event.viewId != View.of(context).viewId) return;
    setState(() => _viewFocused = event.state == ViewFocusState.focused);
  }

  Future<void> _bootstrap() async {
    final flow = _flow, binding = _binding;
    setState(() => _busy = true);
    await flow.refreshSessionState();
    if (!mounted || !_scopeAlive(flow, binding)) return;
    await flow.resyncReadState();
    if (!mounted || !_scopeAlive(flow, binding)) return;
    await flow.loadLatest();
    if (_scopeAlive(flow, binding)) {
      _busy = false;
      _repaint(flow, binding);
    }
  }

  Future<void> _refresh() async {
    final flow = _flow, binding = _binding;
    await flow.refreshSessionState();
    if (!mounted || !_scopeAlive(flow, binding)) return;
    await flow.resyncReadState();
    if (!mounted || !_scopeAlive(flow, binding)) return;
    await flow.refreshLoadedHistory();
    if (_scopeAlive(flow, binding)) _repaint(flow, binding);
  }

  void _repaint(CsSessionFlow flow, int binding) {
    if (!_scopeAlive(flow, binding)) return;
    if (flow.readRevoked) _previews.invalidate();
    setState(() {});
  }

  void _toast(String msg) => AppLoading.showToast(msg);

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
    final flow = _flow, binding = _binding;
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _sending = true;
    });
    final ok = await flow.send(text);
    if (!mounted || !_scopeAlive(flow, binding)) return;
    setState(() {
      _busy = false;
      _sending = false;
    });
    if (ok) {
      _input.clear();
    } else {
      final t = context.t.customerService;
      switch (_flow.lastFailureKind) {
        case CsSeatFailureKind.conflict:
          _toast(t.sendConflict);
        case CsSeatFailureKind.suspended:
        case CsSeatFailureKind.offboarding:
        // 横幅（readOnlySuspended/offboardingRequired）为权威可解释态。
        case CsSeatFailureKind.other:
        case null:
          _toast(t.sendFailed);
      }
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _attach() async {
    final flow = _flow, binding = _binding;
    if (_busy || !_flow.machine.canSend) return;
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty) return;
    if (!mounted || !_scopeAlive(flow, binding)) return;
    final picked = files.single;
    final path = picked.path;
    if (path == null) return;
    final file = File(path);
    final name = picked.name;
    // mime 探测：扩展名 + 魔数头部（后端按白名单校验，octet-stream 必 422）。
    final header = await _readFileHead(file);
    if (!mounted || !_scopeAlive(flow, binding)) return;
    final detected = mime.lookupMimeType(path, headerBytes: header);
    if (detected == null || detected.isEmpty) {
      _toast(context.t.customerService.attachUnsupportedType);
      return;
    }
    setState(() => _busy = true);
    try {
      // Confirmed assets and the stable client message id bind atomically on send.
      final bytes = await file.readAsBytes();
      if (!mounted || !_scopeAlive(flow, binding)) return;
      final assetId = await flow.uploadAsset(
        mime: detected,
        bytes: bytes,
        fileName: name,
      );
      if (!mounted || !_scopeAlive(flow, binding)) return;
      if (assetId.isEmpty) {
        setState(() => _busy = false);
        _toast(context.t.customerService.attachUploadFailed);
        return;
      }
      final ok = await flow.send('', assetIds: [assetId]);
      if (!mounted || !_scopeAlive(flow, binding)) return;
      setState(() => _busy = false);
      if (ok) {
        _toast(context.t.customerService.attachUploaded);
      } else {
        final t = context.t.customerService;
        if (_flow.lastFailureKind == CsSeatFailureKind.conflict) {
          _toast(t.sendConflict);
        } else if (_flow.lastFailureKind == null) {
          _toast(t.attachUploadFailed);
        }
        // suspended/offboarding：降级横幅为权威可解释态。
        if (mounted) {
          setState(() {});
        }
      }
    } on Object {
      if (!mounted || !_scopeAlive(flow, binding)) return;
      setState(() => _busy = false);
      _toast(context.t.customerService.attachUploadFailed);
    }
  }

  /// 读文件头部若干字节供魔数探测（不足则整读）。
  Future<Uint8List> _readFileHead(File file) async {
    final len = await file.length();
    final take = len > 64 ? 64 : len;
    if (take <= 0) return Uint8List(0);
    final raf = await file.open(mode: FileMode.read);
    try {
      final data = await raf.read(take);
      return data;
    } finally {
      await raf.close();
    }
  }

  /// Attachments always use the authorized content proxy, including closed sessions.
  Future<void> _viewAsset(CsMessageAsset asset) async {
    final flow = _flow, binding = _binding;
    try {
      await _previews.show(
        context: context,
        asset: asset,
        loadBytes: () => _cachedAssetBytes(asset.id),
        isCurrent: () => _scopeAlive(flow, binding) && !flow.readRevoked,
      );
      if (_scopeAlive(flow, binding)) _repaint(flow, binding);
    } on EnterpriseApiException catch (e) {
      if (!mounted || !_scopeAlive(flow, binding)) return;
      setState(() => _error = '${e.message} (code=${e.code})');
      if (e.isForbidden) _flow.machine.markSuspended();
      if (e.isOffboardingRequired) _flow.machine.markOffboarding();
    }
  }

  Future<void> _openTransfer() async {
    final flow = _flow, binding = _binding;
    final t = context.t.customerService;
    try {
      // Transfer targets use the scoped authoritative seat endpoint.
      final page = await _csApi.transferTargets(
        widget.orgId,
        limit: kCsQueuePageSize,
      );
      if (!mounted || !_scopeAlive(flow, binding)) return;
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
      if (picked == null || !mounted || !_scopeAlive(flow, binding)) return;
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
      if (confirmed != true || !mounted || !_scopeAlive(flow, binding)) return;
      setState(() => _busy = true);
      final failure = await flow.transferTo(picked.identityId);
      if (!mounted || !_scopeAlive(flow, binding)) return;
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
      if (!mounted || !_scopeAlive(flow, binding)) return;
      setState(() => _error = '${e.message} (code=${e.code})');
      if (e.isForbidden) _flow.machine.markSuspended();
      if (e.isOffboardingRequired) _flow.machine.markOffboarding();
    }
  }

  Future<void> _openClose() async {
    final flow = _flow, binding = _binding;
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
    if (confirmed != true || !mounted || !_scopeAlive(flow, binding)) return;
    final reason = csSanitizeCloseReason(reasonController.text);
    setState(() => _busy = true);
    final failure = await flow.closeSession(reason: reason);
    if (!mounted || !_scopeAlive(flow, binding)) return;
    setState(() => _busy = false);
    if (failure == null) {
      _toast(t.closeSuccess);
    } else {
      _toast(
        failure == CsSeatFailureKind.conflict ? t.closeConflict : t.closeFailed,
      );
    }
  }

  String? _explainText() {
    final t = context.t.customerService;
    switch (_flow.machine.phase) {
      case CsSeatSessionPhase.readOnlySuspended:
        return t.readOnlySuspended;
      case CsSeatSessionPhase.offboardingRequired:
        return t.offboardingRequired;
      case CsSeatSessionPhase.transferredAway:
        return t.transferredAway;
      case CsSeatSessionPhase.closed:
        return t.closedReadonly;
      case CsSeatSessionPhase.rated:
        return t.ratedReadonly;
      case CsSeatSessionPhase.writable:
        return null;
    }
  }

  /// Only server read-state supplies the badge; unknown state is hidden.
  Widget _unreadBadge() {
    final unread = _flow.unreadCount;
    return _flow.machine.shouldPoll && unread != null && unread > 0
        ? CsUnreadBadge(count: unread)
        : const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.customerService;
    final machine = _flow.machine;
    final explain = _explainText();
    final canWrite = _authCurrent() && !_flow.readRevoked && machine.canSend;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.contactName.isEmpty
                    ? t.sessionTitle
                    : csMaskContactName(widget.contactName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _unreadBadge(),
          ],
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
                      focusNode: _inputFocus,
                      enabled: canWrite && !_busy,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(hintText: t.inputHint),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: canWrite && !_busy ? _send : null,
                  tooltip: _sending
                      ? context.t.chat.sending
                      : context.t.chat.send,
                  icon: _sending
                      ? const CircularProgressIndicator()
                      : const Icon(
                          CupertinoIcons.paperplane_fill,
                          color: AppColors.primary,
                        ),
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

  bool _canAcknowledge() =>
      _authCurrent() &&
      _lifecycle == AppLifecycleState.resumed &&
      ModalRoute.of(context)?.isCurrent == true &&
      csHostViewFocused(
        eventFocused: _viewFocused,
        currentViewId: View.of(context).viewId,
        viewIds: WidgetsBinding.instance.platformDispatcher.views
            .map((view) => view.viewId)
            .toList(),
        resumed: _lifecycle == AppLifecycleState.resumed,
      );

  Future<void> _ackVisible(
    CsSessionFlow flow,
    int binding,
    List<String> ids,
  ) async {
    if (!_scopeAlive(flow, binding) || !_canAcknowledge()) return;
    final before = (
      flow.readRevoked,
      flow.ackedCursor,
      flow.unreadCount,
      _error,
    );
    try {
      await flow.ackVisibleMessages(ids);
    } on Object {
      if (mounted && _scopeAlive(flow, binding)) {
        _error = context.t.customerService.loadFailedTitle;
      }
    }
    final after = (
      flow.readRevoked,
      flow.ackedCursor,
      flow.unreadCount,
      _error,
    );
    if (_scopeAlive(flow, binding) && before != after) _repaint(flow, binding);
  }

  Widget _messagesList() {
    final flow = _flow, binding = _binding;
    if (_busy && flow.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return CsFlowTimeline(
      key: ValueKey(binding),
      flow: flow,
      readAllowed: _authCurrent(),
      canAcknowledge: _canAcknowledge,
      onVisible: (ids) => _ackVisible(flow, binding, ids),
      loadOlder: () async {
        await flow.loadOlder();
        if (_scopeAlive(flow, binding)) _repaint(flow, binding);
      },
      retryHistory: _refresh,
      bytesLoader: _cachedAssetBytes,
      onView: _viewAsset,
      contactName: widget.contactName,
    );
  }
}
