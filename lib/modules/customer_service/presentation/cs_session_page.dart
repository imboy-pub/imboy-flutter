/// CS seat session: scoped history, visible reading acknowledgements and
/// authorized enterprise attachments. SSE is an invalidation hint; delivery
/// acknowledgements and visitor read receipts remain separate facts.
library;

import 'dart:typed_data';
import 'dart:ui' show ViewFocusEvent, ViewFocusState;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_gate.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_session_machine.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_action_confirmation.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_attachment_preparation.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_flow.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_seat_events_stream.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_timeline.dart';

import 'cs_session_rating_banner.dart';
import 'cs_attachment_save.dart';
import 'cs_attachment_upload_panel.dart';
import 'cs_verified_asset_cache.dart';

import 'package:imboy/modules/customer_service/presentation/cs_session_preview_scope.dart';
import 'package:imboy/service/auth_session_scope.dart';
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
  final CsApi? csApi;
  final AuthSessionReader? authReader;
  final CsSessionAttachmentPreparation? attachmentPreparation;
  final CsAttachmentSave? attachmentSave;

  const CsSessionPage({
    super.key,
    required this.orgId,
    required this.sessionId,
    this.conversationId = '',
    this.identityId = '',
    this.workspaceId = '',
    this.contactName = '',
    this.csApi,
    this.authReader,
    this.attachmentPreparation,
    this.attachmentSave,
  });

  @override
  State<CsSessionPage> createState() => _CsSessionPageState();
}

