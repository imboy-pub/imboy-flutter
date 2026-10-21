/// 面聊记录（talk_record）分享域服务抽象（T18）。
///
/// 页面不直接持有 [TalkRecordApi]：授权名单/候选/卡片/策略全部经此抽象
/// 网关注入（对齐 T10/T16 服务纪律）：
/// 1. widget 测试零网络（fixture 注入，见 talk_record_share_fixture_service.dart）；
/// 2. T17 联调时替换为带缓存/重试的实现而无需改页面；
/// 3. 失败如实抛 [TalkRecordApiException]（403/404/412 语义驱动门控与
///    冲突 UI），不吞错。
///
/// 契约源：BACKEND-API.md §4（GET /:id、GET/PUT /:id/grants、
/// DELETE /:id/grants/:grant_id、POST /:id/share-card）+ §8
/// （GET /:id/share-candidates）+ §9（分享页导出开关策略禁用态）+
/// §11.3（完整名单仅 owner；其他人只看自己的权限）。
/// 端点均未实现——默认实现是真实 API 薄封装（失败如实展示），
/// fixture 实现仅用于组件行为验证，不冒充真实授权/撤销生效。
library;

import 'package:imboy/modules/talk_record/talk_record_error.dart'
    show TalkRecordApiException;
import 'package:imboy/store/api/talk_record_api.dart'
    show TalkRecordApi, TalkRecordFetched, TalkRecordShareCardData;
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart'
    show TalkRecordShareCandidateModel;
import 'package:imboy/store/model/talk_record/talk_record_cursor_page.dart';
import 'package:imboy/store/model/talk_record/talk_record_grant_model.dart'
    show TalkRecordGrantInput, TalkRecordGrantModel;
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;

/// 分享域数据服务抽象（T18 UI 消费面）。
abstract class TalkRecordShareService {
  /// GET /:id（门控判断：capabilities_for_actor.share 驱动管理/只读视图；
  /// 无权限或不存在统一 404，§11.3）。
  Future<TalkRecordFetched<TalkRecordModel>> record(EntityId id);

  /// GET /:id/grants（owner 查全量；其他人只看自己的权限，§4；
  /// ETag 对应 acl_revision）。
  Future<TalkRecordFetched<List<TalkRecordGrantModel>>> grants(EntityId id);

  /// PUT /:id/grants（owner 提交全量受权清单；If-Match；不得授权超归属
  /// 范围人员——服务端裁决，客户端不预判）。返回保存后的全量名单与新
  /// acl ETag。
  Future<TalkRecordFetched<List<TalkRecordGrantModel>>> putGrants(
    EntityId id, {
    required List<TalkRecordGrantInput> grants,
    required String ifMatch,
  });

  /// DELETE /:id/grants/:grant_id（owner 撤销；If-Match；立即失效，§4）。
  /// 返回撤销后的全量名单与新 acl ETag（列表即时更新）。
  Future<TalkRecordFetched<List<TalkRecordGrantModel>>> revokeGrant(
    EntityId id,
    EntityId grantId, {
    required String ifMatch,
  });

  /// GET /:id/share-candidates（§8：服务端从记录取归属；仅返回主体有权
  /// 可见目录；候选结果不是永久授权凭证）。
  Future<TalkRecordCursorPage<TalkRecordShareCandidateModel>> shareCandidates(
    EntityId id, {
    String? q,
    String cursor = '',
    int? limit,
  });

  /// POST /:id/share-card（§4：只生成受控定位数据、不额外授权、不发
  /// 消息；预览标题最小化，严格模式只发「面聊记录」定位）。
  Future<TalkRecordShareCardData> shareCard(EntityId id);

  /// 当前记录归属下的导出授权策略（§9：分享页导出开关在策略禁止时
  /// disabled 并展示原因；owner 不能绕过企业策略）。
  Future<TalkRecordSharePolicy> sharePolicy(EntityId id);
}

/// 导出授权被策略阻止的原因（i18n 键由 UI 层映射；不编造策略细节）。
enum TalkRecordExportBlockReason {
  /// 未阻止：可授予导出。
  none,

  /// 企业/工作区策略禁止导出。
  organizationPolicy,

  /// 实例未开启导出能力。
  instancePolicy,

  /// 策略获取失败（保守禁用，不假装允许；§4 能力关闭不能仅 UI 禁用）。
  unknown,
}

/// 分享页导出策略投影（§9）。
class TalkRecordSharePolicy {
  /// 是否允许在授权中开启「允许导出」。
  final bool exportGrantAllowed;

  /// 被阻止时的原因（exportGrantAllowed=true 时忽略）。
  final TalkRecordExportBlockReason exportBlockReason;

  const TalkRecordSharePolicy({
    this.exportGrantAllowed = false,
    this.exportBlockReason = TalkRecordExportBlockReason.unknown,
  });

