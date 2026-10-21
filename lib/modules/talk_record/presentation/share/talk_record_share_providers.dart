/// 面聊记录（talk_record）分享域状态层（T18 UI）。
///
/// Provider 形态与 T10/T16 一致：手写 Notifier/Provider（build.yaml 白名单
/// 不含新文件）。服务与卡片发送通道注入点化——widget 测试零网络零平台
/// 通道（fixture 注入）。
///
/// 职责划分：
/// - [TalkRecordShareCenterNotifier]：分享中心（record + grants + 策略；
///   门控由 capabilities_for_actor.share 驱动；保存/撤销/发卡反馈）；
/// - [TalkRecordShareCandidatesNotifier]：候选集（新建授权选人）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/modules/talk_record/talk_record_error.dart'
    show TalkRecordApiException;
import 'package:imboy/store/api/talk_record_api.dart'
    show TalkRecordShareCardData;
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart'
    show TalkRecordShareCandidateModel;
import 'package:imboy/store/model/talk_record/talk_record_grant_model.dart'
    show TalkRecordGrantInput, TalkRecordGrantModel;
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;

import 'talk_record_share_service.dart';
import 'talk_record_card_sender.dart';
import '../talk_record_auth.dart';

// ---------------------------------------------------------------------------
// 注入点（测试 override；T17 联调换真实实现）
// ---------------------------------------------------------------------------

final talkRecordShareServiceProvider = Provider<TalkRecordShareService>((ref) {
  return ApiTalkRecordShareService();
});

/// 卡片发送通道（默认未接入：不产生任何对外消息；fixture 注入证明行为）。
final talkRecordShareCardSenderProvider = Provider<TalkRecordShareCardSender>((
  ref,
) {
  return ImTalkRecordShareCardSender(ref);
});

// acl ETag 惯例：grants 端点不回 ETag 头时以 acl_revision 派生版本令牌
// （§11.2 acl_revision 在授权/撤销/失效/移交时推进；T17 联调若改为逐项
// ETag 头，仅替换此纯函数）。
String talkRecordAclEtagOf(int aclRevision) => 'acl:$aclRevision';

// ---------------------------------------------------------------------------
// 分享中心（record + grants + 策略 + 保存/撤销/发卡反馈）
// ---------------------------------------------------------------------------

enum TalkRecordSharePhase { idle, loading, ready, failed, noAccess }

/// 「权限已保存」与「卡片已发送」是两条独立反馈（UI-SPEC §2/DESIGN §10：
/// 主按钮不把两者混成自动通知）。
enum TalkRecordCardSendPhase {
  idle,
  sending,
  sent,
  failed,
  unavailable,
  cancelled,
  pending,
}

enum TalkRecordShareWritePhase { idle, saving, conflict, failed }

class TalkRecordShareCenterState {
  final EntityId recordId;
  final TalkRecordSharePhase phase;

  /// null 时（loading/failed/noAccess）其他字段无效。
  final TalkRecordModel? record;

  /// owner=全量名单；非 owner=仅自己的授权（§4；空列表=自己无授权）。
  final List<TalkRecordGrantModel> grants;
  final String aclEtag;
  final TalkRecordSharePolicy? policy;

  /// 「权限已保存」反馈（保存授权成功后置 true；发送卡片不置位）。
  final bool savedFeedback;

  /// 卡片发送反馈（「已发送」仅在真实成功后出现；fixture 标注示例）。
  final TalkRecordCardSendPhase cardSendPhase;

  /// 保存/撤销失败分型（412 冲突单独提示刷新）。
  final TalkRecordShareWritePhase writePhase;

  const TalkRecordShareCenterState({
    this.recordId = '',
    this.phase = TalkRecordSharePhase.idle,
    this.record,
    this.grants = const [],
    this.aclEtag = '',
    this.policy,
    this.savedFeedback = false,
    this.cardSendPhase = TalkRecordCardSendPhase.idle,
    this.writePhase = TalkRecordShareWritePhase.idle,
  });

