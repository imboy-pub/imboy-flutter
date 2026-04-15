/// F5-A @所有人纯函数（零外部依赖）。
///
/// 契约对齐后端：
///   - `imboy/src/logic/mention_logic.erl` create_mentions/4：
///     @所有人（mentions 含 `<<"all">>`）需 admin 权限，否则返回
///     `{error, permission_denied}`。
///   - `imboy/src/ds/group_member_ds.erl:249-253` check_admin/2：
///     `Role >= 3` 视为管理员 → admin(3) / owner(4) / vice_owner(5)
///     均可通过；member(1) / guest(2) 不通过。
///   - `imboy/src/ds/mention_ds.erl:38-43` save_mentions/4：
///     识别字面量 `<<"all">>` 作为 @所有人标记；否则按 uid 数字列表处理。
///
/// 本文件故意零外部依赖，便于 Model-only 单测绕开 http_client / sqflite 链。
library;

const Set<int> _kAdminRoles = {3, 4, 5};

/// 判断指定角色是否允许 @所有人（白名单策略）。
///
/// 对齐后端 `check_admin/2` 的 `Role >= 3` 语义；但客户端**明确枚举**
/// {3, 4, 5}，未定义的 role（负数 / 0 / 6+）一律拒绝，防止后端未来引入
/// 新 role 数值时客户端默认放行。
bool canMentionAll(int role) => _kAdminRoles.contains(role);

/// 编码 mentions payload（发送给后端的列表形式）。
///
/// - `isAllSelected=true` → 返回 `['all']`（后端字面量识别标记），忽略 uids；
/// - `isAllSelected=false` → 对 uids 做**去重 + 保序 + 过滤空/全空白**处理。
///
/// 返回值为**独立 List 副本**（非 const），调用方可安全复制；但内部不暴露
/// 可变引用。
List<String> buildMentionsPayload({
  required List<String> uids,
  required bool isAllSelected,
}) {
  if (isAllSelected) {
    return <String>['all'];
  }
  final seen = <String>{};
  final result = <String>[];
  for (final raw in uids) {
    final uid = raw.trim();
    if (uid.isEmpty) continue;
    if (seen.add(uid)) {
      result.add(uid);
    }
  }
  return result;
}

/// 将 UI 层上抛的混合 mentionIds 拆分为 (uids, isAllSelected)。
///
/// 契约：`lib/page/chat/widget/chat_input.dart:425` 对 @所有人使用字面量
/// `'all'` 注入 mentionIds（对齐后端 `imboy/src/ds/mention_ds.erl:38-43`）。
/// 此函数提取 `'all'` 信号转换为 `isAllSelected=true`，其余作为普通 uid 保留。
///
/// - 精确匹配 `'all'`（小写），避免误伤大小写变体 `'All'/'ALL'` 或包含子串
///   `'ball'` 的 uid（TSID 数字字符串不会碰撞，此为防御）。
/// - `'all'` 多次出现幂等；混合场景 `isAllSelected=true` 时普通 uid 仍保留
///   （由后续 `resolveMentionsForSend` 按优先级处理：isAllSelected 压过 uids）。
({List<String> uids, bool isAllSelected}) splitMentionIds(List<String> raw) {
  var isAll = false;
  final uids = <String>[];
  for (final id in raw) {
    if (id == 'all') {
      isAll = true;
    } else {
      uids.add(id);
    }
  }
  return (uids: uids, isAllSelected: isAll);
}

/// 发送侧 mention 决策结果（sealed）。
///
/// 调用方典型接线（对齐 `chat_page.dart:1271-1275`）：
/// ```dart
/// switch (resolveMentionsForSend(...)) {
///   case MentionResolveOk(:final mentions):
///     metadata['mentions'] = mentions;
///   case MentionResolveEmpty():
///     // 不附 mentions 字段
///   case MentionResolveDeniedAll():
///     // Toast 提示 + 阻塞发送
/// }
/// ```
sealed class MentionResolveResult {
  const MentionResolveResult();
}

/// 正常结果：mentions 字段应按返回列表附加。
final class MentionResolveOk extends MentionResolveResult {
  const MentionResolveOk(this.mentions);
  final List<String> mentions;
}

/// 空结果：无需附加 mentions 字段（非群聊 / 无 @ / 全被过滤）。
final class MentionResolveEmpty extends MentionResolveResult {
  const MentionResolveEmpty();
}

/// 权限拒绝：用户尝试 @所有人但无 admin 权限，调用方应阻塞发送并提示。
final class MentionResolveDeniedAll extends MentionResolveResult {
  const MentionResolveDeniedAll();
}

/// 发送侧决策内核：根据会话类型 / 角色 / 选择，判断 mentions 字段应如何处理。
///
/// 优先级（从高到低）：
///   1. 非群聊 → `MentionResolveEmpty`（@ 仅对群聊有语义）
///   2. `isAllSelected=true` 压过 uids：
///      - admin/owner/vice_owner → `MentionResolveOk(["all"])`
///      - member/guest → `MentionResolveDeniedAll`（**不降级** —— 用户意图是
///        @所有人，不能偷偷替换为 @ 子集，语义失真）
///   3. 普通 @：去重过滤后非空 → `MentionResolveOk(uids)`；空 → `Empty`
MentionResolveResult resolveMentionsForSend({
  required bool isGroupChat,
  required int role,
  required List<String> uids,
  required bool isAllSelected,
}) {
  if (!isGroupChat) return const MentionResolveEmpty();
  if (isAllSelected) {
    if (canMentionAll(role)) {
      return const MentionResolveOk(['all']);
    }
    return const MentionResolveDeniedAll();
  }
  final payload = buildMentionsPayload(uids: uids, isAllSelected: false);
  if (payload.isEmpty) return const MentionResolveEmpty();
  return MentionResolveOk(payload);
}
