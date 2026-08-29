/// W2 (ZC-03/ZC-06) — Project Milestone API 客户端
///
/// 契约源：imboy `project_milestone_handler.erl`：
/// - create：name 必填；due_date 'YYYY-MM-DD' | null；status 字段被服务端
///   显式拒绝（400）——状态唯一入口是 /reach；
/// - update：name/due_date 可选（缺省保留；due_date 清空传 null）；
/// - reach：planned→reached 单向，重复 reach 幂等（already_reached）；
/// - list：`{list, page, size}`（无 total/total_page）。
library;

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/workspace_api.dart' show WorkspaceApiException;
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/project_w2_model.dart';
import 'package:imboy/store/model/workspace_model.dart'
    show EntityId, WorkspacePageResult;

/// 里程碑 API。
class MilestoneApi extends HttpClient {
  /// 里程碑列表（status: all|planned|reached；active 成员可读）。
  Future<WorkspacePageResult<MilestoneModel>> list(
    EntityId projectId, {
    String status = 'all',
    int page = 1,
    int size = 10,
  }) async {
    final resp = await get(
      '/api/v1/projects/$projectId/milestones',
      queryParameters: {'status': status, 'page': page, 'size': size},
    );
    return _unwrap(
      resp,
      (json) => WorkspacePageResult.fromJson(json, MilestoneModel.fromJson),
      fallback: const WorkspacePageResult<MilestoneModel>(),
    );
  }

  /// 创建里程碑（Owner/Project Member；Guest 403；归档 980）。
  ///
  /// [dueDate] 传 'YYYY-MM-DD'；不传则后端存 null（无截止日）。
  Future<MilestoneModel> create({
    required EntityId projectId,
    required String name,
    String? dueDate,
  }) async {
    final resp = await post(
      '/api/v1/projects/$projectId/milestones',
      data: {
        'name': name,
        'due_date': (dueDate != null && dueDate.isNotEmpty) ? dueDate : null,
      },
    );
    return _unwrap(resp, MilestoneModel.fromJson, fallback: _empty(projectId));
  }

  /// 更新名称/截止日（[dueDate] null=保留原值；[clearDueDate] true=清空）。
  Future<MilestoneModel> update(
    EntityId milestoneId, {
    String? name,
    String? dueDate,
    bool clearDueDate = false,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (clearDueDate) {
      data['due_date'] = null;
    } else if (dueDate != null && dueDate.isNotEmpty) {
      data['due_date'] = dueDate;
    }
    final resp = await post(
      '/api/v1/milestones/$milestoneId/update',
      data: data,
    );
    return _unwrap(resp, MilestoneModel.fromJson, fallback: _empty(''));
  }

  /// 达成里程碑（planned→reached 单向；重复 reach 幂等）。
  Future<MilestoneReachResult> reach(EntityId milestoneId) async {
    final resp = await post(
      '/api/v1/milestones/$milestoneId/reach',
      data: <String, dynamic>{},
    );
    final payload = _ensureOk(resp);
    return MilestoneReachResult(
      milestone: payload.isEmpty
          ? _empty('')
          : MilestoneModel.fromJson(payload),
      statusFlag: parseModelString(
        payload['status_flag'],
        defaultValue: 'reached',
      ),
    );
  }

  // ==================== 内部 ====================

  static MilestoneModel _empty(EntityId projectId) =>
      MilestoneModel(id: '', projectId: projectId, name: '');

  Map<String, dynamic> _ensureOk(IMBoyHttpResponse resp) {
    if (!resp.ok) {
      throw WorkspaceApiException(resp.code, resp.msg);
    }
    return IMBoyHttpResponse.payloadAsMap(resp.payload);
  }

  T _unwrap<T>(
    IMBoyHttpResponse resp,
    T Function(Map<String, dynamic>) fromJson, {
    required T fallback,
  }) {
    final payload = _ensureOk(resp);
    if (payload.isEmpty) return fallback;
    return fromJson(payload);
  }
}

/// reach 结果（单向状态机 + 幂等标记）。
class MilestoneReachResult {
  final MilestoneModel milestone;

  /// reached | already_reached（幂等命中）。
  final String statusFlag;

  const MilestoneReachResult({
    required this.milestone,
    this.statusFlag = 'reached',
  });

  bool get isAlreadyReached => statusFlag == 'already_reached';
}
