/// 面聊记录（talk_record）分享域 fixture 服务（T18，component 阶段）。
///
/// **声明：fixture 只证明组件行为，不冒充真实授权/撤销/发送生效。**
/// 内存实现模拟 BACKEND-API.md §4/§8/§11.3 端点形状的关键语义：
/// - 门控：caps.share!=true 时 grants() 只返回自己的授权（§4），写操作
///   403；record() 对无权限/不存在统一 404（§11.3 不区分防探测）；
/// - PUT/DELETE grants：If-Match 错配 412；成功推进 record.acl_revision
///   （§11.2 ACL 修订），名单即时更新；
/// - share-candidates：排除创建者与已授权用户（候选≠授权凭证，§8）；
/// - share-card：标题最小化（严格模式只发「面聊记录」定位，§4）；
/// - 卡片发送 fixture 模拟成功/失败并标注示例——**不产生任何真实对外
///   消息**（本卡约束：禁止给真实第三方发任何消息）。
/// 真实联调（T17 双账号授权/回听/撤销）后由 API 实现替换。
library;

import 'package:imboy/config/error_code.dart';
import 'package:imboy/modules/talk_record/talk_record_error.dart'
    show TalkRecordApiException;
import 'package:imboy/store/api/talk_record_api.dart'
    show TalkRecordFetched, TalkRecordShareCardData;
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart'
    show TalkRecordShareCandidateModel;
import 'package:imboy/store/model/talk_record/talk_record_cursor_page.dart';
import 'package:imboy/store/model/talk_record/talk_record_grant_model.dart'
    show TalkRecordGrantInput, TalkRecordGrantModel;
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;

import 'talk_record_share_service.dart';

/// 内存 fixture 分享条目（单记录粒度；测试按需播种多记录）。
class TalkRecordShareFixtureEntry {
  TalkRecordModel record;

  /// acl ETag（If-Match 校验；对应 record.acl_revision）。
  String aclEtag;
  List<TalkRecordGrantModel> grants;
  List<TalkRecordShareCandidateModel> candidates;
  TalkRecordSharePolicy policy;

  /// 当前主体 user_id（非 owner 名单裁剪与卡片生成的 fixture 等价物）。
  EntityId currentUserId;

  /// 已生成的 share-card 数（供测试断言；卡片标注示例）。
  int shareCardCount = 0;

  TalkRecordShareFixtureEntry({
    required this.record,
    required this.aclEtag,
    this.grants = const [],
    this.candidates = const [],
    this.policy = const TalkRecordSharePolicy.allowed(),
    this.currentUserId = '9001',
  });

  bool get isOwner => record.capabilitiesForActor.share;
}

/// fixture 分享服务。
class FixtureTalkRecordShareService implements TalkRecordShareService {
  FixtureTalkRecordShareService(this.entries);

  final List<TalkRecordShareFixtureEntry> entries;

  TalkRecordShareFixtureEntry _entry(EntityId id) {
    return entries.firstWhere(
      (e) => e.record.id == id,
      orElse: () => throw const TalkRecordApiException(
        ErrorCode.NOT_FOUND,
        'record not found (fixture)',
      ),
    );
  }

  void _requireOwner(TalkRecordShareFixtureEntry e) {
    if (!e.isOwner) {
      // §4：只有 owner 可管理 ACL；客户端 caps 推导不构成授权。
      throw const TalkRecordApiException(
        ErrorCode.FORBIDDEN,
        'only owner can manage grants (fixture)',
      );
    }
  }

  void _checkIfMatch(String ifMatch, String etag) {
    if (ifMatch != etag) {
      throw const TalkRecordApiException(
        ErrorCode.PRECONDITION_FAILED,
        'acl revision stale (fixture 412)',
      );
    }
  }

  /// ACL 变更推进 acl_revision（§11.2）并返回新名单 + ETag。
  TalkRecordFetched<List<TalkRecordGrantModel>> _bumpAcl(
    TalkRecordShareFixtureEntry e,
    List<TalkRecordGrantModel> next,
  ) {
    e.record = _copyWithAclRevision(e.record, e.record.aclRevision + 1);
    e.grants = next;
    e.aclEtag = 'acl:${e.record.aclRevision}';
    // 对外只返回活跃名单（revoked 行保留在内存模拟 DB 历史，
    // 与 GET /grants 活跃语义一致，§2 活跃 UNIQUE）。
    return TalkRecordFetched(_activeGrantsOf(e), etag: e.aclEtag);
  }

