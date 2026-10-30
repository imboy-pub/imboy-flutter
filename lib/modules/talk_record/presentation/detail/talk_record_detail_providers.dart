/// 面聊记录（talk_record）详情域状态层（T16 UI）。
///
/// Provider 形态与 T10 一致：build.yaml `riverpod_generator.generate_for`
/// 白名单不含新文件，按 lib/page/CLAUDE.md「最小模板」使用手写
/// Notifier/Provider。服务/网关/播放后端全部注入点化——widget 测试零网络
/// 零平台通道（fixture 注入）。
///
/// 职责划分：
/// - [TalkRecordDetailNotifier]：记录元数据 + 摘要 + 重点（bind 模式，
///   对齐 T10 TalkRecordListNotifier）；笔记保存/转写重试；
/// - [TalkRecordSegmentsNotifier]：原文片段（本地搜索高亮）；
/// - [TalkRecordSpeakersNotifier]：发言人（显示名/认领/人工标记）；
/// - [TalkRecordPlayerNotifier]：受控回放会话（开票/续签/seek/进度）。
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/modules/talk_record/talk_record_error.dart'
    show TalkRecordApiException;
import 'package:imboy/store/model/talk_record/talk_record_segment_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_speaker_model.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;
import 'package:imboy/store/repository/user_repo_local.dart';

import 'talk_record_detail_service.dart';
import '../talk_record_auth.dart';
import 'talk_record_detail_request_fence.dart';
import 'talk_record_detail_states.dart';
export 'talk_record_detail_states.dart';
import 'talk_record_playback_service.dart';

// ---------------------------------------------------------------------------
// 注入点（测试 override；T11+ 可换缓存实现）
// ---------------------------------------------------------------------------

final talkRecordDetailServiceProvider = Provider<TalkRecordDetailService>((
  ref,
) {
  return ApiTalkRecordDetailService();
});

final talkRecordPlaybackGatewayProvider = Provider<TalkRecordPlaybackGateway>((
  ref,
) {
  return TalkRecordApiPlaybackGateway();
});

final talkRecordPartsPlaybackGatewayProvider =
    Provider<TalkRecordPartsPlaybackGateway>((ref) {
      return TalkRecordApiPartsPlaybackGateway();
    });

/// 播放后端（just_audio 真实实现；测试注入 Fake，零平台通道）。
/// dispose 由 Provider 生命周期管理。
final talkRecordPlayerBackendProvider = Provider<TalkRecordPlayerBackend>((
  ref,
) {
  final backend = JustAudioTalkRecordPlayerBackend();
  void onAccountChanged() {
    // Native account guard stops immediately; invalidate cached UI tickets and
    // construct a fresh account-bound backend for the next authenticated view.
    ref.invalidate(talkRecordPlayerProvider);
    ref.invalidateSelf();
  }

  UserRepoLocal.to.addAuthListener(onAccountChanged);
  ref.onDispose(() {
    UserRepoLocal.to.removeAuthListener(onAccountChanged);
    backend.dispose();
  });
  return backend;
});

// If-Match 惯例：列表端点不回 ETag 头时以资源 revision 派生版本令牌
// （§11.2 每个可变资源 ETag/revision；T15 联调若改为逐项 ETag 头，仅
/// 需替换以下三个纯函数）。
String talkRecordSegmentEtagOf(TalkRecordSegmentModel s) =>
    'segment:${s.id}:${s.revision}';
String talkRecordSpeakerEtagOf(TalkRecordSpeakerModel s) =>
    'speaker:${s.id}:${s.revision}';

// ---------------------------------------------------------------------------
// 详情（记录 + 摘要 + 重点 + 笔记）
// ---------------------------------------------------------------------------

class TalkRecordDetailNotifier extends Notifier<TalkRecordDetailState> {
  late TalkRecordDetailRequestFence _requests;
  @override
  TalkRecordDetailState build() {
    final requests = TalkRecordDetailRequestFence(() => ref.mounted);
    _requests = requests;
    final remove = ref.read(talkRecordAuthSubscribeProvider)(() {
      requests.reset();
      if (ref.mounted) {
        state = const TalkRecordDetailState();
      }
    });
    ref.onDispose(() {
      requests.reset();
      remove();
    });
    return const TalkRecordDetailState();
  }

  Future<void> bind(EntityId recordId, {bool force = false}) async {
    if (!force &&
        state.recordId == recordId &&
        state.phase != TalkRecordDetailPhase.idle) {
      return;
    }
    _requests.reset();
    state = TalkRecordDetailState(recordId: recordId);
    await reload();
  }

