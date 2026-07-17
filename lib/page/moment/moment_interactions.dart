import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/i18n/strings.g.dart';
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

/// 当前可见性是否需要跳转好友名单页做多选（部分可见 / 不给谁看）。
///
/// 公开 / 仅好友 / 仅自己 三种无名单态：发布页原地 ActionSheet 选中即定，
/// 不跳页、不拉好友(SQLite)、不拉标签(网络)。仅名单两态才需要好友多选。
bool momentVisibilityNeedsFriendList(int visibility) =>
    momentVisibilityRequiresAllowUids(visibility) ||
    momentVisibilityRequiresDenyUids(visibility);

/// 从 moment payload 读取 `visibility` 并做类型/范围守卫。
///
/// - 数值或字符串数字都能解析（后端/缓存/旧版本载荷可能混用）
/// - 缺失 / null / 未知 code / 负数 → 回退到 [momentVisibilityFriends]
///
/// 选「仅好友」作为安全默认：脏数据绝不意外把私密帖升级为公开。
int parseMomentVisibility(Map<String, dynamic> moment) {
  // Sentinel -99 avoids collision with legit public=0; parseModelInt's
  // default 0 would otherwise make missing/null fields render as public.
  final code = parseModelInt(moment['visibility'], defaultValue: -99);
  switch (code) {
    case momentVisibilityPublic:
    case momentVisibilityFriends:
    case momentVisibilityPrivate:
    case momentVisibilityAllowList:
    case momentVisibilityDenyList:
      return code;
    default:
      return momentVisibilityFriends;
  }
}

/// 将 visibility wire 码映射到已有的 i18n 显示标签。
///
/// 未知 code 回退到「仅好友」标签，与 parseMomentVisibility 安全默认对齐。
String momentVisibilityLabel(int code, Translations t) {
  switch (code) {
    case momentVisibilityPublic:
      return t.discovery.momentsVisibilityPublic;
    case momentVisibilityFriends:
      return t.contact.momentsVisibilityFriends;
    case momentVisibilityPrivate:
      return t.chat.momentsVisibilityPrivate;
    case momentVisibilityAllowList:
      return t.discovery.momentsVisibilityPartial;
    case momentVisibilityDenyList:
      return t.discovery.momentsVisibilityExclude;
    default:
      return t.contact.momentsVisibilityFriends;
  }
}

/// 为 media item 选择用于预览/缩略图展示的 URL。
///
/// - `type == 'video'`：优先返回 `cover_url`（trim 后非空）；为空时回退到
///   `url`。这避免把 MP4 URL 直接塞给 `OctoImage` / image cache（图片解码
///   器吞下 MP4 → 静默黑框）。
/// - 其它类型（image / 未知 / 缺失）：直接返回 `url`。
/// - 全缺失时返回空字符串，调用方据此渲染占位图标。
String pickMediaPreviewUrl(Map<String, dynamic> media) {
  final type = parseModelString(media['type']);
  final url = parseModelString(media['url']);
  if (type == 'video') {
    final cover = parseModelString(media['cover_url']).trim();
    if (cover.isNotEmpty) return cover;
  }
  return url;
}

/// 取显示名首字符作为头像占位。
///
/// 比 `name.substring(0, 1)` 更安全：
/// - 先 trim，空 / 纯空白 → 返回 '?' 占位符（避免 RangeError）
/// - 按 Unicode 码点（rune）而非 UTF-16 code unit 截取，emoji 等
///   代理对字符不会被切半造成 `RangeError: Invalid UTF-16 code unit`
String avatarInitialFrom(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final firstRune = trimmed.runes.first;
  return String.fromCharCode(firstRune);
}

/// 已知的 MomentTimelineChangedEvent action 常量（仅用于 refresh 策略决策）。
/// 新增 action 请同步扩展 shouldRefreshDetailOnEvent / shouldRefreshFeedOnEvent。
const String momentActionNew = 'moment_new';
const String momentActionDeleted = 'moment_deleted';
const String momentActionUpdated = 'moment_updated';