  const TalkRecordSharePolicy.allowed()
    : this(
        exportGrantAllowed: true,
        exportBlockReason: TalkRecordExportBlockReason.none,
      );

  const TalkRecordSharePolicy.blocked(TalkRecordExportBlockReason reason)
    : this(exportGrantAllowed: false, exportBlockReason: reason);
}

/// 卡片发送通道抽象（组件阶段）。
///
/// 契约源：BACKEND-API.md §4 share-card「发送行为由用户在 IM 确认」+
/// 本卡约束「禁止给真实第三方发任何消息」：
/// - 默认实现 [UnavailableShareCardSender] 如实「未接入」，不伪造发送
///   成功（「已发送」仅真实成功后显示，UI-SPEC §4）；
/// - fixture 实现（talk_record_share_fixture_service.dart）模拟成功/失败
///   证明组件行为，卡片与结果均标注示例；
/// - T17 联调时替换为真实 IM 会话选择/系统分享面板实现。
enum TalkRecordCardSendResult {
  sent,
  cancelled,
  pending,
  failed,
  unavailable,
  stale,
}

abstract class TalkRecordShareCardSender {
  /// 发送通道是否可用（false 时 UI 如实提示待接入，不显示「已发送」）。
  bool get isAvailable;

  /// 发送卡片。返回是否真实成功；不可用实现恒 false。
  Future<TalkRecordCardSendResult> send(TalkRecordShareCardData card);
}

/// 默认实现：发送通道未接入（不产生任何对外消息副作用）。
class UnavailableShareCardSender implements TalkRecordShareCardSender {
  const UnavailableShareCardSender();

  @override
  bool get isAvailable => false;

  @override
  Future<TalkRecordCardSendResult> send(TalkRecordShareCardData card) async =>
      TalkRecordCardSendResult.unavailable;
}

/// 默认实现：T08 API 客户端薄封装（端点未实现 → 失败如实抛错）。
class ApiTalkRecordShareService implements TalkRecordShareService {
  ApiTalkRecordShareService([TalkRecordApi? api])
    : _api = api ?? TalkRecordApi();

  final TalkRecordApi _api;

  @override
  Future<TalkRecordFetched<TalkRecordModel>> record(EntityId id) {
    return _api.detail(id);
  }

  @override
  Future<TalkRecordFetched<List<TalkRecordGrantModel>>> grants(EntityId id) {
    return _api.grants(id);
  }

  @override
  Future<TalkRecordFetched<List<TalkRecordGrantModel>>> putGrants(
    EntityId id, {
    required List<TalkRecordGrantInput> grants,
    required String ifMatch,
  }) {
    return _api.putGrants(id, grants: grants, ifMatch: ifMatch);
  }

  @override
  Future<TalkRecordFetched<List<TalkRecordGrantModel>>> revokeGrant(
    EntityId id,
    EntityId grantId, {
    required String ifMatch,
  }) async {
    // T08 客户端 deleteGrant 无返回体（§4 端点语义：撤销立即生效）；
    // 分享页需要撤销后的名单做即时更新——重新 GET 全量。
    await _api.deleteGrant(id, grantId, ifMatch: ifMatch);
    return _api.grants(id);
  }

  @override
  Future<TalkRecordCursorPage<TalkRecordShareCandidateModel>> shareCandidates(
    EntityId id, {
    String? q,
    String cursor = '',
    int? limit,
  }) {
    return _api.shareCandidates(id, q: q, cursor: cursor, limit: limit);
  }

  @override
  Future<TalkRecordShareCardData> shareCard(EntityId id) {
    return _api.shareCard(id);
  }

  @override
  Future<TalkRecordSharePolicy> sharePolicy(EntityId id) async {
    // 真实策略端点未冻结（§9 企业详情 permissions / capabilities 组合），
    // T17 联调定稿；当前从 GET /capabilities 宽松解析，取不到 → 未知
    // 策略并保守禁用（组件行为：disabled + 原因展示）。
    try {
      final caps = await _api.capabilities();
      final raw = caps.raw;
      final allowed = raw['share_export_allowed'] is bool
          ? raw['share_export_allowed']! as bool
          : (raw['export'] is bool ? raw['export']! as bool : null);
      if (allowed == null) {
        return const TalkRecordSharePolicy.blocked(
          TalkRecordExportBlockReason.unknown,
        );
      }
      return allowed
          ? const TalkRecordSharePolicy.allowed()
          : const TalkRecordSharePolicy.blocked(
              TalkRecordExportBlockReason.instancePolicy,
            );
    } on TalkRecordApiException {
      return const TalkRecordSharePolicy.blocked(
        TalkRecordExportBlockReason.unknown,
      );
    }
  }
}
