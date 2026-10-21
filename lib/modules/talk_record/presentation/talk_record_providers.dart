/// 面聊记录（talk_record）Riverpod 状态层（T10 UI）。
///
/// Provider 形态说明：项目 codegen（@riverpod）由 build.yaml 的
/// `riverpod_generator.generate_for` 白名单控制，新文件不在名单内且
/// build.yaml 属本任务只读文件，故此处按 lib/page/CLAUDE.md「最小模板」
/// 使用手写 `NotifierProvider`/`FutureProvider`（既有双轨惯例的另一轨）。
/// riverpod 3.4.3 中手写 Provider 默认常驻（isAutoDispose=false），
/// 草稿/录音条状态因此天然跨页面存活（导航不丢稿的前提）。
///
/// 职责划分：
/// - [TalkRecordDraftNotifier]：准备页草稿（标题/保存到/处理方式/参与者/
///   已告知确认），keepAlive 常驻，导航往返不丢；
/// - [talkRecordCapabilitiesProvider] / [talkRecordCreationContextsProvider]：
///   能力与创建上下文（失败不伪装成功，页面按降级/失败态展示）；
/// - [TalkRecordListNotifier]：列表（筛选/搜索/游标翻页，服务注入）；
/// - [TalkRecordActiveCaptureNotifier]：全局录音条占位状态（T09 驱动，
///   本层只存状态不做录音）。
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:imboy/store/api/talk_record_api.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_service.dart';

import '../application/talk_record_recording_runtime.dart';
import '../application/talk_record_recording_coordinator.dart';

import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';

import 'talk_record_entry_context.dart';
import 'talk_record_auth.dart';
import 'talk_record_services.dart';

// ---------------------------------------------------------------------------
// 服务注入点（测试 override；T11+ 可换带缓存的实现）
// ---------------------------------------------------------------------------

final talkRecordListServiceProvider = Provider<TalkRecordListService>((ref) {
  return TalkRecordApiListService();
});

final talkRecordMicPermissionGatewayProvider =
    Provider<TalkRecordMicPermissionGateway>((ref) {
      return const PermissionHandlerMicPermissionGateway();
    });

final talkRecordRecordingLauncherProvider =
    Provider<TalkRecordRecordingLauncher>((ref) {
      return TalkRecordCoordinatorLauncher(
        () => ref.read(talkRecordRecordingRuntimeProvider.future),
      );
    });

/// Non-autoDispose: page removal never terminates the microphone.
final talkRecordRecordingRuntimeProvider =
    FutureProvider<TalkRecordRecordingCoordinator>((ref) async {
      final runtime = await createTalkRecordRecordingRuntime();
      if (!ref.mounted) return runtime;
      final subscription = runtime.updates.listen((snapshot) {
        ref
            .read(talkRecordStopUnconfirmedProvider.notifier)
            .set(runtime.microphoneStopUnconfirmed);
        final local = runtime.binding;
        final bar = ref.read(talkRecordActiveCaptureProvider.notifier);
        if (!snapshot.isActive ||
            local == null ||
            local.account != currentTalkRecordAccount()) {
          bar.hide();
          return;
        }
        bar.show(
          originContext: local.context,
          title: local.title,
          positionMs: snapshot.effectiveDurationMs,
          phase: switch (snapshot.phase) {
            TalkRecordRecorderPhase.recording =>
              TalkRecordCaptureBarPhase.recording,
            TalkRecordRecorderPhase.paused => TalkRecordCaptureBarPhase.paused,
            _ => TalkRecordCaptureBarPhase.interrupted,
          },
        );
      });
      void onAccountChanged() {
        // Privacy projection is cleared before slow microphone/storage work.
        ref.read(talkRecordActiveCaptureProvider.notifier).hide();
        unawaited(
          runtime.accountChanged().catchError((Object error, StackTrace stack) {
            if (ref.mounted) {
              ref
                  .read(talkRecordStopUnconfirmedProvider.notifier)
                  .set(runtime.microphoneStopUnconfirmed);
            }
            developer.log(
              'Recording interruption failed after account change',
              name: 'talk_record',
              error: error.runtimeType,
              stackTrace: stack,
            );
          }),
        );
      }

      UserRepoLocal.to.addAuthListener(onAccountChanged);
      ref.onDispose(() {
        UserRepoLocal.to.removeAuthListener(onAccountChanged);
        unawaited(subscription.cancel());
        // Do not dispose/stop the recorder when a view/provider is disposed.
      });
      try {
        await runtime.discover();
      } on Object {
        /* UI keeps recovery unavailable; no reset. */
      }
      return runtime;
    });