  Future<void> reload() async {
    final id = state.recordId;
    if (id.isEmpty) {
      return;
    }
    final request = _requests.begin();
    state = state.copyWith(phase: TalkRecordDetailPhase.loading);
    try {
      final service = ref.read(talkRecordDetailServiceProvider);
      final record = await service.record(id);
      if (!request.current) {
        return;
      }
      final summary = await service.summary(id);
      if (!request.current) {
        return;
      }
      final marks = await service.marks(id);
      if (!request.current) {
        return;
      }
      state = state.copyWith(
        phase: TalkRecordDetailPhase.ready,
        record: record.data,
        recordEtag: record.etag,
        summary: summary.data,
        marks: marks.list,
        notesPhase: TalkRecordNotesPhase.idle,
      );
    } on Object {
      if (request.current) {
        state = state.copyWith(phase: TalkRecordDetailPhase.failed);
      }
    }
  }

  Future<void> reloadAfterContentChange() => reload();

  Future<bool> saveNotes(String notes) async {
    final record = state.record;
    if (record == null) {
      return false;
    }
    final request = _requests.begin();
    final etag = state.recordEtag;
    state = state.copyWith(notesPhase: TalkRecordNotesPhase.saving);
    try {
      final updated = await ref
          .read(talkRecordDetailServiceProvider)
          .patchNotes(record.id, notes, ifMatch: etag);
      if (!request.current) {
        return false;
      }
      state = state.copyWith(
        record: updated.data,
        recordEtag: updated.etag,
        notesPhase: TalkRecordNotesPhase.saved,
      );
      return true;
    } on TalkRecordApiException catch (e) {
      if (request.current) {
        state = state.copyWith(
          notesPhase: e.isRevisionStale
              ? TalkRecordNotesPhase.conflict
              : TalkRecordNotesPhase.failed,
        );
      }
      return false;
    } on Object {
      if (request.current) {
        state = state.copyWith(notesPhase: TalkRecordNotesPhase.failed);
      }
      return false;
    }
  }

  Future<bool> retryTranscribe() async {
    final record = state.record;
    if (record == null) {
      return false;
    }
    final request = _requests.begin();
    try {
      final accepted = await ref
          .read(talkRecordDetailServiceProvider)
          .retryTranscribe(record.id);
      if (!request.current) {
        return false;
      }
      if (accepted) {
        await reload();
      }
      return accepted && request.scopeCurrent;
    } on Object {
      return false;
    }
  }
}

final talkRecordDetailProvider =
    NotifierProvider<TalkRecordDetailNotifier, TalkRecordDetailState>(
      TalkRecordDetailNotifier.new,
    );

// ---------------------------------------------------------------------------
// 原文片段
// ---------------------------------------------------------------------------

class TalkRecordSegmentsNotifier extends Notifier<TalkRecordSegmentsState> {
  late TalkRecordDetailRequestFence _requests;
  @override
  TalkRecordSegmentsState build() {
    final requests = TalkRecordDetailRequestFence(() => ref.mounted);
    _requests = requests;
    final remove = ref.read(talkRecordAuthSubscribeProvider)(() {
      requests.reset();
      if (ref.mounted) {
        state = const TalkRecordSegmentsState();
      }
    });
    ref.onDispose(() {
      requests.reset();
      remove();
    });
    return const TalkRecordSegmentsState();
  }

  Future<void> bind(EntityId recordId, {bool force = false}) async {
    if (!force &&
        state.recordId == recordId &&
        state.phase != TalkRecordSegmentsPhase.idle) {
      return;
    }
    _requests.reset();
    state = TalkRecordSegmentsState(recordId: recordId);
    await reload();
  }

  Future<void> reload() async {
    final id = state.recordId;
    if (id.isEmpty) {
      return;
    }
    final request = _requests.begin();
    state = state.copyWith(phase: TalkRecordSegmentsPhase.loading);
    try {
      final page = await ref.read(talkRecordDetailServiceProvider).segments(id);
      if (!request.current) {
        return;
      }
      state = state.copyWith(
        phase: TalkRecordSegmentsPhase.ready,
        segments: page.list,
      );
    } on Object {
      if (request.current) {
        state = state.copyWith(phase: TalkRecordSegmentsPhase.failed);
      }
    }
  }