  /// 当前主体是否可管理 ACL（门控真源：服务端 capabilities_for_actor）。
  bool get canManage => record?.capabilitiesForActor.share ?? false;

  /// 活跃授权名单（§2 活跃 UNIQUE；撤销行不出现）。
  List<TalkRecordGrantModel> get activeGrants =>
      grants.where((g) => g.isActive).toList(growable: false);

  /// 自己的授权（非 owner 只读权限视图数据源）。
  TalkRecordGrantModel? get ownGrant {
    for (final g in activeGrants) {
      return g;
    }
    return null;
  }

  TalkRecordShareCenterState copyWith({
    EntityId? recordId,
    TalkRecordSharePhase? phase,
    TalkRecordModel? record,
    List<TalkRecordGrantModel>? grants,
    String? aclEtag,
    TalkRecordSharePolicy? policy,
    bool? savedFeedback,
    TalkRecordCardSendPhase? cardSendPhase,
    TalkRecordShareWritePhase? writePhase,
  }) {
    return TalkRecordShareCenterState(
      recordId: recordId ?? this.recordId,
      phase: phase ?? this.phase,
      record: record ?? this.record,
      grants: grants ?? this.grants,
      aclEtag: aclEtag ?? this.aclEtag,
      policy: policy ?? this.policy,
      savedFeedback: savedFeedback ?? this.savedFeedback,
      cardSendPhase: cardSendPhase ?? this.cardSendPhase,
      writePhase: writePhase ?? this.writePhase,
    );
  }
}

