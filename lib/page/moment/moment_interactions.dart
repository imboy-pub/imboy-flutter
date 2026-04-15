import 'package:imboy/store/model/model_parse_utils.dart';

/// 可见性 wire-protocol 常量（与后端契约）：
///   0 公开 / 1 仅好友 / 2 仅自己 / 3 部分可见 / 4 不给谁看
///
/// 这些 int 直接序列化进 POST /moments.create 的 `visibility` 字段；
/// 禁止随意重编号，新增可见性策略必须与后端协同。
const int momentVisibilityPublic = 0;
const int momentVisibilityFriends = 1;
const int momentVisibilityPrivate = 2;
const int momentVisibilityAllowList = 3;
const int momentVisibilityDenyList = 4;

/// 当前可见性是否需要用户填写「允许可见」白名单 UID 列表。
bool momentVisibilityRequiresAllowUids(int visibility) =>
    visibility == momentVisibilityAllowList;

/// 当前可见性是否需要用户填写「不给谁看」黑名单 UID 列表。
bool momentVisibilityRequiresDenyUids(int visibility) =>
    visibility == momentVisibilityDenyList;


/// 当前用户是否有权删除这条 moment。
///
/// 规则：`author_uid == currentUid`，且两者都非空白。
/// - 防御未登录（空 currentUid）/ 脏数据（空 author_uid）
/// - trim 后为空视为空，避免 "  " == "  " 的误判
bool canDeleteMoment(Map<String, dynamic> moment, String currentUid) {
  final currentTrim = currentUid.trim();
  if (currentTrim.isEmpty) return false;
  final author = parseModelString(moment['author_uid']).trim();
  if (author.isEmpty) return false;
  return author == currentTrim;
}

/// 当前用户是否有权删除这条评论。
///
/// 规则：评论作者本人 **或** 动态作者本人。
/// - 防御未登录（空 currentUid）返回 false，即使 uid 字段也恰好为空
/// - 评论 user_id 缺失时回退到「仅动态作者可删」
bool canDeleteComment(
  Map<String, dynamic> comment,
  Map<String, dynamic> moment, {
  required String currentUid,
}) {
  final currentTrim = currentUid.trim();
  if (currentTrim.isEmpty) return false;
  final commenterUid = parseModelString(comment['user_id']).trim();
  if (commenterUid.isNotEmpty && commenterUid == currentTrim) return true;
  return canDeleteMoment(moment, currentTrim);
}

/// 按优先级 `remark > nickname > uid > '?'` 解析显示名。
///
/// 与 ContactModel.title() 规则对齐：本地联系人备注胜过对方自取昵称，
/// 昵称胜过裸 uid，全部为空时回退到占位符 '?' 避免 substring(0,1) 炸。
/// 空白字符串视为空。
String resolveMomentDisplayName({
  required String remark,
  required String nickname,
  required String uid,
}) {
  if (remark.trim().isNotEmpty) return remark;
  if (nickname.trim().isNotEmpty) return nickname;
  if (uid.trim().isNotEmpty) return uid;
  return '?';
}

/// 将点赞/评论计数格式化为显示标签。
///
/// - 0 或负数返回空字符串（调用方决定是否完全不渲染图标右侧文本）
/// - 1..999 返回原始数字字符串
/// - 1000+ 返回 "999+"，防止 feed / detail 行布局被大数撑破
///
/// 与微信朋友圈的显示规则一致。
String formatMomentCountLabel(int count) {
  if (count <= 0) return '';
  if (count > 999) return '999+';
  return '$count';
}

/// 从列表中移除所有 `id == momentId` 的条目，返回一个新的 list。
///
/// - 原 list 不会被修改
/// - [momentId] 为空字符串时按 no-op 处理，返回一份浅拷贝
/// - 若没有匹配项，返回一份与原 list 顺序/内容等价的新 list
///
/// 用于 feed 页面乐观删除：先本地剔除卡片、再打网络，失败时整表回滚。
List<Map<String, dynamic>> removeMomentById(
  List<Map<String, dynamic>> items,
  String momentId,
) {
  if (momentId.isEmpty) {
    return List<Map<String, dynamic>>.from(items);
  }
  return items
      .where((item) => parseModelString(item['id']) != momentId)
      .toList(growable: false);
}

/// 返回一个新 moment map，`stats.comment_count` 按 [delta] 增减。
///
/// - 输入 map 和其子 `stats` map 都不会被修改
/// - 结果下限为 0，永不下溢
/// - 缺失 `stats` 视为空 map，从 0 起算
///
/// 用于本地 add/delete comment 后立即同步详情页头部的评论数字，避免
/// 等下一次网络刷新才看到正确的计数。
Map<String, dynamic> applyCommentCountDelta(
  Map<String, dynamic> moment,
  int delta,
) {
  final rawStats = moment['stats'];
  final oldStats = rawStats is Map
      ? Map<String, dynamic>.from(rawStats)
      : <String, dynamic>{};
  final current = parseModelInt(oldStats['comment_count']);
  final next = current + delta;
  final clamped = next < 0 ? 0 : next;
  final nextStats = Map<String, dynamic>.from(oldStats);
  nextStats['comment_count'] = clamped;
  final nextMoment = Map<String, dynamic>.from(moment);
  nextMoment['stats'] = nextStats;
  return nextMoment;
}

/// 将下一页评论合并到已有列表。
///
/// - 按 `id` 去重；首次出现的条目保留，后续重复被丢弃（保持现有顺序稳定）
/// - `next` 内部的重复也会去重
/// - `id` 缺失或空字符串的条目被过滤掉（防御后端脏数据）
/// - 入参两个 list 都不会被修改
///
/// 用于 detail 页面评论游标分页 + eventbus 触发的刷新场景，避免网络
/// 双拉或快速滚动触发的重复 append。
List<Map<String, dynamic>> appendCommentsPage(
  List<Map<String, dynamic>> existing,
  List<Map<String, dynamic>> next,
) {
  final seen = <String>{};
  final merged = <Map<String, dynamic>>[];
  for (final item in existing) {
    final id = parseModelString(item['id']);
    if (id.isEmpty || seen.contains(id)) continue;
    seen.add(id);
    merged.add(item);
  }
  for (final item in next) {
    final id = parseModelString(item['id']);
    if (id.isEmpty || seen.contains(id)) continue;
    seen.add(id);
    merged.add(item);
  }
  return merged;
}

/// 返回一个新 moment map，切换 `liked` 并相应增减 `stats.like_count`。
///
/// - 输入 map 和其子 `stats` map 都不会被修改（调用方可保留原对象用于回滚）。
/// - `like_count` 不会下溢到负数；取消点赞时下限为 0。
/// - 缺失字段按默认值处理：`liked` 缺失视为 false，`stats` 缺失视为空 map。
///
/// Feed / Detail 页面共用的乐观更新辅助。
Map<String, dynamic> applyOptimisticLikeToggle(Map<String, dynamic> moment) {
  final liked = parseModelBool(moment['liked']);
  final rawStats = moment['stats'];
  final oldStats = rawStats is Map
      ? Map<String, dynamic>.from(rawStats)
      : <String, dynamic>{};
  final likeCount = parseModelInt(oldStats['like_count']);
  final nextLikeCount = liked
      ? (likeCount > 0 ? likeCount - 1 : 0)
      : likeCount + 1;
  final nextStats = Map<String, dynamic>.from(oldStats);
  nextStats['like_count'] = nextLikeCount;
  final next = Map<String, dynamic>.from(moment);
  next['liked'] = !liked;
  next['stats'] = nextStats;
  return next;
}