  void setQuery(String q) {
    if (state.recordId.isNotEmpty) {
      state = state.copyWith(query: q.trim());
    }
  }
}

final talkRecordSegmentsProvider =
    NotifierProvider<TalkRecordSegmentsNotifier, TalkRecordSegmentsState>(
      TalkRecordSegmentsNotifier.new,
    );

// ---------------------------------------------------------------------------
// 发言人
// ---------------------------------------------------------------------------

class TalkRecordSpeakersNotifier extends Notifier<TalkRecordSpeakersState> {
  late TalkRecordDetailRequestFence _requests;
  @override
  TalkRecordSpeakersState build() {
    final requests = TalkRecordDetailRequestFence(() => ref.mounted);
    _requests = requests;
    final remove = ref.read(talkRecordAuthSubscribeProvider)(() {
      requests.reset();
      if (ref.mounted) {
        state = const TalkRecordSpeakersState();
      }
    });
    ref.onDispose(() {
      requests.reset();
      remove();
    });
    return const TalkRecordSpeakersState();
  }

  Future<void> bind(EntityId recordId, {bool force = false}) async {
    if (!force &&
        state.recordId == recordId &&
        state.phase != TalkRecordSpeakersPhase.idle) {
      return;
    }
    _requests.reset();
    state = TalkRecordSpeakersState(recordId: recordId);
    await reload();
  }

  Future<void> reload() async {
    final id = state.recordId;
    if (id.isEmpty) {
      return;
    }
    final request = _requests.begin();
    state = state.copyWith(phase: TalkRecordSpeakersPhase.loading);
    try {
      final list = await ref.read(talkRecordDetailServiceProvider).speakers(id);
      if (!request.current) {
        return;
      }
      state = state.copyWith(
        phase: TalkRecordSpeakersPhase.ready,
        speakers: list,
        claimConflict: false,
      );
    } on Object {
      if (request.current) {
        state = state.copyWith(phase: TalkRecordSpeakersPhase.failed);
      }
    }
  }

  Future<bool> setDisplayName(EntityId speakerId, String name) =>
      _patch(speakerId, displayName: name);
  Future<bool> markColleague(EntityId speakerId, EntityId userId) =>
      _patch(speakerId, matchedUserId: userId);
  Future<bool> _patch(
    EntityId speakerId, {
    String? displayName,
    EntityId? matchedUserId,
  }) async {
    TalkRecordSpeakerModel? speaker;
    for (final s in state.speakers) {
      if (s.id == speakerId) {
        speaker = s;
      }
    }
    if (speaker == null) {
      return false;
    }
    final id = state.recordId;
    final request = _requests.begin();
    try {
      await ref
          .read(talkRecordDetailServiceProvider)
          .patchSpeaker(
            id,
            speakerId,
            displayName: displayName,
            matchedUserId: matchedUserId,
            ifMatch: talkRecordSpeakerEtagOf(speaker),
          );
      if (!request.current) {
        return false;
      }
      await reload();
      return request.scopeCurrent;
    } on Object {
      return false;
    }
  }

  Future<bool> claimSelf(EntityId speakerId) async {
    final id = state.recordId;
    if (id.isEmpty) {
      return false;
    }
    final request = _requests.begin();
    try {
      await ref
          .read(talkRecordDetailServiceProvider)
          .claimSpeaker(id, speakerId);
      if (!request.current) {
        return false;
      }
      await reload();
      return request.scopeCurrent;
    } on TalkRecordApiException catch (e) {
      if (request.current && e.isConflict) {
        state = state.copyWith(claimConflict: true);
      }
      return false;
    } on Object {
      return false;
    }
  }
}

final talkRecordSpeakersProvider =
    NotifierProvider<TalkRecordSpeakersNotifier, TalkRecordSpeakersState>(
      TalkRecordSpeakersNotifier.new,
    );

// ---------------------------------------------------------------------------
// 受控回放会话（播放器）
// ---------------------------------------------------------------------------