class TalkRecordShareCenterNotifier
    extends Notifier<TalkRecordShareCenterState> {
  @override
  TalkRecordShareCenterState build() {
    void changed() {
      _epoch++;
      state = const TalkRecordShareCenterState();
    }

    final remove = ref.read(talkRecordAuthSubscribeProvider)(changed);
    ref.onDispose(() {
      _epoch++;
      remove();
    });
    return const TalkRecordShareCenterState();
  }

  int _epoch = 0;
  bool _current(int epoch) => ref.mounted && epoch == _epoch;

  Future<void> bind(EntityId recordId, {bool force = false}) async {
    if (!force &&
        state.recordId == recordId &&
        state.phase != TalkRecordSharePhase.idle) {
      return;
    }
    state = TalkRecordShareCenterState(recordId: recordId);
    await reload();
  }

  Future<void> reload() async {
    final id = state.recordId;
    if (id.isEmpty) return;
    final epoch = ++_epoch;
    state = state.copyWith(phase: TalkRecordSharePhase.loading);
    try {
      final service = ref.read(talkRecordShareServiceProvider);
      final record = await service.record(id);
      if (!_current(epoch)) return;
      final grants = await service.grants(id);
      if (!_current(epoch)) return;
      final policy = await service.sharePolicy(id);
      if (!_current(epoch)) return;
      state = state.copyWith(
        phase: TalkRecordSharePhase.ready,
        record: record.data,
        grants: grants.data,
        aclEtag: grants.etag,
        policy: policy,
      );
    } on TalkRecordApiException catch (e) {
      if (!_current(epoch)) return;
      // §11.3：无权限/不存在统一 404 → 通用失效视图（不泄露原因）。
      state = state.copyWith(
        phase: e.isNoAccess
            ? TalkRecordSharePhase.noAccess
            : TalkRecordSharePhase.failed,
      );
    } on Object {
      if (!_current(epoch)) return;
      state = state.copyWith(phase: TalkRecordSharePhase.failed);
    }
  }

  /// 保存/更新单条授权（PUT 全量语义：现有名单 + 新项/替换项）。
  /// 仅 owner（服务端鉴权；客户端门控只是展示层）。
  Future<bool> saveGrant(TalkRecordGrantInput input) async {
    if (state.record == null) return false;
    state = state.copyWith(writePhase: TalkRecordShareWritePhase.saving);
    final next = <TalkRecordGrantInput>[];
    var replaced = false;
    for (final g in state.activeGrants) {
      if (g.granteeUserId == input.granteeUserId) {
        next.add(input);
        replaced = true;
      } else {
        next.add(
          TalkRecordGrantInput(
            granteeUserId: g.granteeUserId,
            role: g.role,
            allowExport: g.allowExport,
            expiresAt: g.expiresAt,
          ),
        );
      }
    }
    if (!replaced) next.add(input);
    return _submitGrants(next, savedOnSuccess: true);
  }

  /// 撤销授权（DELETE 单条；成功后名单即时更新，§4 立即失效）。
  Future<bool> revokeGrant(EntityId grantId) async {
    if (state.record == null) return false;
    state = state.copyWith(writePhase: TalkRecordShareWritePhase.saving);
    final epoch = ++_epoch;
    final service = ref.read(talkRecordShareServiceProvider);
    try {
      final result = await service.revokeGrant(
        state.recordId,
        grantId,
        ifMatch: state.aclEtag,
      );
      if (!_current(epoch)) return false;
      state = state.copyWith(
        grants: result.data,
        aclEtag: result.etag,
        savedFeedback: false,
        writePhase: TalkRecordShareWritePhase.idle,
      );
      return true;
    } on TalkRecordApiException catch (e) {
      if (!_current(epoch)) return false;
      state = state.copyWith(
        writePhase: e.isRevisionStale
            ? TalkRecordShareWritePhase.conflict
            : TalkRecordShareWritePhase.failed,
      );
      return false;
    } on Object {
      if (!_current(epoch)) return false;
      state = state.copyWith(writePhase: TalkRecordShareWritePhase.failed);
      return false;
    }
  }

  Future<bool> _submitGrants(
    List<TalkRecordGrantInput> inputs, {
    required bool savedOnSuccess,
  }) async {
    final epoch = ++_epoch;
    final service = ref.read(talkRecordShareServiceProvider);
    try {
      final result = await service.putGrants(
        state.recordId,
        grants: inputs,
        ifMatch: state.aclEtag,
      );
      if (!_current(epoch)) return false;
      state = state.copyWith(
        grants: result.data,
        aclEtag: result.etag,
        savedFeedback: savedOnSuccess,
        cardSendPhase: TalkRecordCardSendPhase.idle,
        writePhase: TalkRecordShareWritePhase.idle,
      );
      return true;
    } on TalkRecordApiException catch (e) {
      if (!_current(epoch)) return false;
      state = state.copyWith(
        writePhase: e.isRevisionStale
            ? TalkRecordShareWritePhase.conflict
            : TalkRecordShareWritePhase.failed,
      );
      return false;
    } on Object {
      if (!_current(epoch)) return false;
      state = state.copyWith(writePhase: TalkRecordShareWritePhase.failed);
      return false;
    }
  }

  /// 发送分享卡片（与保存授权完全分离的独立动作）：
  /// 1. shareCard() 生成受控定位数据（不额外授权、不发消息，§4）；
  /// 2. sender 可用 → 模拟/真实发送；「已发送」仅真实成功后显示；
  /// 3. 发送通道未接入（默认）→ unavailable 如实提示，不显示「已发送」。
  Future<void> sendCard() async {
    if (state.record == null ||
        state.cardSendPhase == TalkRecordCardSendPhase.sending) {
      return;
    }
    state = state.copyWith(cardSendPhase: TalkRecordCardSendPhase.sending);
    final epoch = ++_epoch;
    final service = ref.read(talkRecordShareServiceProvider);
    try {
      final card = await service.shareCard(state.recordId);
      if (!_current(epoch)) return;
      final sender = ref.read(talkRecordShareCardSenderProvider);
      if (!sender.isAvailable) {
        state = state.copyWith(
          cardSendPhase: TalkRecordCardSendPhase.unavailable,
        );
        return;
      }
      final sent = await sender.send(card);
      if (!_current(epoch)) return;
      state = state.copyWith(
        cardSendPhase: switch (sent) {
          TalkRecordCardSendResult.sent => TalkRecordCardSendPhase.sent,
          TalkRecordCardSendResult.cancelled =>
            TalkRecordCardSendPhase.cancelled,
          TalkRecordCardSendResult.pending => TalkRecordCardSendPhase.pending,
          TalkRecordCardSendResult.unavailable =>
            TalkRecordCardSendPhase.unavailable,
          TalkRecordCardSendResult.stale => TalkRecordCardSendPhase.idle,
          _ => TalkRecordCardSendPhase.failed,
        },
      );
    } on Object {
      if (!_current(epoch)) return;
      state = state.copyWith(cardSendPhase: TalkRecordCardSendPhase.failed);
    }
  }
}

