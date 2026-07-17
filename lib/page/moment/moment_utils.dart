import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 归一化动态的媒体字段(raw List to `List<Map<String, dynamic>>`)
List<Map<String, dynamic>> normalizeMedia(dynamic rawMedia) {
  if (rawMedia is! List) return const [];
  return rawMedia
      .whereType<Map<String, dynamic>>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

/// 归一化动态的所在位置字段：无位置(null/非 Map)返回 null，否则复制为
/// `Map<String, dynamic>`（防外部别名污染）。后端形状 `{name,lng,lat,address?}`，
/// 旧帖无该字段时安全返回 null（向后兼容）。
Map<String, dynamic>? normalizeMomentLocation(dynamic rawLocation) {
  if (rawLocation is! Map) return null;
  final copy = Map<String, dynamic>.from(rawLocation);
  // name 为展示必备项，缺失即视为无有效位置
  final name = parseModelString(copy['name']);
  if (name.isEmpty) return null;
  return copy;
}

/// 归一化 @提醒的 uid 列表：非 List 返回 const []，逐项转 String（TSID 以
/// integer 传输），空串过滤。旧帖无该字段时安全返回空列表（向后兼容）。
List<String> normalizeMomentAtUids(dynamic rawAtUids) {
  if (rawAtUids is! List) return const [];
  return rawAtUids
      .map((e) => parseModelString(e))
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}

/// 朋友圈媒体九宫格布局（微信标准形态）：
/// - 1 张：单列（单图/单视频由调用方按宽高比大图展示）
/// - 4 张：2×2 排列
/// - 其余（2/3/5-9 张）：三列网格
///
/// cell 尺寸恒按三列计算（微信 4 图 2×2 的格子与九宫格同尺寸），
/// floor 取整保证 Wrap 不因浮点误差换行。
/// spacing 由调用方传 AppSpacing token（本文件保持纯 Dart 无 Flutter 依赖）。
({int columns, double cellSize}) momentGridLayout({
  required int count,
  required double maxWidth,
  double spacing = 8.0,
}) {
  final columns = count == 1 ? 1 : (count == 4 ? 2 : 3);
  final cellSize = ((maxWidth - spacing * 2) / 3).floorToDouble();
  return (columns: columns, cellSize: cellSize);
}

/// 从 media item 解析宽高比（width/height 元数据），无有效数据返回 null。
double? mediaAspectRatio(Map<String, dynamic> media) {
  final w = parseModelInt(media['width']);
  final h = parseModelInt(media['height']);
  if (w > 0 && h > 0) return w / h;
  return null;
}

/// 单条视频展示尺寸：按视频宽高比 letterbox，无元数据退化 16:9；
/// 高度上限为 maxWidth（竖屏视频不超过正方形高度，等比收缩宽度）。
({double width, double height}) momentVideoDisplaySize({
  required double maxWidth,
  double? aspectRatio,
}) {
  final aspect = (aspectRatio != null && aspectRatio > 0)
      ? aspectRatio
      : 16 / 9;
  var width = maxWidth;
  var height = width / aspect;
  if (height > maxWidth) {
    height = maxWidth;
    width = height * aspect;
  }
  return (width: width, height: height);
}

/// 安全获取当前用户 UID，未登录时返回空字符串
/// 直接使用 UserRepoLocal.to.currentUid（不会抛异常）
String currentUidOrEmpty() => UserRepoLocal.to.currentUid;

/// 为动态列表批量填充作者昵称和头像。
///
/// 对每个 item 的 `author_uid` 查询本地联系人库，
/// 将结果写入 `author_nickname` 和 `author_avatar` 字段。
/// 缓存已查询过的 uid 避免重复 IO。
Future<List<Map<String, dynamic>>> enrichItemsWithAuthor(
  List<Map<String, dynamic>> items,
) async {
  if (items.isEmpty) return items;
  final contactRepo = ContactRepo();
  final cache = <String, Map<String, String>>{};

  Future<Map<String, String>> lookup(String uid) async {
    if (cache.containsKey(uid)) return cache[uid]!;
    final contact = await contactRepo.findByUid(uid);
    final info = <String, String>{
      'nickname': contact?.nickname ?? '',
      'remark': contact?.remark ?? '',
      'avatar': contact?.avatar ?? '',
    };
    cache[uid] = info;
    return info;
  }

  final enriched = <Map<String, dynamic>>[];
  for (final item in items) {
    final copy = Map<String, dynamic>.from(item);
    final uid = parseModelString(item['author_uid']);
    if (uid.isNotEmpty) {
      final info = await lookup(uid);
      copy['author_nickname'] = info['nickname'] ?? '';
      copy['author_remark'] = info['remark'] ?? '';
      copy['author_avatar'] = info['avatar'] ?? '';
    }
    // @提醒昵称解析：复用同一 contact 缓存，将展示名(remark>nickname>uid)
    // 写入 at_names 供展示层同步读取，避免每张卡片各自 IO 造成滚动抖动。
    final atUids = normalizeMomentAtUids(item['at_uids']);
    if (atUids.isNotEmpty) {
      final names = <String>[];
      for (final atUid in atUids) {
        final info = await lookup(atUid);
        final remark = info['remark'] ?? '';
        final nickname = info['nickname'] ?? '';
        names.add(
          remark.isNotEmpty ? remark : (nickname.isNotEmpty ? nickname : atUid),
        );
      }
      copy['at_names'] = names;
    }
    enriched.add(copy);
  }
  return enriched;
}

/// 提取动态 @提醒的展示名列表：优先用 [enrichItemsWithAuthor] 阶段解析写入的
/// `at_names`（remark>nickname>uid），缺失时回退裸 uid 列表（未 enrich 的场景）。
List<String> momentAtNames(Map<String, dynamic> item) {
  final raw = item['at_names'];
  if (raw is List) {
    final names = raw
        .map((e) => parseModelString(e))
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    if (names.isNotEmpty) return names;
  }
  return normalizeMomentAtUids(item['at_uids']);
}

/// 为单个动态（帖子）填充作者信息。
Future<Map<String, dynamic>> enrichPostWithAuthor(
  Map<String, dynamic> post,
) async {
  final list = await enrichItemsWithAuthor([post]);
  return list.first;
}

/// 为评论列表填充用户昵称和头像。
///
/// 评论的 uid 字段名为 `user_id`（不同于动态的 `author_uid`）。
Future<List<Map<String, dynamic>>> enrichCommentsWithUser(
  List<Map<String, dynamic>> comments,
) async {
  if (comments.isEmpty) return comments;
  final contactRepo = ContactRepo();
  final cache = <String, Map<String, String>>{};

  Future<Map<String, String>> lookup(String uid) async {
    if (cache.containsKey(uid)) return cache[uid]!;
    final contact = await contactRepo.findByUid(uid);
    final info = <String, String>{
      'nickname': contact?.nickname ?? '',
      'remark': contact?.remark ?? '',
      'avatar': contact?.avatar ?? '',
    };
    cache[uid] = info;
    return info;
  }

  final enriched = <Map<String, dynamic>>[];
  for (final c in comments) {
    final uid = parseModelString(c['user_id']);
    if (uid.isEmpty) {
      enriched.add(c);
      continue;
    }
    final info = await lookup(uid);
    final copy = Map<String, dynamic>.from(c);
    copy['user_nickname'] = info['nickname'] ?? '';
    copy['user_remark'] = info['remark'] ?? '';
    copy['user_avatar'] = info['avatar'] ?? '';
    enriched.add(copy);
  }
  return enriched;
}