/// 受控回放 Notifier。
///
/// 会话生命周期（§4 playback + §11.3 撤权边界）：
/// 1. 首次播放/seek：`openTicket`（带 position_ms）→ backend.load(url)；
/// 2. **续签触发点**：play() 时与每个进度回调时检查票据
///    `needsRenew(now, renewLead)` → `renewTicket` → 换 URL 热载并保持
///    当前进度/播放态（无缝换源的真实策略由 T13/T15 联调定稿）；
/// 3. 续签/开票失败（撤权 → 404/403）→ 停止播放并置 failure/unavailable，
///    不回退到任何直读 URL；
/// 4. detach()：stop 并释放（预取量最小化，见后端声明）。
class TalkRecordPlayerNotifier extends Notifier<TalkRecordPlayerState> {
  static const Duration renewLead = Duration(seconds: 60);
  late TalkRecordDetailRequestFence _requests;
  StreamSubscription<TalkRecordPlayerBackendState>? _subscription;
  TalkRecordPlaybackTicket? _ticket;
  TalkRecordPartsTicket? _partsTicket;
  int _partIndex = -1;
  bool _useParts = false;
  bool _movingPart = false;
  bool _completed = false;
  String? _loadedUrl;
  TalkRecordDetailRequest? _renewal;
  TalkRecordPlayerBackend? _attachedBackend;
  Future<void> _stopPending = Future<void>.value();
  Future<void> _sourcePending = Future<void>.value();
  int _sourceCount = 0;
  bool _sourceValid = false;

  @override
  TalkRecordPlayerState build() {
    final requests = TalkRecordDetailRequestFence(() => ref.mounted);
    _requests = requests;
    _clearSession();
    final remove = ref.read(talkRecordAuthSubscribeProvider)(() {
      requests.reset();
      _clearSession();
      if (ref.mounted) {
        state = const TalkRecordPlayerState();
      }
      unawaited(_stopAttached());
    });
    ref.onDispose(() {
      requests.reset();
      remove();
      _clearSession();
      unawaited(_stopAttached());
    });
    return const TalkRecordPlayerState();
  }

  TalkRecordPlayerBackend get _backend =>
      ref.read(talkRecordPlayerBackendProvider);

  void attach({
    required EntityId recordId,
    required int durationMs,
    required bool playbackAllowed,
    bool useParts = false,
  }) {
    if (state.recordId == recordId &&
        _useParts &&
        _partsTicket != null &&
        !useParts) {
      useParts = true;
    }
    if (state.recordId != recordId || _useParts != useParts) {
      _requests.reset();
      _clearSession();
      _useParts = useParts;
      unawaited(_stopAttached());
      state = TalkRecordPlayerState(
        recordId: recordId,
        durationMs: durationMs,
        unavailable: !playbackAllowed,
      );
    } else if (state.durationMs != durationMs ||
        state.unavailable == playbackAllowed) {
      if (!playbackAllowed && !state.unavailable) {
        _requests.reset();
        _clearSession();
        unawaited(_stopAttached());
      }
      state = state.copyWith(
        durationMs: durationMs,
        unavailable: !playbackAllowed,
      );
    }
    _attachedBackend = _backend;
    final scope = _requests.snapshot();
    _subscription ??= _attachedBackend!.states.listen((event) {
      if (scope.scopeCurrent) onBackendState(event);
    });
  }