  static TalkRecordModel _copyWithAclRevision(TalkRecordModel r, int v) {
    return TalkRecordModel(
      id: r.id,
      ownerUserId: r.ownerUserId,
      createdBy: r.createdBy,
      clientRecordingId: r.clientRecordingId,
      sourceType: r.sourceType,
      scope: r.scope,
      organizationId: r.organizationId,
      workspaceId: r.workspaceId,
      title: r.title,
      language: r.language,
      activeCaptureId: r.activeCaptureId,
      captureStatus: r.captureStatus,
      mediaStatus: r.mediaStatus,
      transcriptStatus: r.transcriptStatus,
      summaryStatus: r.summaryStatus,
      processingMode: r.processingMode,
      durationMs: r.durationMs,
      currentTranscriptId: r.currentTranscriptId,
      contentRevision: r.contentRevision,
      notes: r.notes,
      revision: r.revision,
      aclRevision: v,
      createdAt: r.createdAt,
      updatedAt: DateTime.now(),
      endedAt: r.endedAt,
      deletedAt: r.deletedAt,
      retentionUntil: r.retentionUntil,
      cleanupStatus: r.cleanupStatus,
      visibility: r.visibility,
      capabilitiesForActor: r.capabilitiesForActor,
    );
  }

  @override
  Future<TalkRecordFetched<TalkRecordModel>> record(EntityId id) async {
    final e = _entry(id);
    if (!e.isOwner && !_hasActiveGrant(e, e.currentUserId)) {
      // §11.3：无权限或不存在统一 404，不披露具体原因。
      throw const TalkRecordApiException(
        ErrorCode.NOT_FOUND,
        'no access (fixture)',
      );
    }
    return TalkRecordFetched(e.record, etag: 'record:${e.record.revision}');
  }

  bool _hasActiveGrant(TalkRecordShareFixtureEntry e, EntityId userId) {
    return e.grants.any((g) => g.isActive && g.granteeUserId == userId);
  }

  static List<TalkRecordGrantModel> _activeGrantsOf(
    TalkRecordShareFixtureEntry e,
  ) => e.grants.where((g) => g.isActive).toList(growable: false);

  @override
  Future<TalkRecordFetched<List<TalkRecordGrantModel>>> grants(
    EntityId id,
  ) async {
    final e = _entry(id);
    if (e.isOwner) {
      // §4/§11.3：完整接收者名单只有 owner 可读（仅活跃行）。
      return TalkRecordFetched(_activeGrantsOf(e), etag: e.aclEtag);
    }
    // 其他人只看自己的权限（§4）。
    final mine = e.grants
        .where((g) => g.isActive && g.granteeUserId == e.currentUserId)
        .toList(growable: false);
    return TalkRecordFetched(mine, etag: e.aclEtag);
  }

  @override
  Future<TalkRecordFetched<List<TalkRecordGrantModel>>> putGrants(
    EntityId id, {
    required List<TalkRecordGrantInput> grants,
    required String ifMatch,
  }) async {
    final e = _entry(id);
    _requireOwner(e);
    _checkIfMatch(ifMatch, e.aclEtag);
    // 活跃 UNIQUE(record_id, grantee_user_id)（§2）：全量清单内去重，
    // 重复提交同人以最后一次为准。
    final byUser = <EntityId, TalkRecordGrantModel>{};
    var nextId = 7000 + e.record.aclRevision * 100;
    for (final input in grants) {
      byUser[input.granteeUserId] = TalkRecordGrantModel(
        id: _existingGrantId(e, input.granteeUserId) ?? '${nextId++}',
        recordId: e.record.id,
        granteeUserId: input.granteeUserId,
        granteeDisplayName: _displayNameOf(e, input.granteeUserId),
        role: input.role,
        allowExport: input.allowExport,
        grantedBy: e.currentUserId,
        expiresAt: input.expiresAt,
      );
    }
    // 保留已撤销记录的历史行（isActive=false 不出现在名单）。
    final revoked = e.grants.where((g) => !g.isActive).toList();
    return _bumpAcl(e, [...byUser.values, ...revoked]);
  }

  String? _existingGrantId(TalkRecordShareFixtureEntry e, EntityId userId) {
    for (final g in e.grants) {
      if (g.granteeUserId == userId) return g.id;
    }
    return null;
  }