final talkRecordParticipantDirectoryProvider =
    Provider<TalkRecordParticipantDirectory>((ref) {
      return ApiTalkRecordParticipantDirectory(TalkRecordApi());
    });

// ---------------------------------------------------------------------------
// 草稿（导航不丢稿）
// ---------------------------------------------------------------------------

/// 准备页草稿状态。
class TalkRecordDraftState {
  /// 标题（选填；导航到保存位置页往返保留）。
  final String title;

  /// 保存到（null=沿用入口上下文，由页面兜底解析）。
  final TalkRecordEntryContext? saveTo;

  /// 处理方式（按 capabilities 降级；默认仅录音）。
  final TalkRecordProcessingMode processingMode;

  /// 选填参与者（仅企业上下文；跨归属变更时清空）。
  final List<TalkRecordParticipantSelection> participants;

  /// 已告知现场参与者确认。
  final bool noticeAcknowledged;

  const TalkRecordDraftState({
    this.title = '',
    this.saveTo,
    this.processingMode = TalkRecordProcessingMode.recordOnly,
    this.participants = const [],
    this.noticeAcknowledged = false,
  });

  TalkRecordDraftState copyWith({
    String? title,
    TalkRecordEntryContext? saveTo,
    bool clearSaveTo = false,
    TalkRecordProcessingMode? processingMode,
    List<TalkRecordParticipantSelection>? participants,
    bool? noticeAcknowledged,
  }) {
    return TalkRecordDraftState(
      title: title ?? this.title,
      saveTo: clearSaveTo ? null : (saveTo ?? this.saveTo),
      processingMode: processingMode ?? this.processingMode,
      participants: participants ?? this.participants,
      noticeAcknowledged: noticeAcknowledged ?? this.noticeAcknowledged,
    );
  }

  /// 有效保存到（草稿未改过则回落入口上下文）。
  TalkRecordEntryContext effectiveSaveTo(TalkRecordEntryContext entry) {
    return saveTo ?? entry;
  }

  bool get hasParticipants => participants.isNotEmpty;
}

/// 草稿 Notifier（常驻：列表/准备/保存位置页往返不丢稿）。
class TalkRecordDraftNotifier extends Notifier<TalkRecordDraftState> {
  @override
  TalkRecordDraftState build() {
    void changed() => state = const TalkRecordDraftState();
    final remove = ref.read(talkRecordAuthSubscribeProvider)(changed);
    ref.onDispose(remove);
    return const TalkRecordDraftState();
  }

  void setTitle(String value) {
    state = state.copyWith(title: value);
  }

  /// 更换保存位置：跨个人/企业（或跨企业）时清空不适用参与者与共享选择；
  /// 标题保留（DESIGN §9：不静默丢稿）。
  ///
  /// [previousEffective]：草稿未显式改过保存到时的入口有效上下文
  /// （由保存位置页传入）——否则首次变更会因 saveTo==null 漏判跨界，
  /// 参与者不被清空（widget 测试发现的真缺陷）。
  void setSaveTo(
    TalkRecordEntryContext next, {
    TalkRecordEntryContext? previousEffective,
  }) {
    final prev = state.saveTo ?? previousEffective;
    final crossing =
        prev != null &&
        (prev.scope != next.scope ||
            prev.organizationId != next.organizationId ||
            prev.workspaceId != next.workspaceId);
    state = state.copyWith(
      saveTo: next,
      participants: crossing ? const [] : state.participants,
    );
  }

  void setProcessingMode(TalkRecordProcessingMode mode) {
    state = state.copyWith(processingMode: mode);
  }

  /// 参与者勾选切换（不存在则加入，存在则移除）。
  void toggleParticipant(TalkRecordParticipantSelection participant) {
    final exists = state.participants.contains(participant);
    state = state.copyWith(
      participants: exists
          ? state.participants
                .where((p) => p != participant)
                .toList(growable: false)
          : [...state.participants, participant],
    );
  }

  void replaceParticipants(List<TalkRecordParticipantSelection> participants) {
    if (participants.length > 100 ||
        participants.toSet().length != participants.length) {
      throw ArgumentError('Invalid participant selection');
    }
    state = state.copyWith(participants: List.unmodifiable(participants));
  }

  void setNoticeAcknowledged(bool value) {
    state = state.copyWith(noticeAcknowledged: value);
  }