/// 详情页是否应在收到该 timeline 事件时重新拉取。
///
/// 规则：
/// - `moment_deleted`：永远 false。若删的是当前页，`_deleteMoment()` 已
///   主动 pop；若删的是别的页面，详情页不关心。
/// - `moment_new`：永远 false（别处发新帖与当前详情无关，避免白刷）。
/// - 其它 action（包括未来扩展）：
///     · eventMomentId 匹配 viewing → true
///     · eventMomentId 为空（广播信号）且 viewing 非空 → true
///     · 其它（不同的 moment id）→ false
/// - viewing 空串：永远 false（防御，页面未完成加载时不触发）。
bool shouldRefreshDetailOnEvent({
  required String action,
  required String eventMomentId,
  required String viewingMomentId,
}) {
  if (viewingMomentId.isEmpty) return false;
  if (action == momentActionDeleted) return false;
  if (action == momentActionNew) return false;
  if (eventMomentId.isEmpty) return true;
  return eventMomentId == viewingMomentId;
}

/// Feed 页是否应在收到该 timeline 事件时重新拉取第一页。
///
/// 对已知的 moment_new / moment_deleted / moment_updated 返回 true；
/// 空 action 防御返回 false，避免未来误定义空 action 无差别刷新。
bool shouldRefreshFeedOnEvent(String action) {
  if (action.isEmpty) return false;
  return action == momentActionNew ||
      action == momentActionDeleted ||
      action == momentActionUpdated;
}

/// 提取评论的 `reply_to_uid` 字段，并 trim + 类型守卫。
///
/// - 非 String 值（null / int / Map）统一返回空字符串（防御脏数据）
/// - trim 后仍为空返回空字符串
/// - 调用方用空串表示「这不是一条回复评论」
String extractCommentReplyTarget(Map<String, dynamic> comment) {
  final raw = comment['reply_to_uid'];
  if (raw is! String) return '';
  final trimmed = raw.trim();
  return trimmed;
}

/// 将回复评论组装成显示文本：`{prefix}{replyToName}{separator}{content}`。
///
/// i18n 决策留在 UI 层，helper 只做字符串拼接与 trim 守卫：
/// - [replyToName] 为空或纯空白 → 返回原 [content]
/// - 否则 → 返回 `{prefix}{trimmed-name}{separator}{content}`
///
/// 用例：
/// - zh-CN：prefix = '回复 @', separator = '：'
/// - en-US：prefix = 'Reply @', separator = ': '
String composeReplyDisplay({
  required String content,
  required String replyToName,
  required String prefix,
  required String separator,
}) {
  final trimmedName = replyToName.trim();
  if (trimmedName.isEmpty) return content;
  return '$prefix$trimmedName$separator$content';
}

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

/// 当前 viewer 是否能看到这条 moment。
///
/// **重要：这是客户端侧二次过滤**，不能替代后端授权。用于本地缓存 / 推送
/// 消息渲染前的防御性裁剪、以及作者预览"对方视角"。
///
/// 规则与 [parseMomentVisibility] 的 5 种 wire code 严格对齐：
/// - 作者本人 → 永远可见
/// - 0 公开 → 任何人（含未登录陌生 viewer）可见
/// - 1 仅好友 → 仅 friendUids 中可见
/// - 2 仅自己 → 仅作者
/// - 3 部分可见（白名单）→ 仅 allow_uids 中可见
/// - 4 不给谁看（黑名单）→ 好友 且 不在 deny_uids 中
/// - 未知 visibility → 走 friends 安全默认（与 parseMomentVisibility 对齐）
/// - author_uid 缺失 → 永远不可见（脏数据保守拒绝）
bool canUserSeeMoment({
  required String viewerUid,
  required Map<String, dynamic> moment,
  required Set<String> friendUids,
}) {
  final author = parseModelString(moment['author_uid']).trim();
  if (author.isEmpty) return false;

  final viewer = viewerUid.trim();
  if (viewer.isNotEmpty && viewer == author) return true;

  final visibility = parseMomentVisibility(moment);
  switch (visibility) {
    case momentVisibilityPublic:
      return true;
    case momentVisibilityFriends:
      return viewer.isNotEmpty && friendUids.contains(viewer);
    case momentVisibilityPrivate:
      return false; // 已在上方 viewer == author 处理；走到这里就是别人
    case momentVisibilityAllowList:
      final allow = moment['allow_uids'];
      if (allow is! List) return false;
      return viewer.isNotEmpty && allow.whereType<String>().contains(viewer);
    case momentVisibilityDenyList:
      if (viewer.isEmpty || !friendUids.contains(viewer)) return false;
      final deny = moment['deny_uids'];
      if (deny is! List) return true;
      return !deny.whereType<String>().contains(viewer);
    default:
      // parseMomentVisibility 已把未知 code 归一到 friends，这里 unreachable
      return false;
  }
}

