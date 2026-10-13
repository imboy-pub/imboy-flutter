import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// 坐席会话详情（CSB-03：GET /api/v1/cs/sessions/:id 回显投影，宽容解析）。
enum CsEvaluationState { unknown, unrated, rated }

class CsSessionDetail {
  final String sessionId;
  final String organizationId;

  /// 会话绑定的企业会话（消息通道的必要输入；服务端缺省为空——缺失时
  /// 消息通道显示可解释不可用态，禁止任何个人 IM fallback）。
  final String conversationId;
  final String status;
  final int version;

  /// 兼容旧调用方的评分数值；真实是否已评须读取 evaluationState。
  final int rating;
  final CsEvaluationState evaluationState;
  final DateTime? ratingAt;
  final String contactId;
  final String assigneeIdentityId;

  const CsSessionDetail({
    required this.sessionId,
    this.organizationId = '',
    this.conversationId = '',
    this.status = '',
    this.version = 0,
    this.rating = 0,
    this.evaluationState = CsEvaluationState.unknown,
    this.ratingAt,
    this.contactId = '',
    this.assigneeIdentityId = '',
  });

  bool get isClosed => status == 'closed';

  bool get hasRating => rating > 0;

  factory CsSessionDetail.fromJson(dynamic payload) {
    final map = payload is Map ? payload : const <String, dynamic>{};
    final evaluation = _ratingFacts(map);
    return CsSessionDetail(
      evaluationState: evaluation.$1,
      ratingAt: evaluation.$2,
      sessionId: entityIdOf(map['session_id'] ?? map['id']),
      organizationId: entityIdOf(map['organization_id']),
      conversationId: entityIdOf(map['conversation_id']),
      status: parseModelString(map['status']),
      version: parseModelInt(map['version']),
      rating: parseModelInt(map['rating']),
      contactId: entityIdOf(map['contact_id']),
      assigneeIdentityId: entityIdOf(map['business_identity_id']),
    );
  }
}

(CsEvaluationState, DateTime?) _ratingFacts(Map<dynamic, dynamic> map) {
  if (map.containsKey('rating') &&
      map.containsKey('rating_at') &&
      map['rating'] == null &&
      map['rating_at'] == null) {
    return (CsEvaluationState.unrated, null);
  }
  final rating = map['rating'], at = map['rating_at'];
  if (rating is int &&
      rating >= 1 &&
      rating <= 5 &&
      at is int &&
      at > 0 &&
      at <= 8640000000000) {
    return (
      CsEvaluationState.rated,
      DateTime.fromMillisecondsSinceEpoch(at * 1000, isUtc: true),
    );
  }
  return (CsEvaluationState.unknown, null);
}