  void _clearSession() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _ticket = null;
    _partsTicket = null;
    _partIndex = -1;
    _movingPart = false;
    _completed = false;
    _loadedUrl = null;
    _renewal = null;
    _sourceValid = false;
  }

  Future<void> _stopAttached() {
    final backend = _attachedBackend;
    if (backend == null) {
      return _stopPending;
    }
    final stopping = Future<void>.sync(backend.stop);
    final pendingSource = _sourcePending;
    final hasPendingSource = _sourceCount > 0;
    return _stopPending =
        Future.wait<void>([_stopPending, stopping, pendingSource])
            .then((_) async {
              if (hasPendingSource) await backend.stop();
            })
            .then((_) {})
            .catchError(_cleanupFailed);
  }

  Future<bool> _loadSource(
    TalkRecordDetailRequest request,
    TalkRecordPlayerBackend backend,
    String url,
    int positionMs,
  ) async {
    final previous = _sourcePending;
    final finished = Completer<void>();
    _sourcePending = finished.future;
    _sourceCount++;
    try {
      await previous;
      if (!request.current) return false;
      await backend.load(url, initialPositionMs: positionMs);
      if (!request.current) {
        _sourceValid = false;
        await backend.stop();
        return false;
      }
      _sourceValid = true;
      return true;
    } finally {
      _sourceCount--;
      finished.complete();
    }
  }

  void _cleanupFailed(Object error, StackTrace stack) {
    developer.log(
      'Playback UI teardown failed',
      name: 'talk_record',
      error: error.runtimeType,
      stackTrace: stack,
    );
  }

  Future<void> toggle() async {
    if (state.unavailable) {
      return;
    }
    if (!state.playing) {
      await play();
      return;
    }
    final request = _requests.begin();
    try {
      await _backend.pause();
      if (request.current) {
        state = state.copyWith(playing: false);
      }
    } on Object {
      if (request.current) {
        state = state.copyWith(playing: false, failure: true);
      }
    }
  }

  Future<void> play() async {
    if (state.unavailable || state.recordId.isEmpty) {
      return;
    }
    if (_completed) {
      await seekTo(0);
      return;
    }
    final request = _requests.begin();
    final backend = _backend;
    try {
      await _stopPending;
      if (!request.current) {
        return;
      }
      await _ensureTicket(request, backend);
      if (!request.current) {
        return;
      }
      state = state.copyWith(failure: false, playing: true);
      await backend.play();
    } on Object {
      await _failed(request);
    }
  }

  Future<void> seekTo(int positionMs, {bool autoplay = true}) async {
    if (state.unavailable || state.recordId.isEmpty) {
      return;
    }
    final request = _requests.begin();
    _completed = false;
    final backend = _backend;
    final clamped = positionMs.clamp(0, _maxPosition);
    try {
      await _stopPending;
      if (!request.current) {
        return;
      }
      await _ensureTicket(request, backend, clamped);
      if (!request.current) {
        return;
      }
      await backend.seek(_partPosition(clamped));
      if (!request.current) {
        return;
      }
      state = state.copyWith(positionMs: clamped, failure: false);
      if (autoplay) {
        state = state.copyWith(playing: true);
        await backend.play();
      }
    } on Object {
      await _failed(request);
    }
  }

  Future<void> _failed(TalkRecordDetailRequest request) async {
    if (!request.current) {
      return;
    }
    await _stopAttached();
    if (request.current) {
      _ticket = null;
      _partsTicket = null;
      _partIndex = -1;
      _loadedUrl = null;
      state = state.copyWith(playing: false, loaded: false, failure: true);
    }
  }

  void onBackendState(TalkRecordPlayerBackendState value) {
    if (!ref.mounted || state.recordId.isEmpty) {
      return;
    }
    if (value.blocked) {
      _requests.reset();
      _ticket = null;
      _partsTicket = null;
      _partIndex = -1;
      _loadedUrl = null;
      state = state.copyWith(playing: false, loaded: false, failure: true);
      return;
    }
    if (value.failed) {
      final request = _requests.begin();
      state = state.copyWith(playing: false, loaded: false, failure: true);
      unawaited(_failed(request));
      return;
    }
    if (_movingPart) return;
    final parts = _partsTicket?.parts;
    final part = parts != null && _partIndex >= 0 && _partIndex < parts.length
        ? parts[_partIndex]
        : null;
    _completed =
        value.completed && (part == null || _partIndex + 1 >= parts!.length);
    state = state.copyWith(
      positionMs: part == null
          ? value.positionMs
          : part.offsetMs + value.positionMs,
      durationMs: part == null && value.durationMs > 0
          ? value.durationMs
          : state.durationMs,
      playing: value.playing && !value.completed,
      loaded: _loadedUrl != null,
    );
    if (value.completed && part != null && _partIndex + 1 < parts!.length) {
      unawaited(_advancePart(parts[_partIndex + 1].offsetMs));
      return;
    }
    unawaited(_maybeRenew());
  }

  Future<void> _advancePart(int position) async {
    if (_movingPart) return;
    _movingPart = true;
    final request = _requests.begin();
    try {
      await _ensurePartsAt(request, _backend, position);
      if (!request.current) return;
      state = state.copyWith(
        positionMs: position,
        playing: true,
        failure: false,
      );
      _movingPart = false;
      await _backend.play();
    } on Object {
      await _failed(request);
    } finally {
      _movingPart = false;
    }
  }

  Future<void> _maybeRenew() async {
    if (_useParts) {
      final ticket = _partsTicket;
      if (_renewal != null ||
          ticket == null ||
          !state.playing ||
          !ticket.needsRenew(DateTime.now(), renewLead)) {
        return;
      }
      final request = _requests.snapshot();
      _renewal = request;
      _movingPart = true;
      var resume = false;
      try {
        _partsTicket = null;
        _partIndex = -1;
        await _ensurePartsAt(request, _backend, state.positionMs);
        resume = request.current && state.playing;
      } on Object {
        await _failed(request);
      } finally {
        _movingPart = false;
        if (identical(_renewal, request)) _renewal = null;
      }
      if (resume && request.current) {
        try {
          await _backend.play();
        } on Object {
          await _failed(request);
        }
      }
      return;
    }
    final ticket = _ticket;
    if (_renewal != null ||
        ticket == null ||
        !state.playing ||
        !ticket.needsRenew(DateTime.now(), renewLead)) {
      return;
    }
    final request = _requests.snapshot();
    _renewal = request;
    final backend = _backend;
    final id = state.recordId;
    var resume = false;
    try {
      final renewed = await ref
          .read(talkRecordPlaybackGatewayProvider)
          .renewTicket(id, ticket);
      if (!request.current) {
        return;
      }
      final position = state.positionMs, playing = state.playing;
      if (!await _loadSource(request, backend, renewed.url, position)) {
        return;
      }
      _ticket = renewed;
      _loadedUrl = renewed.url;
      resume = playing;
    } on Object {
      await _failed(request);
    } finally {
      if (identical(_renewal, request)) {
        _renewal = null;
      }
    }
    if (resume && request.current) {
      try {
        await backend.play();
      } on Object {
        await _failed(request);
      }
    }
  }

  Future<void> _ensureTicket(
    TalkRecordDetailRequest request,
    TalkRecordPlayerBackend backend, [
    int? targetPosition,
  ]) async {
    if (_useParts) {
      await _ensurePartsAt(
        request,
        backend,
        targetPosition ?? state.positionMs,
      );
      return;
    }
    final now = DateTime.now(), ticket = _ticket;
    if (ticket != null && !ticket.isExpired(now) && _sourceValid) {
      if (ticket.needsRenew(now, renewLead)) {
        await _maybeRenew();
      }
      return;
    }
    final id = state.recordId, position = state.positionMs;
    final fresh = await ref
        .read(talkRecordPlaybackGatewayProvider)
        .openTicket(id, positionMs: position);
    if (!request.current) {
      return;
    }
    if (!await _loadSource(request, backend, fresh.url, position)) {
      return;
    }
    _ticket = fresh;
    _loadedUrl = fresh.url;
    state = state.copyWith(loaded: true);
  }

  int _partPosition(int position) {
    final parts = _partsTicket?.parts;
    if (parts == null || _partIndex < 0 || _partIndex >= parts.length) {
      return position;
    }
    return (position - parts[_partIndex].offsetMs).clamp(
      0,
      parts[_partIndex].durationMs,
    );
  }

  Future<void> _ensurePartsAt(
    TalkRecordDetailRequest request,
    TalkRecordPlayerBackend backend,
    int position,
  ) async {
    var ticket = _partsTicket;
    if (ticket == null || !DateTime.now().isBefore(ticket.expiresAt)) {
      ticket = await ref
          .read(talkRecordPartsPlaybackGatewayProvider)
          .openTicket(state.recordId);
      if (!request.current) return;
      _partsTicket = ticket;
      _partIndex = -1;
    }
    final parts = ticket.parts;
    var index = parts.indexWhere((p) => position < p.offsetMs + p.durationMs);
    if (index < 0) index = parts.length - 1;
    if (!_sourceValid ||
        _partIndex != index ||
        _loadedUrl != parts[index].url) {
      final wasMoving = _movingPart;
      _movingPart = true;
      try {
        final loaded = await _loadSource(
          request,
          backend,
          parts[index].url,
          (position - parts[index].offsetMs).clamp(0, parts[index].durationMs),
        );
        if (!loaded) return;
      } finally {
        _movingPart = wasMoving;
      }
      if (!request.current) return;
      _partIndex = index;
      _loadedUrl = parts[index].url;
      state = state.copyWith(
        loaded: true,
        durationMs: parts.last.offsetMs + parts.last.durationMs,
      );
    }
  }

  int get _maxPosition => state.durationMs > 0 ? state.durationMs : 1 << 40;

  Future<void> detach() async {
    _requests.reset();
    _clearSession();
    final request = _requests.snapshot();
    await _stopAttached();
    if (request.current) {
      state = state.copyWith(playing: false, loaded: false);
    }
  }

  Future<void> scrubTo(int positionMs) => seekTo(positionMs, autoplay: false);
}

final talkRecordPlayerProvider =
    NotifierProvider<TalkRecordPlayerNotifier, TalkRecordPlayerState>(
      TalkRecordPlayerNotifier.new,
    );