/// 朋友圈发布草稿（失败重发用）。
///
/// 不可变值对象。`buildMomentDraft` 序列化为 map 写入 storage，
/// `restoreMomentDraft` 反序列化回来。
class MomentDraft {
  const MomentDraft({
    required this.content,
    required this.mediaUrls,
    required this.visibility,
    required this.allowUids,
    required this.denyUids,
    required this.savedAt,
  });

  final String content;
  final List<String> mediaUrls;
  final int visibility;
  final List<String> allowUids;
  final List<String> denyUids;
  final DateTime? savedAt;
}

/// 把发布表单状态打包成草稿 map（用于 storage 持久化）。
///
/// 字段命名贴近后端 / 数据库列名（snake_case），方便日后切换 sqlite 持久化。
Map<String, dynamic> buildMomentDraft({
  required String content,
  required List<String> mediaUrls,
  required int visibility,
  required List<String> allowUids,
  required List<String> denyUids,
  required DateTime savedAt,
}) {
  return <String, dynamic>{
    'content': content,
    'media_urls': List<String>.from(mediaUrls),
    'visibility': visibility,
    'allow_uids': List<String>.from(allowUids),
    'deny_uids': List<String>.from(denyUids),
    'saved_at': savedAt.toUtc().toIso8601String(),
  };
}

/// 从 storage 反序列化草稿。
///
/// 返回 null 表示「无可恢复草稿」，UI 不应弹恢复提示。判定规则：
/// - 入参 null / 空 map → null
/// - content 与 mediaUrls 同时为空 → null（无意义草稿）
///
/// 对脏数据保持降级而非 throw：
/// - 非 string content / 非 list media_urls → 视为缺失字段
/// - 未知 visibility → 回退到 [momentVisibilityFriends]（与 parseMomentVisibility 对齐）
/// - savedAt 解析失败 → null
MomentDraft? restoreMomentDraft(Map<String, dynamic>? raw) {
  if (raw == null || raw.isEmpty) return null;

  final rawContent = raw['content'];
  final content = rawContent is String ? rawContent : '';

  final rawMedia = raw['media_urls'];
  final mediaUrls = rawMedia is List
      ? rawMedia.whereType<String>().toList(growable: false)
      : const <String>[];

  if (content.isEmpty && mediaUrls.isEmpty) return null;

  final rawVisibility = raw['visibility'];
  final visibility = rawVisibility is int
      ? parseMomentVisibility({'visibility': rawVisibility})
      : momentVisibilityFriends;

  final allowUids = raw['allow_uids'] is List
      ? (raw['allow_uids'] as List).whereType<String>().toList(growable: false)
      : const <String>[];
  final denyUids = raw['deny_uids'] is List
      ? (raw['deny_uids'] as List).whereType<String>().toList(growable: false)
      : const <String>[];

  DateTime? savedAt;
  final rawSavedAt = raw['saved_at'];
  if (rawSavedAt is String) {
    savedAt = DateTime.tryParse(rawSavedAt);
  }

  return MomentDraft(
    content: content,
    mediaUrls: mediaUrls,
    visibility: visibility,
    allowUids: allowUids,
    denyUids: denyUids,
    savedAt: savedAt,
  );
}

/// feed 渲染快照：哪份数据 + 是否为离线副本。
class MomentFeedSnapshot {
  const MomentFeedSnapshot({required this.items, required this.isStale});

  final List<Map<String, dynamic>> items;

  /// 数据来自本地缓存（远程拉取失败）。UI 据此打 "离线" / "网络异常" 标签。
  final bool isStale;
}