  /// 开始成功或用户显式放弃后清空（V1 单活动草稿）。
  void clear() {
    state = const TalkRecordDraftState();
  }
}

final talkRecordDraftProvider =
    NotifierProvider<TalkRecordDraftNotifier, TalkRecordDraftState>(
      TalkRecordDraftNotifier.new,
    );

// ---------------------------------------------------------------------------
// 能力与创建上下文
// ---------------------------------------------------------------------------

class TalkRecordAuthEpochNotifier extends Notifier<int> {
  @override
  int build() {
    final remove = ref.read(talkRecordAuthSubscribeProvider)(() => state++);
    ref.onDispose(remove);
    return 0;
  }
}

final talkRecordAuthEpochProvider =
    NotifierProvider<TalkRecordAuthEpochNotifier, int>(
      TalkRecordAuthEpochNotifier.new,
    );

/// GET /capabilities（失败返回 null：页面按「能力未知 → 仅录音」降级，
/// 不把加载失败伪装成转写可用）。
final talkRecordCapabilitiesProvider =
    FutureProvider<TalkRecordCapabilitiesModel?>((ref) async {
      ref.watch(talkRecordAuthEpochProvider);
      try {
        return await ref.watch(talkRecordListServiceProvider).capabilities();
      } on Object {
        return null;
      }
    });

/// GET /creation-contexts 首屏集合（失败抛错由页面失败态展示 + 重试）。
final talkRecordCreationContextsProvider =
    FutureProvider<List<TalkRecordCreationContextModel>>((ref) {
      ref.watch(talkRecordAuthEpochProvider);
      return ref
          .watch(talkRecordListServiceProvider)
          .creationContexts(limit: 100);
    });

// ---------------------------------------------------------------------------
// 列表
// ---------------------------------------------------------------------------

/// 列表加载阶段。
enum TalkRecordListPhase { idle, loading, refreshing, ready, failed }

/// 列表状态（入口上下文 + 筛选 + 搜索 + 游标翻页）。
class TalkRecordListState {
  final TalkRecordEntryContext context;
  final TalkRecordListFilter filter;
  final String query;
  final List<TalkRecordModel> records;
  final String nextCursor;
  final bool hasMore;
  final TalkRecordListPhase phase;

  const TalkRecordListState({
    this.context = const TalkRecordEntryContext.personal(),
    this.filter = TalkRecordListFilter.all,
    this.query = '',
    this.records = const [],
    this.nextCursor = '',
    this.hasMore = false,
    this.phase = TalkRecordListPhase.idle,
  });

  TalkRecordListState copyWith({
    TalkRecordEntryContext? context,
    TalkRecordListFilter? filter,
    String? query,
    List<TalkRecordModel>? records,
    String? nextCursor,
    bool? hasMore,
    TalkRecordListPhase? phase,
    bool resetCursor = false,
  }) {
    return TalkRecordListState(
      context: context ?? this.context,
      filter: filter ?? this.filter,
      query: query ?? this.query,
      records: records ?? this.records,
      nextCursor: resetCursor ? '' : (nextCursor ?? this.nextCursor),
      hasMore: resetCursor ? false : (hasMore ?? this.hasMore),
      phase: phase ?? this.phase,
    );
  }
}

/// 列表 Notifier（服务注入；入口绑定/筛选/搜索/翻页统一走 [_fetch]）。
class TalkRecordListNotifier extends Notifier<TalkRecordListState> {
  @override
  TalkRecordListState build() {
    void changed() {
      _requestEpoch++;
      state = const TalkRecordListState();
    }

    final remove = ref.read(talkRecordAuthSubscribeProvider)(changed);
    ref.onDispose(() {
      _requestEpoch++;
      remove();
    });
    return const TalkRecordListState();
  }

  int _requestEpoch = 0;

  /// 页面进入时绑定入口上下文（上下文变化才重置并重载）。
  Future<void> bind(TalkRecordEntryContext context) async {
    if (state.context == context && state.phase != TalkRecordListPhase.idle) {
      return;
    }
    state = TalkRecordListState(context: context);
    await reload(refreshing: false);
  }

  Future<void> setFilter(TalkRecordListFilter filter) async {
    if (state.filter == filter) return;
    state = state.copyWith(filter: filter);
    await reload(refreshing: false);
  }

  Future<void> setQuery(String query) async {
    if (state.query == query.trim()) return;
    state = state.copyWith(query: query.trim());
    await reload(refreshing: false);
  }

