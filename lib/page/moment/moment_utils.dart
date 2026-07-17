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
    final uid = parseModelString(item['author_uid']);
    if (uid.isEmpty) {
      enriched.add(item);
      continue;
    }
    final info = await lookup(uid);
    final copy = Map<String, dynamic>.from(item);
    copy['author_nickname'] = info['nickname'] ?? '';
    copy['author_remark'] = info['remark'] ?? '';
    copy['author_avatar'] = info['avatar'] ?? '';
    enriched.add(copy);
  }
  return enriched;
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