/// feed 离线兜底：决定使用 remote 还是 cached 作为渲染源。
///
/// - `remote` 为 null 表示远程拉取失败 / 抛异常
/// - `remote` 为空 list 仍算成功（用户可能真的清空了所有动态）
/// - 失败回退到 `cached`，并打 `isStale=true`，UI 据此提示离线
/// - 始终返回 cached 的浅拷贝，避免外部 mutate 影响调用方持有的引用
MomentFeedSnapshot pickFeedSnapshot({
  required List<Map<String, dynamic>>? remote,
  required List<Map<String, dynamic>> cached,
}) {
  if (remote != null) {
    return MomentFeedSnapshot(items: remote, isStale: false);
  }
  return MomentFeedSnapshot(
    items: List<Map<String, dynamic>>.from(cached),
    isStale: true,
  );
}

/// 朋友圈媒体校验最大图片数量（与微信对齐）。
const int momentMaxImageCount = 9;

/// 朋友圈媒体校验错误码。
///
/// 这些字符串字面值会被上层 switch 用来路由 i18n 文案，禁止重命名。
const String momentMediaErrorNone = 'none';
const String momentMediaErrorTooManyImages = 'too_many_images';
const String momentMediaErrorTooManyVideos = 'too_many_videos';
const String momentMediaErrorMixed = 'mixed_image_and_video';

/// `validateMediaSelection` 的结构化结果。
///
/// 不抛异常，UI 层用 `ok` 决定是否拦截发布、用 `error` 路由 toast 文案。
class MomentMediaValidationResult {
  const MomentMediaValidationResult.ok()
    : ok = true,
      error = momentMediaErrorNone;
  const MomentMediaValidationResult.fail(this.error) : ok = false;

  final bool ok;
  final String error;
}

/// 校验朋友圈发布时选中的媒体集合。
///
/// 规则（与微信朋友圈对齐）：
/// - 空集合 → ok（纯文字动态）
/// - 最多 [momentMaxImageCount] 张图片（默认 9）
/// - 最多 1 个视频
/// - 图片与视频不能混排
///
/// 优先级：mixed > tooManyVideos > tooManyImages（先报最严重的违规）。
/// `type` 缺失视为 `image`（兼容旧载荷，避免整盘拒绝）。
MomentMediaValidationResult validateMediaSelection(
  List<Map<String, dynamic>> items,
) {
  if (items.isEmpty) return const MomentMediaValidationResult.ok();
  var imageCount = 0;
  var videoCount = 0;
  for (final item in items) {
    final type = parseModelString(item['type']);
    if (type == 'video') {
      videoCount++;
    } else {
      // image / 未知 / 空 → 一律按图片计
      imageCount++;
    }
  }
  if (imageCount > 0 && videoCount > 0) {
    return const MomentMediaValidationResult.fail(momentMediaErrorMixed);
  }
  if (videoCount > 1) {
    return const MomentMediaValidationResult.fail(
      momentMediaErrorTooManyVideos,
    );
  }
  if (imageCount > momentMaxImageCount) {
    return const MomentMediaValidationResult.fail(
      momentMediaErrorTooManyImages,
    );
  }
  return const MomentMediaValidationResult.ok();
}

/// 文本中一处 `@用户名` 提及。
///
/// - [name]：`@` 之后的用户名（不含 `@`）
/// - [start] / [end]：在原文本中的下标，`text.substring(start, end)` 等于 `@name`
class MomentMention {
  const MomentMention({
    required this.name,
    required this.start,
    required this.end,
  });

  final String name;
  final int start;
  final int end;
}

/// 从评论 / 发布文本中提取 `@用户名` 提及。
///
/// 用户名由 Unicode 字母、数字、下划线组成（覆盖中英文），遇到空白 / 标点 /
/// 第二个 `@` 即终止。`@` 必须出现在文本起点或空白之后，避免把邮箱
/// `alice@example.com` 中的 `@example` 误识别为 mention。
///
/// 仅做 **形如 mention 的子串识别**，不做 uid 解析；调用方需要再用名字去
/// 联系人 / 群成员表里查 uid。返回顺序与文本顺序一致，重复出现都保留以便
/// UI 层逐处高亮。
List<MomentMention> extractMentions(String text) {
  if (text.isEmpty) return const [];
  // (?:^|\s) — 行首或空白后；不消费空白用 (?<=) 后行断言
  // [\w\u4e00-\u9fa5]+ — 字母/数字/下划线/中日韩统一表意
  final regex = RegExp(r'(?<=^|\s)@([\w\u4e00-\u9fa5]+)');
  final mentions = <MomentMention>[];
  for (final match in regex.allMatches(text)) {
    final name = match.group(1);
    if (name == null || name.isEmpty) continue;
    mentions.add(MomentMention(name: name, start: match.start, end: match.end));
  }
  return mentions;
}