final talkRecordShareCenterProvider =
    NotifierProvider<TalkRecordShareCenterNotifier, TalkRecordShareCenterState>(
      TalkRecordShareCenterNotifier.new,
    );

// ---------------------------------------------------------------------------
// 候选集（新建授权选人）
// ---------------------------------------------------------------------------

enum TalkRecordCandidatesPhase { idle, loading, ready, failed }

class TalkRecordShareCandidatesState {
  final EntityId recordId;
  final TalkRecordCandidatesPhase phase;
  final List<TalkRecordShareCandidateModel> candidates;
  final String query;

  const TalkRecordShareCandidatesState({
    this.recordId = '',
    this.phase = TalkRecordCandidatesPhase.idle,
    this.candidates = const [],
    this.query = '',
  });

  TalkRecordShareCandidatesState copyWith({
    EntityId? recordId,
    TalkRecordCandidatesPhase? phase,
    List<TalkRecordShareCandidateModel>? candidates,
    String? query,
  }) {
    return TalkRecordShareCandidatesState(
      recordId: recordId ?? this.recordId,
      phase: phase ?? this.phase,
      candidates: candidates ?? this.candidates,
      query: query ?? this.query,
    );
  }
}

class TalkRecordShareCandidatesNotifier
    extends Notifier<TalkRecordShareCandidatesState> {
  @override
  TalkRecordShareCandidatesState build() {
    void changed() {
      _epoch++;
      state = const TalkRecordShareCandidatesState();
    }

    final remove = ref.read(talkRecordAuthSubscribeProvider)(changed);
    ref.onDispose(() {
      _epoch++;
      remove();
    });
    return const TalkRecordShareCandidatesState();
  }

  int _epoch = 0;
  bool _current(int epoch) => ref.mounted && epoch == _epoch;

  Future<void> bind(EntityId recordId) async {
    if (state.recordId == recordId &&
        state.phase != TalkRecordCandidatesPhase.idle) {
      return;
    }
    state = TalkRecordShareCandidatesState(recordId: recordId);
    await reload();
  }

  Future<void> reload() async {
    final id = state.recordId;
    if (id.isEmpty) return;
    final epoch = ++_epoch;
    state = state.copyWith(phase: TalkRecordCandidatesPhase.loading);
    try {
      final page = await ref
          .read(talkRecordShareServiceProvider)
          .shareCandidates(id, q: state.query.isEmpty ? null : state.query);
      if (!_current(epoch)) return;
      state = state.copyWith(
        phase: TalkRecordCandidatesPhase.ready,
        candidates: page.list,
      );
    } on Object {
      if (!_current(epoch)) return;
      // 候选目录不可用：如实失败（编辑权限页提示，不猜候选人）。
      state = state.copyWith(phase: TalkRecordCandidatesPhase.failed);
    }
  }

  Future<void> setQuery(String q) async {
    state = state.copyWith(query: q.trim());
    await reload();
  }
}

final talkRecordShareCandidatesProvider =
    NotifierProvider<
      TalkRecordShareCandidatesNotifier,
      TalkRecordShareCandidatesState
    >(TalkRecordShareCandidatesNotifier.new);

/// 共享卡片数据展示辅助（fixture 卡片标注示例；真实卡片由 IM 渲染）。
String? talkRecordCardFixtureBadgeOf(TalkRecordShareCardData card) {
  return card.raw['fixture'] == true ? 'fixture' : null;
}
