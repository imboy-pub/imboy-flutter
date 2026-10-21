/// 面聊记录（talk_record）详情域服务抽象（T16）。
///
/// 页面不直接持有 [TalkRecordApi]：详情/原文/说话人/摘要/重点/笔记全部经
/// 此抽象网关注入（对齐 T10 talk_record_services.dart 纪律）：
/// 1. widget 测试零网络（fixture 注入，见 talk_record_fixture_service.dart）；
/// 2. T15 联调时替换为带缓存/ETag 管理的实现而无需改页面；
/// 3. 失败如实抛 [TalkRecordApiException]（412 语义驱动冲突 UI），不吞错。
///
/// 契约源：BACKEND-API.md §4（GET /:id、PATCH /:id notes、segments/speakers/
/// summary/marks 端点、jobs retry）+ §11.2（content_revision 推进与摘要 stale）。
/// 端点均未实现——默认实现是真实 API 薄封装（失败如实展示），
/// fixture 实现仅用于组件行为验证，不冒充真实转写数据质量。
library;

import 'package:imboy/modules/talk_record/talk_record_error.dart'
    show TalkRecordApiException;
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_cursor_page.dart';
import 'package:imboy/store/model/talk_record/talk_record_mark_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_segment_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_speaker_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_summary_model.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;

/// 详情域数据服务抽象（T16 UI 消费面）。
abstract class TalkRecordDetailService {
  /// GET /:id（元数据 + capabilities_for_actor + ETag）。
  Future<TalkRecordFetched<TalkRecordModel>> record(EntityId id);

  /// PATCH /:id notes（共享补充笔记；If-Match 必带，§4）。
  Future<TalkRecordFetched<TalkRecordModel>> patchNotes(
    EntityId id,
    String notes, {
    required String ifMatch,
  });

  /// GET /:id/segments（start_ms 正序；q 服务端过滤，组件阶段客户端高亮）。
  Future<TalkRecordCursorPage<TalkRecordSegmentModel>> segments(
    EntityId id, {
    EntityId? speakerId,
    String? q,
    String cursor = '',
    int? limit,
  });

  /// PATCH /:id/segments/:segment_id（text + If-Match；成功后服务端推进
  /// record.content_revision 并把摘要标 stale，§11.2）。
  Future<TalkRecordFetched<TalkRecordSegmentModel>> patchSegment(
    EntityId id,
    EntityId segmentId, {
    String? text,
    EntityId? speakerId,
    required String ifMatch,
  });

  /// GET /:id/speakers（匿名标签/人工姓名/绑定来源；不暴露 embedding）。
  Future<List<TalkRecordSpeakerModel>> speakers(EntityId id);

  /// PATCH /:id/speakers/:speaker_id（display_name/matched_user_id；
  /// 服务端设 manual，客户端不能指定 self_claim，§4）。
  Future<TalkRecordSpeakerModel> patchSpeaker(
    EntityId id,
    EntityId speakerId, {
    String? displayName,
    EntityId? matchedUserId,
    required String ifMatch,
  });

  /// POST /:id/speakers/:speaker_id/claim（仅本人；已有他人认领 409）。
  Future<TalkRecordSpeakerModel> claimSpeaker(EntityId id, EntityId speakerId);

  /// GET /:id/summary（未生成返回状态对象，不伪装 404，§4）。
  Future<TalkRecordFetched<TalkRecordSummaryModel>> summary(EntityId id);

  /// GET /:id/marks（start_ms 正序）。
  Future<TalkRecordCursorPage<TalkRecordMarkModel>> marks(
    EntityId id, {
    String cursor = '',
    int? limit,
  });

  /// POST /:id/jobs/:job_id/retry 的转写重试子集（owner/editor；
  /// 只允许可重试失败，§4）。返回是否已受理。
  Future<bool> retryTranscribe(EntityId id);
}

/// 默认实现：T08 API 客户端薄封装（端点未实现 → 失败如实抛错）。
class ApiTalkRecordDetailService implements TalkRecordDetailService {
  ApiTalkRecordDetailService([TalkRecordApi? api])
    : _api = api ?? TalkRecordApi();

  final TalkRecordApi _api;

  @override
  Future<TalkRecordFetched<TalkRecordModel>> record(EntityId id) {
    return _api.detail(id);
  }

  @override
  Future<TalkRecordFetched<TalkRecordModel>> patchNotes(
    EntityId id,
    String notes, {
    required String ifMatch,
  }) {
    return _api.patchRecord(id, notes: notes, ifMatch: ifMatch);
  }

  @override
  Future<TalkRecordCursorPage<TalkRecordSegmentModel>> segments(
    EntityId id, {
    EntityId? speakerId,
    String? q,
    String cursor = '',
    int? limit,
  }) {
    return _api.segments(
      id,
      speakerId: speakerId,
      q: q,
      cursor: cursor,
      limit: limit,
    );
  }

  @override
  Future<TalkRecordFetched<TalkRecordSegmentModel>> patchSegment(
    EntityId id,
    EntityId segmentId, {
    String? text,
    EntityId? speakerId,
    required String ifMatch,
  }) {
    return _api.patchSegment(
      id,
      segmentId,
      text: text,
      speakerId: speakerId,
      ifMatch: ifMatch,
    );
  }

  @override
  Future<List<TalkRecordSpeakerModel>> speakers(EntityId id) {
    return _api.speakers(id);
  }

  @override
  Future<TalkRecordSpeakerModel> patchSpeaker(
    EntityId id,
    EntityId speakerId, {
    String? displayName,
    EntityId? matchedUserId,
    required String ifMatch,
  }) {
    return _api.patchSpeaker(
      id,
      speakerId,
      displayName: displayName,
      matchedUserId: matchedUserId,
      ifMatch: ifMatch,
    );
  }

  @override
  Future<TalkRecordSpeakerModel> claimSpeaker(EntityId id, EntityId speakerId) {
    return _api.claimSpeaker(id, speakerId);
  }

  @override
  Future<TalkRecordFetched<TalkRecordSummaryModel>> summary(EntityId id) {
    return _api.summary(id);
  }

  @override
  Future<TalkRecordCursorPage<TalkRecordMarkModel>> marks(
    EntityId id, {
    String cursor = '',
    int? limit,
  }) {
    return _api.marks(id, cursor: cursor, limit: limit);
  }

  @override
  Future<bool> retryTranscribe(EntityId id) async {
    // 真实链路需先 GET /:id/jobs 找可重试的 transcribe job（§4），
    // 端点未实现前不伪造 job id——如实抛未支持错误，页面按失败态展示。
    throw const TalkRecordApiException(
      501,
      'talk_record jobs retry pending integration',
    );
  }
}

/// 当前主体角色推导（**仅用于展示徽章与操作可见性**，UI-SPEC §3；
/// 服务端 ACL 才是鉴权真源，客户端推导不构成任何授权）。
///
/// 依据 capabilities_for_actor：能管理分享/删除/移交 → owner；
/// 仅能编辑 → editor；否则 viewer（导出能力不改变角色显示）。
enum TalkRecordActorRole { owner, editor, viewer }

TalkRecordActorRole talkRecordActorRoleOf(TalkRecordCapabilitiesForActor caps) {
  if (caps.share || caps.delete || caps.transferOwner) {
    return TalkRecordActorRole.owner;
  }
  if (caps.edit) return TalkRecordActorRole.editor;
  return TalkRecordActorRole.viewer;
}
