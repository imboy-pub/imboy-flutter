import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';

/// Agent 任务审批 API 客户端（Phase 4 T4.2）
///
/// 群内可点击审批卡片的后端调用。仅传 task_id；ApproverUid 由后端从 JWT
/// current_uid 派生（前端不传、不可伪造）。授权/去重仲裁在后端 agent_task_observer。
class AgentTaskApi extends HttpClient {
  /// 批准任务
  Future<bool> approve(String taskId) => _decide(API.agentTaskApprove, taskId);

  /// 拒绝任务
  Future<bool> reject(String taskId) => _decide(API.agentTaskReject, taskId);

  Future<bool> _decide(String path, String taskId) async {
    if (taskId.trim().isEmpty) return false;
    final resp = await post(path, data: {'task_id': taskId});
    return resp.ok;
  }
}