  Future<void> reload({bool refreshing = true}) async {
    state = state.copyWith(
      phase: refreshing
          ? TalkRecordListPhase.refreshing
          : TalkRecordListPhase.loading,
      resetCursor: true,
    );
    await _fetch();
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.nextCursor.isEmpty) return;
    await _fetch(cursor: state.nextCursor);
  }

  Future<void> _fetch({String cursor = ''}) async {
    final epoch = ++_requestEpoch;
    try {
      final page = await ref
          .read(talkRecordListServiceProvider)
          .page(
            scope: state.context.isOrganization
                ? TalkRecordScope.organization
                : TalkRecordScope.personal,
            organizationId: state.context.isOrganization
                ? state.context.organizationId
                : null,
            workspaceId: state.context.hasWorkspace
                ? state.context.workspaceId
                : null,
            filter: state.filter,
            q: state.query.isEmpty ? null : state.query,
            cursor: cursor,
          );
      if (!ref.mounted || epoch != _requestEpoch) return;
      state = state.copyWith(
        records: cursor.isEmpty ? page.list : [...state.records, ...page.list],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        phase: TalkRecordListPhase.ready,
      );
    } on Object {
      if (!ref.mounted || epoch != _requestEpoch) return;
      // 失败如实进入 failed 态（保留既有 records 供刷新场景展示）。
      state = state.copyWith(phase: TalkRecordListPhase.failed);
    }
  }
}

final talkRecordListProvider =
    NotifierProvider<TalkRecordListNotifier, TalkRecordListState>(
      TalkRecordListNotifier.new,
    );

// ---------------------------------------------------------------------------
// 全局录音条占位状态（T09 驱动；本层只存状态）
// ---------------------------------------------------------------------------

/// 录音条展示阶段（语义对齐 UI-SPEC §4 状态文案）。
enum TalkRecordCaptureBarPhase { recording, paused, interrupted }

/// 活跃采集占位状态。
class TalkRecordActiveCaptureState {
  final bool visible;

  /// 原归属上下文（跨空间时录音条标注原归属）。
  final TalkRecordEntryContext originContext;
  final TalkRecordCaptureBarPhase phase;

  /// 记录标题（可空）。
  final String title;

  /// 当前有效录音时长（毫秒；暂停不计入）。
  final int positionMs;

  const TalkRecordActiveCaptureState({
    this.visible = false,
    this.originContext = const TalkRecordEntryContext.personal(),
    this.phase = TalkRecordCaptureBarPhase.recording,
    this.title = '',
    this.positionMs = 0,
  });

  TalkRecordActiveCaptureState copyWith({
    bool? visible,
    TalkRecordEntryContext? originContext,
    TalkRecordCaptureBarPhase? phase,
    String? title,
    int? positionMs,
  }) {
    return TalkRecordActiveCaptureState(
      visible: visible ?? this.visible,
      originContext: originContext ?? this.originContext,
      phase: phase ?? this.phase,
      title: title ?? this.title,
      positionMs: positionMs ?? this.positionMs,
    );
  }
}

/// 录音条状态 Notifier：T09 录音引擎写入；页面/条只读展示。
class TalkRecordActiveCaptureNotifier
    extends Notifier<TalkRecordActiveCaptureState> {
  @override
  TalkRecordActiveCaptureState build() => const TalkRecordActiveCaptureState();

  void show({
    required TalkRecordEntryContext originContext,
    TalkRecordCaptureBarPhase phase = TalkRecordCaptureBarPhase.recording,
    String title = '',
    int positionMs = 0,
  }) {
    state = TalkRecordActiveCaptureState(
      visible: true,
      originContext: originContext,
      phase: phase,
      title: title,
      positionMs: positionMs,
    );
  }

  void update({
    TalkRecordCaptureBarPhase? phase,
    String? title,
    int? positionMs,
  }) {
    state = state.copyWith(phase: phase, title: title, positionMs: positionMs);
  }

  void hide() {
    state = const TalkRecordActiveCaptureState();
  }
}

final talkRecordActiveCaptureProvider =
    NotifierProvider<
      TalkRecordActiveCaptureNotifier,
      TalkRecordActiveCaptureState
    >(TalkRecordActiveCaptureNotifier.new);

/// Account-neutral safety state: never contains recording identity or content.
class TalkRecordStopUnconfirmedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final talkRecordStopUnconfirmedProvider =
    NotifierProvider<TalkRecordStopUnconfirmedNotifier, bool>(
      TalkRecordStopUnconfirmedNotifier.new,
    );
