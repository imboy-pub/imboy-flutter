/// W07.c（channel-group-ux-v2.2 §6.5 C2）：清单 cursor 协议客户端。
///
/// App 侧对四类清单（个人群三 attr / 已订阅频道 / 我管理频道 / 工作区
/// 目录）的签名游标协议消费层。协议**显式 opt-in**：仅当请求带
/// `pagination=cursor` 时服务端才返回新 envelope
/// `{list, has_more, next_cursor}`；不带该参数 → 旧 envelope 逐字不变
/// （J27.a：旧客户端/旧 Admin 零变化）。
///
/// 能力门（J27.b）：manifest `list_contracts.create_request_id == 1`
/// （与创建合同同一恰为整数 1 的精度）才允许发 pagination=cursor；未
/// 声明 → 消费方走既有 legacy 路径（行为零变化），绝不激进启用。
///
/// 错误语义（J27.c）：绑定不符/篡改/过期 → 服务端 400 invalid_request，
/// 客户端映射为 CursorRejected——**不回落第 1 页**（不剥键、不猜
/// offset），由调用方决定同范围重扫或如实报错。
library;

/// 各清单家族的 list_kind 标识（与服务端 list_cursor 域一致）。
class ListCursorKind {
  const ListCursorKind._();

  static const String groupOwned = 'group_owned';
  static const String groupJoined = 'group_joined';
  static const String groupManaged = 'group_managed';
  static const String channelSubscribed = 'channel_subscribed';
  static const String channelManaged = 'channel_managed';
  static const String wsGroupDirectory = 'ws_group_directory';
  static const String wsGroupMember = 'ws_group_member';
  static const String wsChannelDirectory = 'ws_channel_directory';
}

/// manifest `list_contracts` 能力门（J27.b 精度）：恰为整数 1 才启用。
bool listCursorContractEnabled(Map<String, dynamic>? listContracts) =>
    listContracts != null &&
    listContracts['create_request_id'] is int &&
    listContracts['create_request_id'] == 1;

/// 构造 pagination=cursor 请求的 query 参数（协议 opt-in 形态）。
Map<String, String> cursorQuery({String? token, int limit = 50, String? q}) {
  final params = <String, String>{'pagination': 'cursor', 'limit': '$limit'};
  if (token != null && token.isNotEmpty) params['cursor'] = token;
  if (q != null && q.isNotEmpty) params['q'] = q;
  return params;
}

/// 解析 cursor 协议 envelope（服务端 success payload）。
/// 终止页 next_cursor 缺席/空 → null；非终止页 token 必须前进。
class CursorPage<T> {
  const CursorPage({
    required this.list,
    required this.hasMore,
    this.nextCursor,
  });

  final List<T> list;
  final bool hasMore;

  /// 终止页为 null（has_more=false 时服务端回空串/缺省）。
  final String? nextCursor;
}
