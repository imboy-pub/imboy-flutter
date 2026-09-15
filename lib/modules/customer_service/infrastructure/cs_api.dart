/// 客服（坐席侧）API 客户端（amendment §2.4 / plan §5.2 客服 API）
///
/// 契约：plan §5.2 保留 V3 的 session/claim/transfer/close/rating 能力，
/// 但 V3 具体路径不在冻结件中（契约疑问已在 A4 报告登记）。本客户端按
/// 最小形状实现：`/api/v1/cs/sessions/...`，路径参数为 session id，动作
/// 全部为 POST（claim/transfer/close/rating）。
///
/// 错误映射：401 未授权 / 403 被拒绝（含被 suspend 后的 claim 等写操作）
/// / 409 offboarding_required；镜像 [EnterpriseApiException] 判定属性。
library;

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// 客服 API 失败。
class CsApiException implements Exception {
  final int code;
  final String message;

  const CsApiException(this.code, this.message);

  bool get isUnauthorized => code == 401;

  /// 403：无权限 / 坐席被 suspend（降级只读）。
  bool get isForbidden => code == 403;

  bool get isOffboardingRequired => code == 409;

  @override
  String toString() => 'CsApiException($code): $message';
}

/// 客服排队会话条目。
class CsQueueItem {
  final String sessionId;
  final String contactId;
  final String contactName;
  final String waitingSince;

  const CsQueueItem({
    required this.sessionId,
    required this.contactId,
    this.contactName = '',
    this.waitingSince = '',
  });

  factory CsQueueItem.fromJson(Map<String, dynamic> json) {
    return CsQueueItem(
      sessionId: entityIdOf(json['session_id']),
      contactId: entityIdOf(json['contact_id']),
      contactName: parseModelString(json['contact_name']),
      waitingSince: parseModelString(json['waiting_since']),
    );
  }
}

/// 客服（坐席侧）API 客户端。
class CsApi extends HttpClient {
  /// 排队会话列表。
  Future<List<CsQueueItem>> queue() async {
    final resp = await get('/api/v1/cs/sessions/queue');
    _ensureOk(resp);
    return IMBoyHttpResponse.payloadList(resp.payload)
        .map(CsQueueItem.fromJson)
        .toList(growable: false);
  }

  /// claim：坐席接单。
  Future<void> claim(String sessionId) async {
    final resp = await post('/api/v1/cs/sessions/$sessionId/claim');
    _ensureOk(resp);
  }

  /// transfer：转接给目标业务身份。
  Future<void> transfer(
    String sessionId, {
    required String toIdentityId,
  }) async {
    final resp = await post(
      '/api/v1/cs/sessions/$sessionId/transfer',
      data: {'to_identity_id': toIdentityId},
    );
    _ensureOk(resp);
  }

  /// close：结束会话。
  Future<void> close(String sessionId) async {
    final resp = await post('/api/v1/cs/sessions/$sessionId/close');
    _ensureOk(resp);
  }

  /// rating：会话评分（1..5）。
  Future<void> rate(String sessionId, {required int score}) async {
    final resp = await post(
      '/api/v1/cs/sessions/$sessionId/rating',
      data: {'score': score},
    );
    _ensureOk(resp);
  }

  void _ensureOk(IMBoyHttpResponse resp) {
    if (!resp.ok) {
      throw CsApiException(resp.code, resp.msg);
    }
  }
}
