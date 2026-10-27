import 'package:imboy/component/ui/app_loading.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/error_code.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_exceptions.dart';
import 'package:imboy/service/creation_receipt/creation_receipt_contract.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/list_cursor_client.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;

class GroupApi extends HttpClient {
  Future<Map<String, dynamic>?> page({
    int page = 1,
    int size = 10,
    String attr = '', // owner | join | manager
  }) async {
    IMBoyHttpResponse resp = await get(
      API.groupPage,
      queryParameters: {'page': page, 'size': size, 'attr': attr},
    );

    if (!resp.ok) {
      return null;
    }
    return resp.payload is Map<String, dynamic>
        ? resp.payload as Map<String, dynamic>
        : null;
  }

  /// W07.c 收尾（C2 个人群 cursor 协议）：签名游标分页。
  ///
  /// [attr] 必须 ∈ {owner, join, manager}（服务端 attr_kind 白名单；
  /// 'all' 是客户端聚合视图，禁止进入游标协议）。[token] null/空 = 首页；
  /// 非空 = 上一页 next_cursor（签名游标，绑定 uid/list_kind/上界）。
  /// 绑定不符/篡改/过期 → 服务端 400 invalid_request，此处抛出
  /// （不回落第 1 页，J27.c），由调用方决定终止或报错。
  /// 返回原始行（与 legacy `payload['list']` 同形状，消费方落库路径零差异）。
  Future<CursorPage<Map<String, dynamic>>> pageCursor({
    required String attr,
    String? token,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{
      'pagination': 'cursor',
      'attr': attr,
      'limit': limit,
    };
    if (token != null && token.isNotEmpty) params['cursor'] = token;
    final resp = await get(API.groupPage, queryParameters: params);
    resp.throwIfFailed();
    if (resp.payload == null) {
      return const CursorPage(list: [], hasMore: false);
    }
    final rows = IMBoyHttpResponse.payloadList(resp.payload);
    final hasMore = resp.payload['has_more'] == true;
    final dynamic next = resp.payload['next_cursor'];
    final nextCursor = (next == null || next.toString().isEmpty)
        ? null
        : next.toString();
    return CursorPage(
      list: rows,
      hasMore: hasMore && nextCursor != null,
      nextCursor: nextCursor,
    );
  }

  Future<Map<String, dynamic>> detail({required String gid}) async {
    IMBoyHttpResponse resp = await get(
      API.groupDetail,
      queryParameters: {"gid": gid},
    );
    if (resp.ok == false) {
      AppLoading.showError(resp.msg);
    }
    if (!resp.ok) return <String, dynamic>{};
    final payload = IMBoyHttpResponse.payloadAsMap(resp.payload);
    // P0-B B4：群详情携带 e2ee_mode（后端 SELECT *），此处同步本地旗标——
    // 覆盖开关广播之后才入群、没收到 group_e2ee_mode S2C 的成员
    final e2eeMode =
        payload['e2ee_mode'] ??
        (payload['group'] is Map ? payload['group']['e2ee_mode'] : null);
    if (e2eeMode != null) {
      await GroupSessionService.to.setGroupE2EEMode(
        gid,
        int.tryParse(e2eeMode.toString()) ?? 0,
      );
    }
    return payload;
  }

  /// 获取群备注（仅自己可见）
  Future<String?> getRemark({required String gid}) async {
    IMBoyHttpResponse resp = await get(
      API.groupRemark,
      queryParameters: {'gid': gid},
    );
    if (!resp.ok) return null;
    return IMBoyHttpResponse.payloadStr(resp.payload, 'remark');
  }

  /// 更新群备注（仅自己可见）
  Future<bool> updateRemark({
    required String gid,
    required String remark,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.groupRemark,
      data: {'gid': gid, 'remark': remark},
    );
    if (!resp.ok) {
      AppLoading.showError(resp.msg);
    }
    return resp.ok;
  }

  /// 开启群级 E2EE（仅群主，后端契约 0→1 单向，P0-B B4）
  Future<bool> setE2eeMode({required String gid}) async {
    IMBoyHttpResponse resp = await post(
      API.groupSetE2eeMode,
      data: {'gid': gid, 'e2ee_mode': 1},
    );
    if (!resp.ok) {
      AppLoading.showError(resp.msg);
      return false;
    }
    // 本地旗标立即升位；其他成员经 group_e2ee_mode S2C 广播 / 群详情同步
    await GroupSessionService.to.setGroupE2EEMode(gid, 1);
    return true;
  }

  Future<Map<String, dynamic>?> dissolve({required String gid}) async {
    IMBoyHttpResponse resp = await post(API.groupDissolve, data: {"gid": gid});
    if (resp.ok == false) {
      AppLoading.showError(resp.msg);
    }
    return resp.ok
        ? (resp.payload is Map<String, dynamic>
              ? resp.payload as Map<String, dynamic>
              : null)
        : null;
  }

  /// 工作区域建群（GZAPP-05；`scope=workspace` + `workspace_id`）。
  ///
  /// 与 [groupAdd] 的差别只有 scope 分区：服务端按 scope 校验成员资格
  /// （非工作区成员 / 个人域 id 一律拒绝，客户端不预判）。
  /// 返回 `(gid, error)`：error 非空即失败，gid 仅成功时有值。
  Future<({String gid, String? error})> createWorkspaceGroup({
    required EntityId workspaceId,
    required List<String> memberUserIds,
  }) async {
    final resp = await post(
      '/api/v1/group/add',
      data: {
        'member_uids': memberUserIds,
        'scope': 'workspace',
        'workspace_id': workspaceId,
      },
    );
    if (!resp.ok) {
      return (gid: '', error: _errText(resp));
    }
    final payload = resp.payload is Map<String, dynamic>
        ? resp.payload as Map<String, dynamic>
        : <String, dynamic>{};
    final group = payload['group'];
    final gid = group is Map<String, dynamic>
        ? '${group['id'] ?? group['gid'] ?? ''}'
        : '';
    return (gid: gid, error: gid.isEmpty ? '建群应答缺少群 ID' : null);
  }

  /// 群名/title 编辑（建群后补名；`group/edit` 的 `title` 字段）。
  Future<String?> editTitle({
    required String gid,
    required String title,
  }) async {
    final resp = await post(
      '/api/v1/group/edit',
      data: {'gid': gid, 'title': title},
    );
    return resp.ok ? null : _errText(resp);
  }

  /// 解散群（群主 **或** 所属企业 owner/admin，GZAPP-03 双授权源）。
  /// 返回 null = 成功；非 null = 服务端文案（页面原样透出）。
  Future<String?> dissolveWithReason({required String gid}) async {
    final resp = await post('/api/v1/group/dissolve', data: {'gid': gid});
    return resp.ok ? null : _errText(resp);
  }

  String _errText(IMBoyHttpResponse resp) =>
      resp.msg.isEmpty ? '${resp.code}' : '${resp.msg} (${resp.code})';

  /// 面对面建群
  Future<Map<String, dynamic>> groupFace2face({
    required String code,
    required String longitude,
    required String latitude,
  }) async {
    IMBoyHttpResponse resp = await get(
      API.groupFace2face,
      queryParameters: {
        "code": code,
        "longitude": longitude, // 经度
        "latitude": latitude, // 维度
      },
    );
    if (resp.ok == false) {
      AppLoading.showError(resp.msg);
    }
    return resp.ok
        ? IMBoyHttpResponse.payloadAsMap(resp.payload)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> groupFace2faceSave({
    required String code,
    required String gid,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.groupFace2faceSave,
      data: {"code": code, "gid": gid},
    );
    if (resp.ok == false) {
      AppLoading.showError(resp.msg);
    }
    return resp.ok
        ? IMBoyHttpResponse.payloadAsMap(resp.payload)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>?> groupAdd({
    required List<String> memberUserIds,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.groupAdd,
      data: {"member_uids": memberUserIds},
    );
    return resp.ok
        ? (resp.payload is Map<String, dynamic>
              ? resp.payload as Map<String, dynamic>
              : null)
        : null;
  }

  /// W04.d.g（channel-group-ux-v2.2 §6.4 C1）：带受理合同的群创建。
  ///
  /// 只做传输与响应形状解析；能力门/意图持久化/派发策略由
  /// GroupCreationReceiptService 编排。`recoverOnly=true` 时服务端绝不
  /// 创建，仅查受理（>=24h 或时钟不可信）。传输与鉴权重试（HttpRetry
  /// 链）自动携带同一请求体——同键与 recover_only 不会被中间件剥离。
  Future<CreationReceiptResult> createGroupWithReceipt({
    required String requestId,
    required List<String> memberUserIds,
    String? title,
    EntityId? workspaceId,
    bool recoverOnly = false,
  }) async {
    final data = <String, dynamic>{
      'member_uids': memberUserIds,
      'request_id': requestId,
      if (recoverOnly) 'recover_only': true,
      if (title != null && title.isNotEmpty) 'title': title,
      if (workspaceId != null) ...{
        'scope': 'workspace',
        'workspace_id': workspaceId,
      },
    };
    final resp = await post(API.groupAdd, data: data);
    // 传输层失败（网络断连/超时/会话切换等）：结果未知——服务端可能已受理
    // 也可能未收到；调用方必须保留意图，不得当作"信封已确认拒绝"。
    // 仅 BadRequestException（envelope 业务错误）与 BadResponseException
    // （响应形状损坏）代表已完成 HTTP 交换。
    if (!resp.ok &&
        resp.error is! BadRequestException &&
        resp.error is! BadResponseException) {
      return CreationReceiptResult(ok: false, errorText: resp.msg);
    }
    return parseCreationReceiptResponse(
      ok: resp.ok,
      code: resp.code,
      msg: resp.msg,
      payload: resp.payload,
      extractResourceId: (payload) {
        final gid = payload['gid'];
        return gid == null ? null : '$gid';
      },
    );
  }

  Future<bool> groupEdit({
    required String gid,
    required Map<String, dynamic> data,
  }) async {
    data['gid'] = gid;
    IMBoyHttpResponse resp = await post(API.groupEdit, data: data);
    if (resp.code == ErrorCode.ERROR) {
      AppLoading.showError(resp.msg);
    }
    return resp.ok ? true : false;
  }

  Future<int> addTag({required String scene, required String tagName}) async {
    IMBoyHttpResponse resp = await post(
      API.userTagAdd,
      data: {"scene": scene, "tag": tagName},
    );
    if (resp.code == ErrorCode.ERROR) {
      AppLoading.showError(resp.msg);
    }
    return resp.ok ? ((resp.payload['tagId'] as num?)?.toInt() ?? 0) : 0;
  }

  Future<Map<String, dynamic>?> pageRelation({
    int page = 1,
    int size = 10,
    required int tagId,
    String scene = '',
    String? kwd,
  }) async {
    String api = API.userTagRelationFriendPage;
    if (scene == 'collect') {
      api = API.userTagRelationCollectPage;
    } else if (scene == 'friend') {
      api = API.userTagRelationFriendPage;
    }
    IMBoyHttpResponse resp = await get(
      api,
      queryParameters: {
        'page': page,
        'size': size,
        'scene': scene,
        'tag_id': tagId,
        'kwd': kwd,
      },
    );

    if (!resp.ok) {
      return null;
    }
    return resp.payload is Map<String, dynamic>
        ? resp.payload as Map<String, dynamic>
        : null;
  }

  Future<bool> removeRelation({
    required int tagId,
    required String objectId,
    required String scene,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.userTagRelationRemove,
      data: {"scene": scene, "tagId": tagId, "objectId": objectId},
    );
    return resp.ok ? true : false;
  }

  Future<bool> setRelation({
    required int tagId,
    required String tagName,
    required List<String> objectIds,
    required String scene,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.userTagRelationSet,
      data: {
        "scene": scene,
        "tagId": tagId,
        "tagName": tagName,
        "objectIds": objectIds,
      },
    );
    return resp.ok ? true : false;
  }

  /// 转让群主
  /// [gid] 群组ID
  /// [newOwnerUid] 新群主用户ID
  Future<bool> transfer({
    required String gid,
    required String newOwnerUid,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.groupTransfer,
      data: {'gid': gid, 'new_owner_uid': newOwnerUid},
    );

    return resp.ok;
  }
}