class _CsSessionPageState extends State<CsSessionPage>
    with WidgetsBindingObserver {
  late CsSessionFlow _flow;
  late CsSeatEventsStream _events;
  final TextEditingController _input = TextEditingController();
  final _inputFocus = FocusNode();
  late final AuthSessionReader _auth;
  int _binding = 0;
  AuthSessionScope _authScope = (uid: '', generation: 0, transitioning: true);
  String _draftScope = '';
  late final CsSessionPreviewScope _previews;
  AppLifecycleState? _lifecycle;
  bool? _viewFocused;

  bool _busy = false;
  bool _sending = false;
  bool _uploading = false;
  final _actions = CsSessionActionConfirmation();
  late final CsSessionAttachmentPreparation _attachmentPreparation;
  CsPreparedSeatAttachment? _preparedAttachment;
  CsAssetUploadOperation? _attachmentOperation;
  String? _error;

  final _assetCache = CsVerifiedAssetCache();
  Future<CsVerifiedAssetContent?> _cachedAssetContent(String id) =>
      _assetCache.get(id, () => _flow.fetchAssetContent(id));
  Future<Uint8List?> _cachedAssetBytes(String id) async {
    final flow = _flow, binding = _binding;
    final content = await _cachedAssetContent(id);
    return _scopeAlive(flow, binding) && !flow.readRevoked
        ? content?.bytes
        : null;
  }

  @override
  void initState() {
    super.initState();
    _previews = CsSessionPreviewScope(save: widget.attachmentSave);
    _attachmentPreparation =
        widget.attachmentPreparation ?? CsSessionAttachmentPreparation();
    WidgetsBinding.instance.addObserver(this);
    _auth = widget.authReader ?? authSessionReader;
    _auth.addListener(_authChanged);
    _actions.addListener(_actionChanged);
    _inputFocus.addListener(_focusChanged);
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    _bind();
  }

  String _routeScope(CsSessionPage page) =>
      '${page.orgId}/${page.workspaceId}/${page.sessionId}/${page.conversationId}/${page.identityId}';

  bool _authCurrent() => _auth.isCurrent(_authScope);

  bool _scopeAlive(CsSessionFlow flow, int binding) =>
      mounted &&
      binding == _binding &&
      identical(flow, _flow) &&
      _authCurrent();

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  void _authChanged() {
    if (!mounted) return;
    final now = _auth.current;
    if (now.transitioning || now.uid.isEmpty) {
      _refreshCurrent(_flow, _binding);
      return;
    }
    if (now == _authScope) return;
    _flow.dispose();
    _bind();
    setState(() {});
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
    _actions.invalidate();
    _previews.invalidate();
    final now = _auth.current;
    final draftScope = '${now.uid}/${_routeScope(widget)}';
    if (_draftScope != draftScope) _input.clear();
    _draftScope = draftScope;
    final binding = ++_binding, route = _routeScope(widget);
    _authScope = now;
    _clearAttachmentScope();
    _busy = false;
    _sending = false;
    _uploading = false;
    _error = null;
    _flow = CsSessionFlow(
      orgId: widget.orgId,
      sessionId: widget.sessionId,
      conversationId: widget.conversationId,
      identityId: widget.identityId,
      workspaceId: widget.workspaceId,
      contactMaskedName: csMaskContactName(widget.contactName),
      csApi: widget.csApi,
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
    _actions.removeListener(_actionChanged);
    _actions.dispose();
    _previews.dispose();
    _clearAttachmentScope();
    _flow.dispose();
    _input.dispose();
    _auth.removeListener(_authChanged);
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
    if (!_refreshCurrent(flow, binding)) return;
    await flow.resyncReadState();
    if (!_refreshCurrent(flow, binding)) return;
    await flow.refreshLoadedHistory();
    if (_refreshCurrent(flow, binding)) _repaint(flow, binding);
  }

  bool _refreshCurrent(CsSessionFlow flow, int binding) {
    if (mounted &&
        binding == _binding &&
        identical(flow, _flow) &&
        !_authCurrent()) {
      flow.invalidateReadScope();
      flow.dispose();
      _actions.invalidate();
      _input.clear();
      _previews.invalidate();
      _clearAttachmentScope();
      setState(() {});
    }
    return _scopeAlive(flow, binding);
  }

  void _clearAttachmentScope() {
    _assetCache.clear();
    _preparedAttachment = null;
    _attachmentOperation?.cancel();
    _attachmentOperation = null;
  }

  void _repaint(CsSessionFlow flow, int binding) {
    if (!_scopeAlive(flow, binding)) return;
    if (flow.readRevoked) {
      _previews.invalidate();
      _clearAttachmentScope();
    }
    _actions.refresh();
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
    if (text.isEmpty || _busy || _actions.busy) return;
    setState(() {
      _busy = true;
      _sending = true;
    });
    _actions.refresh();
    final ok = await flow.send(text);
    if (!mounted || !_scopeAlive(flow, binding)) return;
    setState(() {
      _busy = false;
      _sending = false;
    });
    _actions.refresh();
    if (ok) {
      _input.clear();
      _actions.refresh();
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

  void _setUploadBusy(bool value) {
    setState(() {
      _busy = value;
      _uploading = value;
    });
    _actions.refresh();
  }

  bool _canAttach(CsSessionFlow flow, int binding, {bool ownsUpload = false}) =>
      _scopeAlive(flow, binding) &&
      !flow.readRevoked &&
      (!ownsUpload ||
          _attachmentOperation?.stage != CsAssetUploadStage.cancelled) &&
      _attachmentOperation?.stage != CsAssetUploadStage.unknown &&
      flow.machine.canSend &&
      !_actions.busy &&
      flow.pendingClientMsgId == null &&
      (!_busy || (ownsUpload && _uploading));

  CsAssetUploadOperation _newAttachmentOperation(
    CsSessionFlow flow,
    int binding,
  ) => CsAssetUploadOperation(
    isCurrent: () =>
        _scopeAlive(flow, binding) &&
        !flow.readRevoked &&
        flow.machine.canSend &&
        !_actions.busy,
    onChanged: () {
      if (_scopeAlive(flow, binding)) setState(() {});
    },
  );

  Future<void> _attach() async {
    final flow = _flow, binding = _binding;
    if (!_canAttach(flow, binding)) return;
    _preparedAttachment = null;
    _attachmentOperation = _newAttachmentOperation(flow, binding);
    final operation = _attachmentOperation!;
    _setUploadBusy(true);
    try {
      final prepared = await _attachmentPreparation.prepare(
        canWrite: () => _canAttach(flow, binding, ownsUpload: true),
      );
      if (prepared == null) {
        operation.cancel();
        return;
      }
      if (!_canAttach(flow, binding, ownsUpload: true)) return;
      _preparedAttachment = prepared;
      await _uploadPrepared(flow, binding, prepared);
    } on CsUnsupportedSeatAttachment {
      if (_scopeAlive(flow, binding)) {
        _attachmentOperation = null;
        setState(
          () => _error = context.t.customerService.attachUnsupportedType,
        );
      }
    } on Object {
      if (_scopeAlive(flow, binding)) {
        _attachmentOperation = null;
        setState(() => _error = context.t.customerService.attachUploadFailed);
      }
    } finally {
      if (_scopeAlive(flow, binding)) _setUploadBusy(false);
    }
  }

  Future<void> _uploadPrepared(
    CsSessionFlow flow,
    int binding,
    CsPreparedSeatAttachment prepared,
  ) async {
    final operation = _attachmentOperation!;
    final id = await flow.uploadAsset(
      mime: prepared.mime,
      bytes: prepared.bytes,
      fileName: prepared.fileName,
      operation: operation,
    );
    if (!_canAttach(flow, binding, ownsUpload: true) || id.isEmpty) return;
    final ok = await flow.send('', assetIds: [id]);
    if (!mounted || !_refreshCurrent(flow, binding)) return;
    _toast(
      ok
          ? context.t.customerService.attachUploaded
          : context.t.customerService.sendFailed,
    );
    if (ok) _preparedAttachment = null;
  }

  Future<void> _retryAttachment() async {
    final flow = _flow, binding = _binding, prepared = _preparedAttachment;
    if (prepared == null ||
        _busy ||
        _actions.busy ||
        !_scopeAlive(flow, binding) ||
        !flow.machine.canSend ||
        flow.readRevoked ||
        !(_attachmentOperation?.canRetry ?? false)) {
      return;
    }
    _attachmentOperation = _newAttachmentOperation(flow, binding);
    _setUploadBusy(true);
    try {
      await _uploadPrepared(flow, binding, prepared);
    } finally {
      if (_scopeAlive(flow, binding)) _setUploadBusy(false);
    }
  }

  void _cancelAttachment() {
    _attachmentOperation?.cancel();
    if (mounted) setState(() {});
  }

  /// Attachments always use the authorized content proxy, including closed sessions.
  Future<void> _viewAsset(CsMessageAsset asset) async {
    final flow = _flow, binding = _binding;
    try {
      await _previews.show(
        context: context,
        asset: asset,
        loadContent: () => flow.fetchAssetContent(asset.id),
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

  void _actionChanged() {
    if (mounted) setState(() {});
  }

  CsActionRisks _actionRisks() => CsActionRisks(
    draft: _input.text.trim().isNotEmpty,
    sending: _sending,
    uploading: _uploading,
    unconfirmed:
        (_flow.pendingClientMsgId != null ||
            _attachmentOperation?.stage == CsAssetUploadStage.unknown) &&
        !_sending &&
        !_uploading,
  );

  Future<void> _openTransfer() async {
    final flow = _flow, binding = _binding;
    try {
      final result = await _actions.transfer(
        context: context,
        flow: flow,
        isCurrent: () => _scopeAlive(flow, binding),
        risks: _actionRisks,
      );
      if (!mounted || !_scopeAlive(flow, binding) || result == null) return;
      _repaint(flow, binding);
      if (result.failure == null) {
        _toast(context.t.customerService.transferSuccess);
      } else {
        _toastFailure(result.failure!);
      }
    } on CsApiException catch (e) {
      if (!_scopeAlive(flow, binding)) return;
      _toastFailure(flow.applyActionFailure(e));
      _repaint(flow, binding);
    } on Object {
      if (_scopeAlive(flow, binding)) _toastFailure(CsSeatFailureKind.other);
    }
  }

  Future<void> _openClose() async {
    final flow = _flow, binding = _binding;
    try {
      final result = await _actions.close(
        context: context,
        flow: flow,
        isCurrent: () => _scopeAlive(flow, binding),
        risks: _actionRisks,
      );
      if (!mounted || !_scopeAlive(flow, binding) || result == null) return;
      _repaint(flow, binding);
      final t = context.t.customerService;
      _toast(
        result.failure == null
            ? t.closeSuccess
            : result.failure == CsSeatFailureKind.conflict
            ? t.closeConflict
            : t.closeFailed,
      );
    } on Object {
      if (mounted && _scopeAlive(flow, binding)) {
        _toast(context.t.customerService.closeFailed);
      }
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
        return _authCurrent() &&
                !_flow.readRevoked &&
                _flow.detail?.isClosed == true &&
                _flow.detail?.evaluationState == CsEvaluationState.rated
            ? t.ratedReadonly
            : t.closedReadonly;
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
    final canWrite =
        _authCurrent() &&
        !_flow.readRevoked &&
        machine.canSend &&
        _attachmentOperation?.stage != CsAssetUploadStage.unknown;
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
              onPressed: _actions.busy || _flow.detail?.status != 'active'
                  ? null
                  : _openTransfer,
              tooltip: t.transferAction,
              icon: const Icon(CupertinoIcons.arrow_2_squarepath),
            ),
            IconButton(
              onPressed:
                  _actions.busy ||
                      !['queued', 'active'].contains(_flow.detail?.status)
                  ? null
                  : _openClose,
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
          CsSessionRatingBanner(
            detail: _authCurrent() && !_flow.readRevoked ? _flow.detail : null,
            phase: _flow.machine.phase,
          ),
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
          if (_attachmentOperation != null &&
              !_flow.readRevoked &&
              (_uploading ||
                  _preparedAttachment != null ||
                  _attachmentOperation!.stage != CsAssetUploadStage.complete))
            CsAttachmentUploadPanel(
              operation: _attachmentOperation!,
              messageUnconfirmed: _preparedAttachment != null && !_uploading,
              onCancel: _cancelAttachment,
              onRetry: _preparedAttachment == null ? null : _retryAttachment,
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
                  onPressed: canWrite && !_busy && !_actions.busy
                      ? _attach
                      : null,
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
                      enabled: canWrite && !_busy && !_actions.busy,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(hintText: t.inputHint),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: canWrite && !_busy && !_actions.busy
                      ? _send
                      : null,
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
