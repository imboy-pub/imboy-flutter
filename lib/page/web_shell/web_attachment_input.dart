import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_chat_core/flutter_chat_core.dart' show Message;
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/message_events.dart' show MessageSentEvent;
import 'package:imboy/store/model/message_model.dart' show IMBoyMessageStatus;
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:flutter/material.dart';
import 'package:imboy/capabilities/adapters/picked_attachment_bytes.dart';
import 'package:imboy/component/helper/func.dart' show formatBytes;
import 'package:imboy/component/helper/image_dimensions.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/upload/upload_mime.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/attachment_handler.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/store/repository/attachment_upload_task_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';

import 'web_attachment_input_events_stub.dart'
    if (dart.library.js_interop) 'web_attachment_input_events_web.dart';
import 'web_group_composer_gate.dart';
import 'web_shell_state.dart';

typedef _SelectedAttachment = ({
  String name,
  Uint8List? bytes,
  int size,
  bool image,
  int width,
  int height,
});

({int width, int height}) webAttachmentPreviewSize(int width, int height) {
  if (width <= 0 || height <= 0) {
    throw const FormatException('image dimensions');
  }
  final limit = AppSizes.thumbnailSize.toInt();
  final scale = math.min(1.0, limit / math.max(width, height));
  return (
    width: math.max(1, (width * scale).floor()),
    height: math.max(1, (height * scale).floor()),
  );
}

class WebAttachmentInput extends StatefulWidget {
  const WebAttachmentInput({
    super.key,
    required this.selection,
    required this.currentUserId,
    required this.isCurrent,
    required this.inputFocus,
    required this.regionKey,
  });
  final ChatSelection selection;
  final String currentUserId;
  final bool Function() isCurrent;
  final FocusNode inputFocus;
  final GlobalKey regionKey;
  @override
  State<WebAttachmentInput> createState() => _WebAttachmentInputState();
}

class _WebAttachmentInputState extends State<WebAttachmentInput> {
  // Browser composer cache budget, not the backend/Native per-file contract.
  static const _retainedBytesBudget = AttachmentApi.maxUploadBytes;
  List<_SelectedAttachment> _files = [];
  int get _retainedBytes =>
      _files.fold(0, (sum, file) => sum + (file.bytes?.length ?? 0));
  int get _remainingBytes => _retainedBytesBudget - _retainedBytes;
  String get _selectedBytesLabel =>
      '${t.main.selected} · ${t.main.cache}: '
      '${formatBytes(_retainedBytes)} / ${formatBytes(_retainedBytesBudget)}';
  late AuthSessionScope _owner;
  StreamSubscription<void>? _failure;
  StreamSubscription<MessageSentEvent>? _sent;
  final _pendingCommitAnchors = <String>{};
  void Function()? _removeEvents;
  CancelToken? _cancel;
  bool Function()? _permission;
  bool _busy = false, _preparing = false, _restoring = false;
  bool _unknown = false, _restoreFailed = false, _initialized = false;
  bool _outboxReady = false, _dispatchUnknown = false;
  int _revision = 0;
  String? _anchor;
  UploadCheckpointStage? _stage;
  bool get _active =>
      mounted &&
      _owner.uid.isNotEmpty &&
      _owner.uid == widget.currentUserId &&
      widget.isCurrent() &&
      authSessionReader.current == _owner &&
      !_owner.transitioning;
  bool get _ready =>
      _active && isWebWriterReady && WebGroupSendScope.allowedOf(context);
  bool _invalidImage(_SelectedAttachment file) =>
      file.image && (file.width <= 0 || file.height <= 0);
  bool _cannotPreview(_SelectedAttachment file) =>
      file.image && !isWebImagePreviewSizeAllowed(file.width, file.height);
  bool get _hasInvalidSelection =>
      _files.any((file) => file.bytes != null && _invalidImage(file));
  String get _previewFailureLabel =>
      '${t.chat.groupFileImagePreview}: ${t.common.groupFileImageLoadFailed}';
  bool get _canPick =>
      _ready &&
      _initialized &&
      !_busy &&
      !_preparing &&
      !_restoring &&
      !_unknown &&
      !_restoreFailed;

