/// 客服工作台入口可见性判定（§12.5.1 / CSM-01）
///
/// 纯函数、零 Flutter / 零 IO 依赖，可单测四态：
///
/// 1. 合格坐席（active member + active customer_service assignment +
///    enabled seat）→ 可见；
/// 2. 普通用户（无 customer_service 职能 assignment）→ 不可见；
/// 3. disabled seat（坐席席位被 suspend/停用）→ 不可见；
/// 4. 错 function（active assignment 但职能不是 customer_service）→ 不可见。
///
/// 安全口径：客户端隐藏只是 UX；服务端对 cs_seat 面 fail-closed
/// （cs_actions:seat_auth 的 required_function 校验），本判定只决定入口
/// 是否渲染，绝不放大服务端授权。
library;

/// customer_service 职能 wire 值（服务端权威，见 cs_actions:seat_auth）。
const String kCsFunctionKey = 'customer_service';

/// 入口判定输入（全部为会话内已有用户域数据的原始 wire 值）。
class CsSeatGateInput {
  /// 组织成员状态 wire 值（active|suspended|removed；空视为非 active）。
  final String memberStatus;

  /// 业务身份职能（function_key；空 = 无 assignment）。
  final String functionKey;

  /// 业务身份状态（assignment 状态；非 active 视为停用）。
  final String identityStatus;

  /// 坐席席位是否启用（seat enabled；服务端未回显时客户端按 unknown 保守
  /// 处理——由调用方决定缺省值，本类型不做默认放行）。
  final bool seatEnabled;

  const CsSeatGateInput({
    required this.memberStatus,
    required this.functionKey,
    required this.identityStatus,
    required this.seatEnabled,
  });
}

/// 入口可见性：四条同时成立才可见（fail-closed 与集）。
///
/// - active Organization member；
/// - active customer_service assignment（职能精确匹配，不含前缀/别名）；
/// - enabled seat；
/// - 输入任何一项未知/为空 → 不可见。
bool csWorkspaceEntryVisible(CsSeatGateInput input) {
  if (input.memberStatus != 'active') return false;
  if (input.functionKey != kCsFunctionKey) return false;
  if (input.identityStatus != 'active') return false;
  if (!input.seatEnabled) return false;
  return true;
}

/// 由 seat-contexts（BE-S01a 权威聚合）判定入口/工作台可见性（纯函数）。
///
/// `GET /api/v1/cs/me/seat-contexts` 的每行已由服务端按 active member +
/// active workspace 聚合；行内 `businessIdentityId` 非空 = active
/// customer_service assignment、`seatEnabled` = enabled seat。**任一**行
/// 同时成立即可见（多 Org 用户任一可用席位即入口成立）。
///
/// 返回 false 的情形（全部 fail-closed）：空列表（无 active member Org）、
/// 全部 seat disabled、全部缺 assignment、解析缺字段。
bool csEntryVisibleFromContexts(Iterable<CsSeatContextLike> contexts) {
  for (final c in contexts) {
    if (c.isEligible) return true;
  }
  return false;
}

/// [csEntryVisibleFromContexts] 的最小结构接口（避免 domain 反向依赖
/// infrastructure 的完整 DTO；CsSeatContext 满足此形状）。
abstract interface class CsSeatContextLike {
  bool get isEligible;
}

/// 客户名掩码（待接列表展示）：保留首字符，其余以 `**` 掩码；
/// 空名回落 `**`；单字符名掩码为 `*`（不泄露长度为零/一以外的信息）。
String csMaskContactName(String rawName) {
  final name = rawName.trim();
  if (name.isEmpty) return '**';
  if (name.length == 1) return '$name*';
  return '${name[0]}**';
}