  String _displayNameOf(TalkRecordShareFixtureEntry e, EntityId userId) {
    for (final g in e.grants) {
      if (g.granteeUserId == userId && g.granteeDisplayName.isNotEmpty) {
        return g.granteeDisplayName;
      }
    }
    for (final c in e.candidates) {
      if (c.userId == userId) return c.displayName;
    }
    return userId;
  }

  @override
  Future<TalkRecordFetched<List<TalkRecordGrantModel>>> revokeGrant(
    EntityId id,
    EntityId grantId, {
    required String ifMatch,
  }) async {
    final e = _entry(id);
    _requireOwner(e);
    _checkIfMatch(ifMatch, e.aclEtag);
    final target = e.grants.where((g) => g.id == grantId).toList();
    if (target.isEmpty || !target.first.isActive) {
      throw const TalkRecordApiException(
        ErrorCode.NOT_FOUND,
        'grant not found (fixture)',
      );
    }
    // 撤销 = revokedAt 落位（§4 立即失效；§11.3 不承诺收回已导出副本）。
    final revokedGrant = TalkRecordGrantModel(
      id: target.first.id,
      recordId: target.first.recordId,
      granteeUserId: target.first.granteeUserId,
      granteeDisplayName: target.first.granteeDisplayName,
      role: target.first.role,
      allowExport: target.first.allowExport,
      grantedBy: target.first.grantedBy,
      revokedAt: DateTime.now(),
      expiresAt: target.first.expiresAt,
    );
    final next = e.grants
        .map((g) => g.id == grantId ? revokedGrant : g)
        .toList();
    return _bumpAcl(e, next);
  }

  @override
  Future<TalkRecordCursorPage<TalkRecordShareCandidateModel>> shareCandidates(
    EntityId id, {
    String? q,
    String cursor = '',
    int? limit,
  }) async {
    final e = _entry(id);
    var rows = e.candidates
        .where(
          (c) =>
              c.userId != e.record.ownerUserId && !_hasActiveGrant(e, c.userId),
        )
        .toList();
    if (q != null && q.isNotEmpty) {
      final kw = q.toLowerCase();
      rows = rows
          .where(
            (c) =>
                c.displayName.toLowerCase().contains(kw) ||
                c.account.toLowerCase().contains(kw),
          )
          .toList();
    }
    return TalkRecordCursorPage(list: rows, nextCursor: '', hasMore: false);
  }

  @override
  Future<TalkRecordShareCardData> shareCard(EntityId id) async {
    final e = _entry(id);
    if (!e.isOwner && !_hasActiveGrant(e, e.currentUserId)) {
      throw const TalkRecordApiException(
        ErrorCode.NOT_FOUND,
        'no access (fixture)',
      );
    }
    e.shareCardCount++;
    // §4：标题最小化（严格模式只发「面聊记录」定位，不泄露完整标题）。
    return TalkRecordShareCardData(
      cardType: 'talk_record_card',
      recordId: e.record.id,
      title: '面聊记录',
      raw: const {'fixture': true},
    );
  }

  @override
  Future<TalkRecordSharePolicy> sharePolicy(EntityId id) async {
    return _entry(id).policy;
  }
}

/// 卡片发送 fixture：可编程成功/失败；**结果为示例，不产生真实消息**。
class FixtureShareCardSender implements TalkRecordShareCardSender {
  FixtureShareCardSender({this.shouldSucceed = true});

  final bool shouldSucceed;

  /// 已「发送」的卡片（仅 fixture 计数，供测试断言；非真实投递）。
  final List<TalkRecordShareCardData> sentCards = [];

  @override
  bool get isAvailable => true;

  @override
  Future<TalkRecordCardSendResult> send(TalkRecordShareCardData card) async {
    if (!shouldSucceed) return TalkRecordCardSendResult.failed;
    sentCards.add(card);
    return TalkRecordCardSendResult.sent;
  }
}

// ---------------------------------------------------------------------------
// 场景构造器（fixture 数据——仅证明组件行为，人名均为虚构）
// ---------------------------------------------------------------------------

/// 按场景播种 fixture 服务。所有候选/授权人为虚构用户，不对应真实账号。
class TalkRecordShareFixtureScenarios {
  static const _ownerCaps = {
    'edit': true,
    'share': true,
    'export': true,
    'can_delete': true,
    'playback': true,
  };
  static const _editorCaps = {
    'edit': true,
    'share': false,
    'export': false,
    'can_delete': false,
    'playback': true,
  };
  static const _viewerCaps = {
    'edit': false,
    'share': false,
    'export': false,
    'can_delete': false,
    'playback': true,
  };