/// 是否还能继续加载下一页评论 / feed。
///
/// 把分散在 detail / feed 页 `_loadMore*` 顶部的三段 guard 合一：
/// - 已在加载（`isLoading`）→ false（防抖，避免双拉）
/// - 后端已告知没有更多（`!hasMore`）→ false
/// - cursor 为 null / 空字符串 / 纯空白 → false（无可用游标无法翻页）
///
/// 调用方只需 `if (!canLoadMoreComments(...)) return;` 一行。
bool canLoadMoreComments({
  required bool isLoading,
  required bool hasMore,
  required String? cursor,
}) {
  if (isLoading) return false;
  if (!hasMore) return false;
  if (cursor == null) return false;
  if (cursor.trim().isEmpty) return false;
  return true;
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

/// 解析用户输入的 UID 列表字符串（半角逗号分隔）。
///
/// - trim 每项，丢弃空项 / 连续逗号 / 尾随逗号 / 纯空白输入
/// - 保序，不去重（重复由后端幂等处理，前端不私自裁剪语义）
/// - 返回不可增长 list，调用方不应再 mutate
///
/// 前端 UI 约定用户只能输半角 `,`；全角 `，` 不做兼容解析，
/// 以避免「看起来输入了 3 个 UID 实际只拆出 1 个」的静默误解析。
List<String> parseMomentUidList(String raw) {
  if (raw.trim().isEmpty) return const [];
  return raw
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

/// 构造当前用户的「发布失败草稿」存储 key。
///
/// - 非空 uid → `moment_failed_draft_{uid}`（账号隔离，防跨账号泄漏）
/// - 空 / 纯空白 uid → `''`；调用方据此跳过读写，避免产生无主 kv 噪音
/// - 对 uid 做 trim，避免 `' 42'` 与 `'42'` 生成两个 key
String momentFailedDraftKey(String uid) {
  final trimmed = uid.trim();
  if (trimmed.isEmpty) return '';
  return 'moment_failed_draft_$trimmed';
}

/// 从 comments 列表中剔除 `id` 等于 [commentId] 的条目。
///
/// 与 [removeMomentById] 同构：
/// - 返回新的不可增长 list，不 mutate 输入
/// - 空 [commentId] → 原样返回拷贝（防御，避免「空 id 匹配全部 id 为空的项目」
///   造成误批量删除）
List<Map<String, dynamic>> removeCommentById(
  List<Map<String, dynamic>> comments,
  String commentId,
) {
  if (commentId.isEmpty) {
    return List<Map<String, dynamic>>.from(comments);
  }
  return comments
      .where((item) => parseModelString(item['id']) != commentId)
      .toList(growable: false);
}

/// 评论回复目标：`(uid, name)` 对，用于 detail 页回复态预填。
///
/// 使用 `MomentReplyTarget.none` 表示「未进入回复态」（等价于顶层评论），
/// 而不是用 `null` —— 调用方 `setState` 时直接赋值更简洁，也避免 nullable
/// 传染到 UI 文案拼接处。
class MomentReplyTarget {
  const MomentReplyTarget({required this.uid, required this.name});

  /// 空目标 —— 用于「取消回复」/「无匹配」等场景。
  static const MomentReplyTarget none = MomentReplyTarget(uid: '', name: '');

  final String uid;
  final String name;

  bool get isNone => uid.isEmpty;
}

/// 从评论 map 解析回复目标。
///
/// - uid 缺失 / 空 → 返回 [MomentReplyTarget.none]
/// - 名称优先级走 [resolveMomentDisplayName]：remark > nickname > uid
///   （与作者名解析保持同一真相源，避免两处命名漂移）
/// 是否应该触发 feed 列表的下一页加载。
///
/// 把 feed 页 `_onScroll` 中的三段判断合一：
/// - `isLoadingMore = true` → false（防抖，避免重复请求）
/// - `hasMore = false` → false（已到末页）
/// - 距底距离 `maxExtent - pixels >= threshold` → false（还没到预拉区）
///
/// 触发边界采用闭区间（`pixels >= maxExtent - threshold`），与原始
/// `_onScroll` 的 `<` 早返回严格一致。改成开区间会让用户「贴着边界
/// 慢速滚动」时错过触发。
///
/// 默认 [threshold] = 320 像素 —— 距底 320px 时即开始预拉，UI 顺滑无感。
/// `hasClients` / `ScrollController` 这类 Flutter 特定 guard 留在 widget。
bool shouldTriggerFeedLoadMore({
  required double pixels,
  required double maxExtent,
  required bool isLoadingMore,
  required bool hasMore,
  double threshold = 320,
}) {
  if (isLoadingMore || !hasMore) return false;
  return pixels >= maxExtent - threshold;
}

MomentReplyTarget buildReplyTarget(Map<String, dynamic> comment) {
  final uid = parseModelString(comment['user_id']);
  if (uid.isEmpty) return MomentReplyTarget.none;
  final remark = parseModelString(comment['user_remark']);
  final nickname = parseModelString(comment['user_nickname']);
  final name = resolveMomentDisplayName(
    remark: remark,
    nickname: nickname,
    uid: uid,
  );
  return MomentReplyTarget(uid: uid, name: name);
}

/// 从 media item 安全解析视频时长（毫秒）。
int mediaDurationMs(Map<String, dynamic> media) {
  final raw = media['duration_ms'];
  if (raw is int) return raw < 0 ? 0 : raw;
  if (raw is num) return raw.toInt().clamp(0, 1 << 31);
  if (raw is String) return int.tryParse(raw) ?? 0;
  return 0;
}

/// 把毫秒时长格式化为 `M:SS` / `H:MM:SS`。
String formatVideoDuration(int ms) {
  if (ms <= 0) return '0:00';
  final totalSec = ms ~/ 1000;
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = totalSec % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// 把 RFC3339 格式的 created_at 转成相对时间显示。解析失败回退到原始字符串。
String momentRelativeTime(String createdAt) {
  final trimmed = createdAt.trim();
  if (trimmed.isEmpty) return '';
  final dt = DateTime.tryParse(trimmed);
  if (dt == null) {
    // 后端可能返回裸毫秒 epoch（如 "1784034763781"），tryParse 返回 null，
    // 此时按毫秒时间戳解析，避免把原始数字串直接显示到 UI。
    final ms = int.tryParse(trimmed);
    if (ms == null) return trimmed;
    return DateTimeHelper.dateTimeFmt(
      DateTimeHelper.millisecondToDateTime(ms, isUtc: true),
    );
  }
  return DateTimeHelper.dateTimeFmt(dt);
}

/// 从 moment payload 安全提取 `recent_likers` 列表。
List<Map<String, dynamic>> parseRecentLikers(Map<String, dynamic> moment) {
  final raw = moment['recent_likers'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

String _likerDisplayName(Map<String, dynamic> liker) {
  return resolveMomentDisplayName(
    remark: parseModelString(liker['remark']),
    nickname: parseModelString(liker['nickname']),
    uid: parseModelString(liker['uid']),
  );
}

/// 构建朋友圈点赞人文案（对齐微信规则）。
String buildLikersLabel(
  List<Map<String, dynamic>> likers,
  int totalCount, {
  Translations? translations,
}) {
  if (totalCount <= 0 && likers.isEmpty) return '';
  final effectiveTotal = totalCount > 0 ? totalCount : likers.length;
  final names = likers.map(_likerDisplayName).where((n) => n != '?').toList();
  final namesJoined = names.join('、');
  final tr = translations ?? t;
  if (names.length >= effectiveTotal) {
    return tr.discovery.momentLikedBy(names: namesJoined);
  }
  // 昵称一个都没解析出来时，"$names 等N人赞了"会渲染成病句
  // " 等1人赞了"（QA#27），降级为纯计数文案。
  if (names.isEmpty) {
    return tr.discovery.momentLikesCountOnly(count: effectiveTotal.toString());
  }
  return tr.discovery.momentAndOthersLiked(
    names: namesJoined,
    count: effectiveTotal.toString(),
  );
}

/// 当前是否处于不限流量的网络（WiFi / 以太网）。失败保守返回 false。
Future<bool> isUnmeteredNetwork() async {
  try {
    final results = await Connectivity().checkConnectivity();
    return results.any(
      (r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet,
    );
  } on Exception {
    return false;
  }
}