  void _check() {
    if (!_ready ||
        _permission?.call() == false ||
        _cancel?.isCancelled == true) {
      throw const AccountLocalTaskCancelledException();
    }
  }

  @override
  void initState() {
    super.initState();
    _owner = authSessionReader.current;
    _initialized = !kIsWeb; // Native VM fixtures only exercise local selection.
    authSessionReader.addListener(_onAuth);
    _failure = webWriterFailures.listen((_) => _reset());
    _sent = AppEventBus.on<MessageSentEvent>().listen(_onCommitted);
    _removeEvents = listenWebAttachmentInput(
      containsPoint: (x, y) {
        final box = widget.regionKey.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.hasSize) {
          return false;
        }
        return (box.localToGlobal(Offset.zero) & box.size).contains(
          Offset(x.toDouble(), y.toDouble()),
        );
      },
      acceptsPaste: () => _canPick && widget.inputFocus.hasFocus,
      captureInput: () {
        final revision = _revision;
        return () => _active && revision == _revision && _ready;
      },
      onFile: (name, size, read) => _prepare(name, size, read),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_permission?.call() == false ||
        (!_ready && (_initialized || _restoring))) {
      _reset();
    }
    if (!_initialized && !_restoring && !_restoreFailed && _ready) {
      unawaited(_restorePending());
    }
  }

  @override
  void didUpdateWidget(covariant WebAttachmentInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection ||
        oldWidget.currentUserId != widget.currentUserId) {
      _reset();
      unawaited(_restorePending());
    }
  }

  void _onAuth() {
    if (_owner != authSessionReader.current || !widget.isCurrent()) {
      _reset();
    }
  }

  ImageProvider _previewProvider(_SelectedAttachment file) {
    final size = webAttachmentPreviewSize(file.width, file.height);
    return ResizeImage(
      MemoryImage(file.bytes!),
      width: size.width,
      height: size.height,
    );
  }

  void _release(_SelectedAttachment file) {
    if (file.bytes != null && file.image && !_cannotPreview(file)) {
      unawaited(_previewProvider(file).evict());
    }
  }

  void _reset() {
    _revision++;
    _pendingCommitAnchors.clear();
    _cancel?.cancel('attachment view no longer owned');
    _cancel = null;
    for (final file in _files) {
      _release(file);
    }
    _files = [];
    _anchor = null;
    _stage = null;
    _dispatchUnknown = false;
    _outboxReady = false;
    _permission = null;
    _busy = _preparing = _restoring = _unknown = _restoreFailed = false;
    _initialized = !kIsWeb;
    _owner = authSessionReader.current;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _revision++;
    _cancel?.cancel('attachment view disposed');
    for (final file in _files) {
      _release(file);
    }
    authSessionReader.removeListener(_onAuth);
    _removeEvents?.call();
    unawaited(_failure?.cancel());
    unawaited(_sent?.cancel());
    super.dispose();
  }

  Future<void> _restorePending() async {
    if (!kIsWeb || !_ready || _restoring || _initialized) {
      return;
    }
    final revision = _revision;
    setState(() => _restoring = true);
    try {
      final repo = AttachmentUploadTaskRepo();
      await BrowserAttachmentMaterialStore.forCurrentBrowserSession(repo)
          .ensureDurable();
      final owner = AccountLocalTaskOwner.capture();
      final rows = await repo.listBusinessPending(widget.currentUserId);
      if (!_active || revision != _revision) {
        return;
      }
      var restored = false;
      for (final dispatchOnly in [true, false]) {
        for (final row in rows) {
          if (_restoreRow(row, owner, dispatchOnly: dispatchOnly)) {
            restored = true;
            break;
          }
        }
        if (restored) break;
      }
      if (_active && revision == _revision && _ready) {
        setState(() => _initialized = true);
      }
    } on Object {
      if (_active && revision == _revision) {
        setState(() => _restoreFailed = true);
      }
    } finally {
      if (_active && revision == _revision) {
        setState(() => _restoring = false);
        _consumePendingCommit();
      }
    }
  }

  void _onCommitted(MessageSentEvent event) {
    final conversation = ConversationUk3Generator.generateSmart(
      type: widget.selection.chatType,
      currentUserId: widget.currentUserId,
      peerId: widget.selection.peerId,
    );
    if (!_active ||
        event.messageType != widget.selection.chatType ||
        event.conversationUk3 != conversation ||
        (event.messageId != _anchor && !_restoring)) {
      return;
    }
    _pendingCommitAnchors.add(event.messageId);
    _consumePendingCommit();
  }

  void _consumePendingCommit() {
    if (_restoring || _busy || _preparing || !_active) return;
    if (_anchor != null && _pendingCommitAnchors.contains(_anchor)) {
      unawaited(_checkLocalDispatch());
    } else {
      _pendingCommitAnchors.clear();
    }
  }

  bool _restoreRow(
    AttachmentUploadTask row,
    AccountLocalTaskOwner owner, {
    required bool dispatchOnly,
    List<_SelectedAttachment> tail = const [],
  }) {
    if (row.stage == AttachmentUploadStage.abandoned) {
      return false;
    }
    try {
      BrowserUploadMaterial.requireOwner(
        row.uploadPath,
        owner.storageDigest,
        row.id,
      );
    } on BrowserMaterialException {
      return false;
    }
    final intent = jsonDecode(row.businessIntent!) as Map;
    final state = intent['state'];
    final dispatchUnknown = !{
      'uploading',
      'outbox_ready',
      'dispatch_reserved_v2',
    }.contains(state);
    if (state == 'committed' ||
        dispatchUnknown != dispatchOnly ||
        intent['author_id'] != widget.currentUserId ||
        intent['peer_id'] != widget.selection.peerId ||
        intent['chat_type'] != widget.selection.chatType.toLowerCase() ||
        row.anchorMsgId == null) {
      return false;
    }
    setState(() {
      _anchor = row.anchorMsgId;
      _unknown = true;
      _dispatchUnknown = dispatchUnknown;
      _files = [
        (
          name: _restoredName(intent, row.fileName),
          bytes: null,
          size: row.plainSize,
          image: row.mime.startsWith('image/'),
          width: 0,
          height: 0,
        ),
        ...tail,
      ];
    });
    return true;
  }

  String _restoredName(Map<dynamic, dynamic> intent, String fallback) {
    for (final key in ['message_template', 'message']) {
      final message = intent[key];
      if (message is Map &&
          message['name'] is String &&
          (message['name'] as String).trim().isNotEmpty) {
        return message['name'] as String;
      }
    }
    return fallback;
  }

  Future<void> _checkLocalDispatch() async {
    if (!_ready || _restoring || _busy || _preparing || _anchor == null) return;
    final revision = _revision;
    final uid = widget.currentUserId;
    final selection = widget.selection;
    final anchor = _anchor!;
    _pendingCommitAnchors.remove(anchor);
    final owner = AccountLocalTaskOwner.capture();
    bool current() =>
        _active &&
        _ready &&
        revision == _revision &&
        uid == widget.currentUserId &&
        selection == widget.selection &&
        _anchor == anchor;
    setState(() => _restoring = true);
    try {
      final repo = AttachmentUploadTaskRepo();
      final rows = await repo.findByAnchor(anchor, uid);
      if (!current() || rows.isEmpty) return;
      for (final row in rows) {
        BrowserUploadMaterial.requireOwner(
          row.uploadPath,
          owner.storageDigest,
          row.id,
        );
        final intent = jsonDecode(row.businessIntent!) as Map;
        if (row.userId != uid ||
            row.anchorMsgId != anchor ||
            row.stage != AttachmentUploadStage.confirmed ||
            (row.lastError?.startsWith('legacy_migrating:') ?? false) ||
            intent['expected_objects'] != rows.length ||
            intent['author_id'] != uid ||
            intent['peer_id'] != selection.peerId ||
            intent['chat_type'] != selection.chatType.toLowerCase() ||
            intent['state'] != 'committed') {
          return;
        }
      }
      final canonical = await MessageRepo(
        tableName: MessageRepo.getTableName(selection.chatType),
      ).find(anchor);
      if (!current() ||
          canonical == null ||
          canonical.fromId.toString() != uid ||
          canonical.toId.toString() != selection.peerId ||
          canonical.type != selection.chatType ||
          canonical.conversationUk3 !=
              ConversationUk3Generator.generateSmart(
                type: selection.chatType,
                currentUserId: uid,
                peerId: selection.peerId,
              ) ||
          !{
            IMBoyMessageStatus.sent,
            IMBoyMessageStatus.delivered,
            IMBoyMessageStatus.seen,
          }.contains(canonical.status)) {
        return;
      }
      final pending = await repo.listBusinessPending(uid);
      if (!current()) return;
      final completed = _files.isEmpty ? null : _files.first;
      final tail = _files.skip(1).toList();
      for (final dispatchOnly in [true, false]) {
        for (final row in pending) {
          if (row.anchorMsgId == anchor) continue;
          if (_restoreRow(row, owner, dispatchOnly: dispatchOnly, tail: tail)) {
            if (completed != null) _release(completed);
            return;
          }
        }
      }
      setState(() {
        _files = tail;
        _anchor = null;
        _unknown = false;
        _dispatchUnknown = false;
      });
      if (completed != null) _release(completed);
    } on Object {
      // Missing or unreadable local evidence cannot prove a safe send.
    } finally {
      if (_active && revision == _revision) {
        setState(() => _restoring = false);
        _consumePendingCommit();
      }
    }
  }

  Future<void> _pick(bool images) async {
    if (!_canPick) {
      return;
    }
    final revision = _revision;
    setState(() => _preparing = true);
    var files = <PlatformFile>[];
    try {
      files = await FilePicker.pickFiles(
        type: images ? FileType.image : FileType.any,
      );
      if (!_active || revision != _revision) {
        return;
      }
      setState(() => _preparing = false);
      for (final file in files) {
        if (!_active || revision != _revision) {
          return;
        }
        final length = file.lengthSync();
        if (!_active || revision != _revision) {
          return;
        }
        await _prepare(
          file.name,
          length,
          () => readPickedAttachmentBytes(
            file,
            maxBytes: _remainingBytes,
            knownLengthOnly: true,
            requireCurrent: () {
              if (revision != _revision) {
                throw const AccountLocalTaskCancelledException();
              }
              _check();
            },
          ),
        );
      }
    } on Object {
      if (_active && revision == _revision) {
        AppLoading.showError(t.common.operationFailedAgainLater);
      }
    } finally {
      for (final file in files) {
        revokePickedAttachmentUri(file.uri);
      }
      if (_active && revision == _revision) {
        setState(() => _preparing = false);
        _consumePendingCommit();
      }
    }
  }

  Future<void> _prepare(
    String name,
    int? size,
    Future<Uint8List> Function() read,
  ) async {
    if (!_canPick) {
      return;
    }
    final revision = _revision;
    setState(() => _preparing = true);
    try {
      if (size != null && (size <= 0 || size > AttachmentApi.maxUploadBytes)) {
        throw const FormatException('attachment size');
      }
      final available = _remainingBytes;
      if (available <= 0 || (size != null && size > available)) {
        _showBudgetLimit();
        return;
      }
      final bytes = await read();
      _check();
      if (revision != _revision) {
        return;
      }
      if (bytes.isEmpty ||
          bytes.length > AttachmentApi.maxUploadBytes ||
          (size != null && bytes.length != size)) {
        throw const FormatException('attachment size');
      }
      if (bytes.length > available || bytes.length > _remainingBytes) {
        _showBudgetLimit();
        return;
      }
      final mime = resolveUploadMime(name, bytes);
      final image = mime.startsWith('image/') && mime != 'image/svg+xml';
      var dimensions = (width: 0, height: 0);
      if (image) {
        try {
          dimensions = await _validateImage(bytes);
        } on Object {
          // Keep the selection; preview failure authorizes no upload or downgrade.
          _check();
        }
      }
      _check();
      if (revision == _revision) {
        setState(
          () => _files = [
            ..._files,
            (
              name: name,
              bytes: bytes,
              size: bytes.length,
              image: image,
              width: dimensions.width,
              height: dimensions.height,
            ),
          ],
        );
        widget.inputFocus.requestFocus();
      }
    } on Object {
      if (_active && revision == _revision) {
        AppLoading.showError(t.common.selectImageFailed);
      }
    } finally {
      if (_active && revision == _revision) {
        setState(() => _preparing = false);
        _consumePendingCommit();
      }
    }
  }

  void _showBudgetLimit() => AppLoading.showError(
    '${t.main.cache} · ${t.customerService.governance.limitAtCapacity}\n$_selectedBytesLabel',
  );

  Future<({int width, int height})> _validateImage(Uint8List bytes) async {
    _check();
    final dimensions = readImageDimensions(bytes);
    _check();
    if (!isWebImagePreviewSizeAllowed(dimensions.width, dimensions.height)) {
      return dimensions;
    }
    final target = webAttachmentPreviewSize(
      dimensions.width,
      dimensions.height,
    );
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: target.width,
      targetHeight: target.height,
      allowUpscaling: false,
    );
    try {
      _check();
      final frame = await codec.getNextFrame();
      try {
        _check();
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
    return dimensions;
  }

  ChatAttachmentHandler _handler() {
    final revision = _revision;
    final permission = _permission;
    final cancel = _cancel!;
    bool ownsOperation() =>
        _active &&
        revision == _revision &&
        !cancel.isCancelled &&
        permission?.call() != false;
    void checkOperation() {
      if (!ownsOperation() || !_ready) {
        throw const AccountLocalTaskCancelledException();
      }
    }

    final repo = AttachmentUploadTaskRepo();
    final conversationUk3 = ConversationUk3Generator.generateSmart(
      type: widget.selection.chatType,
      currentUserId: widget.currentUserId,
      peerId: widget.selection.peerId,
    );
    return ChatAttachmentHandler(
      type: widget.selection.chatType,
      peerId: widget.selection.peerId,
      conversationUk3: conversationUk3,
      ownerGeneration: UserRepoLocal.to.sessionGeneration,
      browserMaterialStore: kIsWeb
          ? BrowserAttachmentMaterialStore.forCurrentBrowserSession(repo)
          : null,
      cancelToken: cancel,
      requireCurrent: checkOperation,
      showProgress: false,
      isMutedCheck: () => !ownsOperation() || !_ready,
      // Web messages publish through the confirmed journal, never a bare callback.
      onMessageCreated: (_) async => false,
      onMessagePersisted: (message) async {
        checkOperation();
        if (message.authorId != widget.currentUserId ||
            message.metadata?['conversation_uk3'] != conversationUk3) {
          return false;
        }
        // The existing Web subscriber inserts only this conversation, by ID.
        AppEventBus.fireData(message);
        return true;
      },
      onUploadAnchor: (anchor) {
        if (ownsOperation()) {
          _anchor = anchor;
        }
      },
      onUploadCheckpoint: (event) async {
        checkOperation();
        setState(() => _stage = event.stage);
      },
      onUploadResult: (ready, failure) {
        if (ownsOperation()) {
          setState(() {
            _outboxReady = ready;
            _unknown = !ready;
          });
        }
      },
    );
  }

  Future<bool> _recoverConfirmedUpload(
    ChatAttachmentHandler handler,
    String anchor,
  ) async {
    if (!await handler.recoverUpload(anchor)) return false;
    handler.requireCurrent?.call();
    return const ChatNetworkService().presentAttachmentOutbox(
      type: handler.type,
      peerId: handler.peerId,
      conversationUk3: handler.conversationUk3,
      messageId: anchor,
      isCurrent: () {
        handler.requireCurrent?.call();
        return _active && _ready;
      },
      present: handler.onMessagePersisted!,
    );
  }

  /// Exercise the same confirmed handler/continuation with an isolated journal.
  @visibleForTesting
  Future<bool> completeConfirmedUploadForTest(
    Message template, {
    bool retry = false,
  }) {
    _permission = WebGroupSendScope.leaseOf(context);
    _cancel = CancelToken();
    final handler = _handler();
    if (retry) return _recoverConfirmedUpload(handler, template.id);
    // This annotated seam is called only by isolated widget fixtures.
    // ignore: invalid_use_of_visible_for_testing_member
    return handler.completeUploadedMessageForTest(template);
  }

  @visibleForTesting
  bool restoreUploadForTest(AttachmentUploadTask row, {String? nextFileName}) =>
      _restoreRow(
        row,
        AccountLocalTaskOwner.capture(),
        tail: nextFileName == null
            ? const []
            : [
                (
                  name: nextFileName,
                  bytes: Uint8List(1),
                  size: 1,
                  image: false,
                  width: 0,
                  height: 0,
                ),
              ],
        dispatchOnly: !{
          'uploading',
          'outbox_ready',
          'dispatch_reserved_v2',
        }.contains((jsonDecode(row.businessIntent!) as Map)['state']),
      );

  Future<void> _classifyFailure(int revision) async {
    if (!_active || revision != _revision) {
      return;
    }
    var hasJournal = _anchor != null;
    var abandoned = false;
    var dispatchUnknown = false;
    if (_anchor != null) {
      try {
        final rows = await AttachmentUploadTaskRepo().findByAnchor(
          _anchor!,
          widget.currentUserId,
        );
        abandoned =
            rows.isNotEmpty &&
            rows.every((row) => row.stage == AttachmentUploadStage.abandoned);
        hasJournal = rows.isNotEmpty && !abandoned;
        dispatchUnknown = rows.any((row) {
          final intent = jsonDecode(row.businessIntent!) as Map;
          return !{
            'uploading',
            'outbox_ready',
            'dispatch_reserved_v2',
            'committed',
          }.contains(intent['state']);
        });
      } on Object {
        // An unreadable journal cannot prove that a new upload identity is safe.
        hasJournal = true;
        dispatchUnknown = true;
      }
    }
    if (_active && revision == _revision) {
      setState(() {
        _unknown = hasJournal;
        _dispatchUnknown = dispatchUnknown;
        if (!hasJournal) {
          _anchor = null;
          if (_files.isNotEmpty && _files.first.bytes == null) {
            _files = _files.skip(1).toList();
          }
        }
      });
      if (abandoned) {
        AppLoading.showError(t.common.legacyUploadRecoveryBody);
      }
    }
  }

  Future<void> _send({bool retry = false}) async {
    if (!_ready ||
        !_initialized ||
        _busy ||
        _preparing ||
        _restoring ||
        (retry && _dispatchUnknown) ||
        _hasInvalidSelection) {
      return;
    }
    final revision = _revision;
    _permission = WebGroupSendScope.leaseOf(context);
    _cancel = CancelToken();
    setState(() {
      _busy = true;
      _unknown = false;
    });
    try {
      final handler = _handler();
      if (retry) {
        if (_anchor == null ||
            !await _recoverConfirmedUpload(handler, _anchor!)) {
          await _classifyFailure(revision);
          return;
        }
        if (!_active || revision != _revision) {
          return;
        }
        _remove(0);
        _anchor = null;
      } else {
        await _sendSelected(handler, revision);
      }
    } on Object {
      await _classifyFailure(revision);
    } finally {
      if (_active && revision == _revision) {
        _cancel = null;
        _permission = null;
        setState(() {
          _busy = false;
          _stage = null;
        });
        _consumePendingCommit();
      }
    }
  }

  Future<void> _sendSelected(
    ChatAttachmentHandler handler,
    int revision,
  ) async {
    while (_files.isNotEmpty && !_unknown) {
      _check();
      if (revision != _revision) {
        return;
      }
      _outboxReady = false;
      final file = _files.first;
      if (file.bytes == null) {
        throw StateError('recovery required');
      }
      if (_invalidImage(file)) {
        return;
      }
      if (file.image) {
        await handler.uploadImageBytes(
          file.bytes!,
          file.name,
          dimensions: (width: file.width, height: file.height),
        );
      } else {
        if (!mounted) {
          return;
        }
        await handler.uploadFileBytes(context, file.bytes!, file.name);
      }
      _check();
      if (revision != _revision) {
        return;
      }
      if (!_outboxReady) {
        await _classifyFailure(revision);
        return;
      }
      _remove(0);
      _anchor = null;
    }
  }

  void _remove(int index) {
    final file = _files[index];
    _release(file);
    setState(() => _files = [..._files]..removeAt(index));
  }

  Widget _thumbnail(_SelectedAttachment file) {
    if (file.image && file.bytes != null) {
      if (_cannotPreview(file)) {
        return const Icon(
          Icons.broken_image_outlined,
          key: ValueKey('web-attachment-unpreviewable'),
        );
      }
      return Center(
        child: AspectRatio(
          aspectRatio: file.width / file.height,
          child: Image(
            image: _previewProvider(file),
            fit: BoxFit.fill,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
          ),
        ),
      );
    }
    return Icon(
      file.image ? Icons.image_outlined : Icons.insert_drive_file_outlined,
    );
  }

  Widget _file(_SelectedAttachment file, int index) => Row(
    children: [
      SizedBox(
        width: AppSizes.thumbnailSize,
        height: AppSizes.thumbnailSize,
        child: _thumbnail(file),
      ),
      AppSpacing.horizontalSmall,
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${file.name} · ${formatBytes(file.size)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (file.bytes != null && _cannotPreview(file))
              Text(
                _previewFailureLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
      if (!_busy && !_unknown)
        IconButton(
          onPressed: () => _remove(index),
          constraints: const BoxConstraints(
            minWidth: AppSizes.touchTarget,
            minHeight: AppSizes.touchTarget,
          ),
          tooltip: t.common.buttonRemove,
          icon: const Icon(Icons.close),
        ),
    ],
  );

  Widget _pickers() => Row(
    children: [
      IconButton(
        key: const ValueKey('web-attachment-image'),
        onPressed: _canPick ? () => _pick(true) : null,
        tooltip: t.chat.image,
        icon: const Icon(Icons.image_outlined),
      ),
      IconButton(
        key: const ValueKey('web-attachment-file'),
        onPressed: _canPick ? () => _pick(false) : null,
        tooltip: t.chat.file,
        icon: const Icon(Icons.attach_file),
      ),
      ..._actions(),
    ],
  );

  static const _actionStyle = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(
      Size(AppSizes.touchTarget, AppSizes.touchTarget),
    ),
    visualDensity: VisualDensity.standard,
  );

  List<Widget> _actions() => [
    if (_files.isNotEmpty && !_unknown)
      TextButton(
        style: _actionStyle,
        onPressed: _canPick && !_hasInvalidSelection ? () => _send() : null,
        child: Text(t.common.buttonSend),
      ),
    if (_dispatchUnknown)
      TextButton(
        style: _actionStyle,
        onPressed: _ready && !_busy && !_restoring ? _checkLocalDispatch : null,
        child: Text(t.common.legacyUploadCheckLocal),
      )
    else if (_unknown || _restoreFailed)
      TextButton(
        style: _actionStyle,
        onPressed: _ready && !_busy ? _retry : null,
        child: Text(t.common.retry),
      ),
    if (_busy)
      TextButton(
        style: _actionStyle,
        onPressed: () {
          _cancel?.cancel('user stopped upload');
          setState(() => _unknown = true);
        },
        child: Text(t.common.cancel),
      ),
  ];

  void _retry() {
    if (_restoreFailed) {
      setState(() => _restoreFailed = false);
      unawaited(_restorePending());
    } else {
      unawaited(_send(retry: true));
    }
  }

  Widget _selectedFiles() => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: AppSizes.thumbnailSize * 3),
    child: ListView(
      shrinkWrap: true,
      children: [for (var i = 0; i < _files.length; i++) _file(_files[i], i)],
    ),
  );

  Widget _activity() => Row(
    children: [
      const SizedBox(
        width: AppSpacing.large,
        height: AppSpacing.large,
        child: CircularProgressIndicator(),
      ),
      AppSpacing.horizontalSmall,
      Text(
        _stage == UploadCheckpointStage.putDone
            ? t.customerService.attachConfirming
            : t.common.uploading,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _pickers(),
      if (_files.isNotEmpty) ...[Text(_selectedBytesLabel), _selectedFiles()],
      if (_busy || _preparing || _restoring) _activity(),
      if (_unknown)
        Text(
          _dispatchUnknown
              ? t.common.legacyUploadOutboxCheck
              : t.customerService.attachUnknown,
        ),
      if (_restoreFailed) Text(t.common.operationFailedAgainLater),
    ],
  );
}