  /// 基础条目构造。
  static TalkRecordShareFixtureEntry entry({
    required String recordId,
    String title = '项目例会',
    String scope = 'organization',
    String visibility = 'shared_with_grants',
    Map<String, dynamic> caps = _ownerCaps,
    String currentUserId = '9001',
    List<TalkRecordGrantModel> grants = const [],
    TalkRecordSharePolicy policy = const TalkRecordSharePolicy.allowed(),
  }) {
    final record = TalkRecordModel.fromJson({
      'id': recordId,
      'owner_user_id': currentUserId,
      'created_by': currentUserId,
      'title': title,
      'scope': scope,
      'capture_status': 'ended',
      'media_status': 'available',
      'transcript_status': 'ready',
      'summary_status': 'draft',
      'processing_mode': 'summarize',
      'duration_ms': 655_000,
      'revision': 2,
      'acl_revision': 1,
      'visibility': visibility,
      'capabilities_for_actor': caps,
    });
    return TalkRecordShareFixtureEntry(
      record: record,
      aclEtag: 'acl:1',
      grants: grants,
      candidates: defaultCandidates(),
      policy: policy,
      currentUserId: currentUserId,
    );
  }

  /// 默认虚构候选集（企业同事/个人联系人通用形状；均已排除授权）。
  static List<TalkRecordShareCandidateModel> defaultCandidates() => [
    for (var i = 0; i < 4; i++)
      TalkRecordShareCandidateModel.fromJson({
        'user_id': '${9101 + i}',
        'display_name': _candidateName(i),
        'account': 'member${i + 1}@fixture.example',
      }),
  ];

  static String _candidateName(int i) => const ['陈晰', '林早', '赵示例', '周测'][i % 4];

  /// 虚构授权行。
  static TalkRecordGrantModel grant({
    required String id,
    required String granteeUserId,
    required String name,
    String role = 'viewer',
    bool allowExport = false,
    DateTime? expiresAt,
  }) {
    return TalkRecordGrantModel.fromJson({
      'id': id,
      'record_id': '1001',
      'grantee_user_id': granteeUserId,
      'grantee_display_name': name,
      'role': role,
      'allow_export': allowExport,
      'granted_by': '9001',
      if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
    });
  }

  /// owner + 0 授权（UI-SPEC 冻结：无任何授权时不提供「发送卡片」主操作）。
  static FixtureTalkRecordShareService ownerZeroGrants({
    String recordId = '1001',
    TalkRecordSharePolicy policy = const TalkRecordSharePolicy.allowed(),
  }) {
    return FixtureTalkRecordShareService([
      entry(
        recordId: recordId,
        visibility: 'owner_only',
        policy: policy,
        grants: const [],
      ),
    ]);
  }

  /// owner + 多授权（viewer + editor + 可导出 + 到期各形态）。
  static FixtureTalkRecordShareService ownerWithGrants({
    String recordId = '1001',
    TalkRecordSharePolicy policy = const TalkRecordSharePolicy.allowed(),
  }) {
    return FixtureTalkRecordShareService([
      entry(
        recordId: recordId,
        policy: policy,
        grants: [
          grant(id: '6001', granteeUserId: '9101', name: '陈晰', role: 'viewer'),
          grant(
            id: '6002',
            granteeUserId: '9102',
            name: '林早',
            role: 'editor',
            allowExport: true,
          ),
          grant(
            id: '6003',
            granteeUserId: '9103',
            name: '赵示例',
            role: 'viewer',
            allowExport: true,
            expiresAt: DateTime(2099, 1, 1),
          ),
        ],
      ),
    ]);
  }

  /// 非-owner（editor，caps.share=false）+ 自己的授权 → 只读权限视图。
  static FixtureTalkRecordShareService editorWithOwnGrant({
    String recordId = '1001',
  }) {
    return FixtureTalkRecordShareService([
      entry(
        recordId: recordId,
        caps: _editorCaps,
        currentUserId: '9102',
        grants: [
          grant(
            id: '6002',
            granteeUserId: '9102',
            name: '林早',
            role: 'editor',
            allowExport: true,
          ),
        ],
      ),
    ]);
  }

  /// 非-owner（viewer）无授权 → record() 统一 404（§11.3）。
  static FixtureTalkRecordShareService viewerNoAccess({
    String recordId = '1001',
  }) {
    return FixtureTalkRecordShareService([
      entry(recordId: recordId, caps: _viewerCaps, currentUserId: '9104'),
    ]);
  }
}
