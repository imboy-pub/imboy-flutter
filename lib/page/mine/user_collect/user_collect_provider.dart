import 'dart:convert' show jsonDecode;
import 'package:imboy/theme/default/app_spacing.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/component/helper/datetime.dart' show DateTimeHelper;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/modules/security_privacy/public.dart';
import 'package:imboy/page/single/video_viewer_page.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_provider.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/message_model.dart' show MessageModel;
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:imboy/store/api/user_collect_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart'
    show MessageRepo;
import 'package:imboy/store/repository/user_collect_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/component/chat/message_audio_builder.dart' as audio;

import 'user_collect_state.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';
import 'package:imboy/service/assets.dart' show AssetsService;

part 'user_collect_provider.g.dart';

/// 归一化历史收藏的附件 uri：
/// 新收藏的 source 已是 Garage object_key（走 presign 授权）；历史收藏
/// 快照的是完整 URL（go-fastdfs 时代），对 Garage 资源必 401。若该 URL
/// 的 path 是 object_key 形态（`u<uid>/...`），提取 path 交给授权链复活；
/// 否则原样返回（渲染侧已优雅降级占位）。
String normalizeCollectUri(String uri) {
  if (uri.isEmpty || !uri.contains('://')) return uri;
  final u = Uri.tryParse(uri);
  if (u == null) return uri;
  final path = u.path.startsWith('/') ? u.path.substring(1) : u.path;
  return AssetsService.isObjectKey(path) ? path : uri;
}

/// UserCollect Notifier
/// 处理收藏相关的业务逻辑
@riverpod
class UserCollectNotifier extends _$UserCollectNotifier {
  @override
  UserCollectState build() {
    return UserCollectState();
  }

  /// 更新状态
  void updateState(UserCollectState newState) {
    state = newState;
  }

  Future<List<UserCollectModel>> page({
    int page = 1,
    int size = 10,
    String? kind,
    String? tag,
    String? kwd,
    bool onRefresh = false,
  }) async {
    final List<UserCollectModel> result = [];
    final repo = UserCollectRepo();

    try {
      // 标记加载状态
      if (onRefresh) state.isRefreshing = true;
      // 先尝试从本地分页读取（除非强制刷新）
      if (!onRefresh) {
        page = page > 1 ? page : 1;
        final int offset = (page - 1) * size;

        String where = '${UserCollectRepo.userId}=?';
        List<Object?> whereArgs = [UserRepoLocal.to.currentUid];
        String? orderBy;
        if (kind == state.recentUse) {
          orderBy = "${UserCollectRepo.updatedAt} desc, auto_id desc";
          where = "$where and ${UserCollectRepo.updatedAt} >= 0";
        } else if (kind != null && int.tryParse(kind) != null) {
          where = "$where and ${UserCollectRepo.kind}=?";
          whereArgs.add(kind);
        }
        if (tag != null) {
          where = "$where and ${UserCollectRepo.tag} like '%$tag,%'";
        }
        if (strNoEmpty(kwd)) {
          where =
              "$where and (${UserCollectRepo.source} like '%$kwd%' or ${UserCollectRepo.remark} like '%$kwd%' or ${UserCollectRepo.info} like '%$kwd%')";
        }
        if (kDebugMode) iPrint("searchLeading_tag query executing");

        final List<UserCollectModel> localList = await repo.page(
          limit: size,
          offset: offset,
          where: where,
          whereArgs: whereArgs,
          orderBy: orderBy,
        );
        if (kDebugMode) iPrint("searchLeading_tag list ${localList.length}");

        if (page == 1 && localList.isEmpty) {
          // 如果第一页本地没有，继续走服务端请求
        } else {
          // 本地有数据，直接返回（并更新 hasMore）
          await _decryptCollectModels(localList);
          state.hasMore = localList.length >= size;
          return localList;
        }
      }

      // 构建服务端请求参数
      final Map<String, dynamic> args = {'page': page, 'size': size};
      if (kind == state.recentUse) {
        args['order'] = state.recentUse;
      } else if (kind != null && int.tryParse(kind) != null) {
        args['kind'] = kind;
      }
      if (strNoEmpty(kwd)) {
        args['kwd'] = kwd;
      }
      if (strNoEmpty(tag)) {
        args['tag'] = tag;
      }

      final Map<String, dynamic>? payload = await UserCollectApi().page(args);
      if (payload == null || payload['list'] == null) {
        // 服务端返回为空或异常，标记无更多并返回空列表
        state.hasMore = false;
        return [];
      }

      for (var json in (payload['list'] as List)) {
        json['user_id'] = json['user_id'] ?? UserRepoLocal.to.currentUid;
        final UserCollectModel model = UserCollectModel.fromJson(
          json as Map<String, dynamic>,
        );
        await repo.save(json);
        result.add(model);
      }
      await _decryptCollectModels(result);

      // 翻页时去重（防止重复项）
      if (page > 1 && state.items.isNotEmpty) {
        final existing = state.items.map((e) => e.kindId).toSet();
        final filtered = result
            .where((r) => !existing.contains(r.kindId))
            .toList();
        // 更新 hasMore：以过滤后的数量判断
        state.hasMore = filtered.length >= size;
        return filtered;
      }

      // 非翻页或第一页：直接按照数量判断 hasMore
      state.hasMore = result.length >= size;
      return result;
    } on Exception {
      if (kDebugMode) {}
      // 出错返回空列表，外层会显示错误态或重试
      state.hasMore = false;
      return [];
    } finally {
      state.isLoading = false;
      state.isRefreshing = false;
    }
  }

  Future<void> _decryptCollectModels(List<UserCollectModel> list) async {
    for (final item in list) {
      try {
        // v2.0: 检查 e2ee 字段是否存在（而不是 msg_type == 'e2ee'）
        final e2ee = item.info['e2ee'];
        if (e2ee == null || e2ee == '') continue;
        final decrypted = await E2EEService.decryptIncomingPayload(
          payload: item.info,
        );
        if (!identical(decrypted, item.info)) {
          item.info = Map<String, dynamic>.from(decrypted);
        }
      } on Exception {
        if (kDebugMode) {}
      }
    }
  }

  /// 显示分类标签
  /// scene page | detail
  Widget buildItemBody(
    BuildContext context,
    UserCollectModel obj,
    String scene,
  ) {
    // 缓存屏幕尺寸，避免重复使用 screenWidth/screenHeight
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    Widget body = const SizedBox.shrink();
    // Kind 被收藏的资源种类： 1 文本  2 图片  3 语音  4 视频  5 文件  6 位置消息
    if (obj.kind == 1) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              obj.info['text'] as String? ??
                  (obj.info['payload']['text'] as String? ?? ''),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: scene == 'page' ? 4 : 160,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (obj.kind == 2) {
      String uri = normalizeCollectUri(
        obj.info['payload']['uri'] as String? ?? '',
      );
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          scene == 'page'
              ? Image(
                  width: screenWidth * 0.5,
                  height: 120,
                  fit: BoxFit.cover,
                  image: cachedImageProvider(uri, w: screenWidth),
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: screenWidth * 0.5,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: AppRadius.borderRadiusLarge,
                    ),
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : InkWell(
                  onTap: () async {
                    zoomInPhotoView(context, uri);
                  },
                  child: Image(
                    // detail 里面减去左右 padding 和
                    width: screenWidth - 20,
                    fit: BoxFit.cover,
                    image: cachedImageProvider(uri, w: screenWidth),
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: screenWidth - 20,
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: AppRadius.borderRadiusLarge,
                      ),
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Text(
                  formatBytes(obj.info['payload']['size'] as int? ?? 0),
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  " ${obj.info['payload']['width']}X${obj.info['payload']['height']}",
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      );
    } else if (obj.kind == 3) {
      int durationMS = obj.info['payload']['duration_ms'] as int? ?? 0;
      // row > expand > column > text 换行有效
      body = scene == 'page'
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 9,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        durationMS > 0 ? "${durationMS / 1000} ''" : '',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Column(children: [Icon(Icons.graphic_eq, size: 28)]),
                ),
              ],
            )
          : FutureBuilder<CustomMessage?>(
              future:
                  MessageModel.fromJson(obj.info).toTypeMessage()
                      as Future<CustomMessage?>,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      t.common.loadFailedWithError(
                        error: snapshot.error.toString(),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                return audio.AudioMessageBuilder(
                  type: 'C2C', // 默认作为 C2C 渲染，或者根据 metadata 判断
                  user: User(
                    id: UserRepoLocal.to.currentUid,
                    name: UserRepoLocal.to.current.nickname,
                    imageSource: UserRepoLocal.to.current.avatar,
                  ),
                  message: snapshot.data,
                );
              },
            );
    } else if (obj.kind == 4) {
      String uri = obj.info['payload']['thumb']['uri'] as String? ?? '';
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.centerRight,
            children: <Widget>[
              Image(
                width: scene == 'page' ? screenWidth * 0.5 : screenWidth - 20,
                height: scene == 'page' ? 120 : screenHeight * 0.618,
                fit: BoxFit.cover,
                image: cachedImageProvider(uri, w: screenWidth * 0.5),
              ),
              Positioned.fill(
                child: InkWell(
                  onTap: () {
                    final String uri =
                        obj.info['payload']['video']['uri'] as String? ?? '';
                    final String thumb =
                        obj.info['payload']['thumb']['uri'] as String? ?? '';
                    if (uri.isEmpty) {
                      AppLoading.showError(
                        t
                            .common
                            .collectedVideoFormatIncorrectCannotFindVideoUri,
                      );
                    } else {
                      Navigator.push(
                        context,
                        CupertinoPageRoute<dynamic>(
                          builder: (context) =>
                              VideoViewerPage(url: uri, thumb: thumb),
                        ),
                      );
                    }
                  },
                  child: SizedBox(
                    height: 100,
                    child: Center(
                      child: Icon(
                        Icons.video_library,
                        color: AppColors.onPrimary,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Text(
                  formatBytes(
                    obj.info['payload']['video']['size'] as int? ?? 0,
                  ),
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  " ${obj.info['payload']['video']['width']}X${obj.info['payload']['video']['height']}",
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      );
    } else if (obj.kind == 5) {
      String mimeType = (obj.info['payload']['mimeType'] ?? '')
          .toString()
          .toLowerCase();
      body = scene == 'page'
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        obj.info['payload']['name'] as String? ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      "$mimeType  ${formatBytes(obj.info['payload']['size'] as int? ?? 0)}",
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            )
          : Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Flexible(
                      child: Text(
                        obj.info['payload']['name'] as String? ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(
                        "${t.chat.fileSize}: ${formatBytes(obj.info['payload']['size'] as int? ?? 0)}",
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      mimeType,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            );
    } else if (obj.kind == 6) {
      String title = obj.info['payload']['title'] as String? ?? '';
      String address = obj.info['payload']['address'] as String? ?? '';

      body = scene == 'page'
          ? Row(
              children: [
                Expanded(
                  flex: 9,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      AppSpacing.verticalSmall,
                      Text(
                        address,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const Expanded(
                  flex: 1,
                  child: Column(
                    children: [Icon(Icons.location_on_outlined, size: 28)],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    width: screenWidth - 20,
                    height: screenHeight - 160,
                    padding: AppSpacing.allRegular,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.borderRadiusSmall,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            AppSpacing.horizontalSmall,
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.verticalMedium,
                        Text(
                          address,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.8),
                          ),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
    } else if (obj.kind == 7) {
      // 个人名片
      String nickname = obj.info['payload']['nickname'] as String? ?? '';
      String avatar = obj.info['payload']['avatar'] as String? ?? '';
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              padding: AppSpacing.allMedium,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.borderRadiusSmall,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.borderRadiusLarge,
                    child: Image(
                      image: cachedImageProvider(avatar, w: 40),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: AppRadius.borderRadiusLarge,
                          ),
                          child: Icon(
                            Icons.person,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        );
                      },
                    ),
                  ),
                  AppSpacing.horizontalMedium,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nickname,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        AppSpacing.verticalTiny,
                        Text(
                          t.common.personalCard,
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return scene == 'detail'
        ? SizedBox(
            width: screenWidth - 8,
            height: screenHeight - 120,
            child: SingleChildScrollView(child: body),
          )
        : body;
  }

  /// 点击分类标签，按Tag搜索
  Future<void> searchByTag(
    BuildContext context,
    String tag,
    String kindTips,
    Function callback,
  ) async {
    state.page = 1;
    if (kDebugMode) iPrint("searchLeading_tag searchByTag executing");
    var list = await page(page: state.page, size: state.size, tag: tag);
    if (list.isNotEmpty) {
      state.page += 1;
    }
    state.items = list;

    state.searchTrailing = [
      InkWell(
        onTap: () {
          if (state.kwd.isEmpty) {
            return;
          }
          doSearch(state.kwd);
        },
        child: const Icon(Icons.search),
      ),
    ].map((e) => e).toList();

    state.searchLeading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ElevatedButton(
            onPressed: () {
              state.searchLeading = null;
              state.searchTrailing = null;
              state.kwd = '';
              state.searchController.text = "";
              state.kindActive = !state.kindActive;
              state.kindActive = !state.kindActive;
              state.kind = 'all';
              callback();
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.pressed)) {
                  return ThemeData().colorScheme.surface.withAlpha(191);
                }
                return ThemeData().colorScheme.surface;
              }),
            ),
            child: IntrinsicWidth(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Transform.scale(
                      scaleX: -1,
                      child: Icon(
                        Icons.local_offer,
                        size: 18,
                        color: ThemeData().colorScheme.onPrimary.withAlpha(191),
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      kindTips,
                      style: TextStyle(
                        color: ThemeData().colorScheme.onPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AppSpacing.horizontalMedium,
                  Icon(
                    Icons.close,
                    size: 16,
                    color: Theme.of(
                      // ignore: use_build_context_synchronously resolveWith 同步回调,paint 时 context 有效
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: 0.75),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 点击分类标签，按分类搜索
  Future<void> searchByKind(
    BuildContext context,
    String kind,
    String kindTips,
    Function callback,
  ) async {
    state.page = 1;
    state.kind = kind;
    var list = await page(page: state.page, size: state.size, kind: kind);
    if (list.isNotEmpty) {
      state.page += 1;
    }
    state.items = list;

    state.searchTrailing = [
      InkWell(
        onTap: () {
          if (state.kwd.isEmpty) {
            return;
          }
          doSearch(state.kwd);
        },
        child: const Icon(Icons.search),
      ),
    ].map((e) => e).toList();

    state.searchLeading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ElevatedButton(
            onPressed: () {
              state.searchLeading = null;
              state.searchTrailing = null;
              state.kwd = '';
              state.searchController.text = "";
              state.kindActive = !state.kindActive;
              state.kindActive = !state.kindActive;
              state.kind = 'all';
              callback();
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.pressed)) {
                  return ThemeData().colorScheme.surface.withAlpha(191);
                }
                return ThemeData().colorScheme.surface;
              }),
            ),
            child: IntrinsicWidth(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Transform.scale(
                      scaleX: -1,
                      child: Icon(
                        Icons.grid_view,
                        size: 18,
                        color: Theme.of(
                          // ignore: use_build_context_synchronously resolveWith 同步回调,paint 时 context 有效
                          context,
                        ).colorScheme.onPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      kindTips,
                      style: TextStyle(
                        color: ThemeData().colorScheme.onPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AppSpacing.horizontalMedium,
                  Icon(
                    Icons.close,
                    size: 16,
                    color: Theme.of(
                      // ignore: use_build_context_synchronously resolveWith 同步回调,paint 时 context 有效
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<List<UserCollectModel>> doSearch(String query) async {
    if (kDebugMode) debugPrint("user_collect_s_doSearch executing");

    state.page = 1;
    var list = await page(
      page: state.page,
      size: state.size,
      kind: state.kind,
      kwd: query.toString(),
    );
    if (list.isNotEmpty) {
      state.page += 1;
    }
    state.items = list;
    return list;
  }

  /// 删除收藏（带防重复提交与错误回滚）
  /// 参数：
  ///   obj - 要删除的收藏项
  /// 返回：删除是否成功（bool）
  Future<bool> remove(UserCollectModel obj) async {
    final String id = obj.kindId.toString();
    // 防止并发删除同一项
    if (state.removingIds.contains(id)) {
      if (kDebugMode) iPrint('remove already in progress');
      return false;
    }
    state = state.copyWith()..removingIds.add(id);

    try {
      // 1) 先请求后端删除（若后端删除失败，则不更新本地）
      bool remoteOk = await UserCollectApi().remove(kindId: id);
      if (!remoteOk) {
        if (kDebugMode) iPrint('remote remove failed');
        return false;
      }

      // 2) 再删除本地库记录
      int deleted = await UserCollectRepo().delete(id);
      if (deleted > 0) {
        return true;
      } else {
        // 本地删除失败：记录日志并尝试通知（此处为占位，可实现回滚策略）
        if (kDebugMode) iPrint('local delete failed after remote remove');
        return false;
      }
    } on Exception {
      if (kDebugMode) {}
      return false;
    } finally {
      // 无论成功或失败都释放锁
      state = state.copyWith()..removingIds.remove(id);
    }
  }

  /// 收藏的信息来源，消息发布中的昵称或者备注
  Future<String> getCollectSource(String authorId) async {
    ContactModel? obj = await ContactRepo().findByUid(
      authorId,
      autoFetch: true,
    );
    if (kDebugMode) {}
    if (obj == null) {
      return '';
    }
    return obj.title;
  }

  /// 转发收藏回调
  Future<bool> change(String kindId) async {
    bool res = await UserCollectApi().change({
      'action': 'transpond_callback',
      'kind_id': kindId,
    });

    if (res) {
      await UserCollectRepo().save({
        UserCollectRepo.updatedAt: DateTimeHelper.millisecond() ~/ 1000,
        UserCollectRepo.userId: UserRepoLocal.to.currentUid,
        UserCollectRepo.kindId: kindId,
      });
    }
    return res;
  }

  /// 备注收藏
  Future<bool> remark(String kindId, String remark) async {
    bool res = await UserCollectApi().change({
      'action': 'remark',
      'kind_id': kindId,
      'remark': remark,
    });
    if (kDebugMode) debugPrint("send_to_view callback after $res");
    if (res) {
      await UserCollectRepo().save({
        UserCollectRepo.updatedAt: DateTimeHelper.millisecond() ~/ 1000,
        UserCollectRepo.userId: UserRepoLocal.to.currentUid,
        UserCollectRepo.kindId: kindId,
        UserCollectRepo.remark: remark,
      });
    }
    return res;
  }

  /// 按消息 id 的 in-flight 去重：调用方每次 new UserCollectNotifier，
  /// 实例锁无效，须静态锁。曾因双触发把 user_collect/add 请求发两次（QA#31）。
  static final Set<String> _addInFlight = {};

  /// 添加收藏
  Future<bool> add({required String tb, required Message msg}) async {
    if (!_addInFlight.add(msg.id)) return false;
    try {
      return await _doAdd(tb: tb, msg: msg);
    } finally {
      _addInFlight.remove(msg.id);
    }
  }

  Future<bool> _doAdd({required String tb, required Message msg}) async {
    if (kDebugMode) debugPrint("userCollectLogic/add 类型: ${msg.runtimeType}");

    int kind = getCollectKind(msg);
    // 如果消息类型不支持收藏，直接返回失败
    if (kind <= 0) {
      if (kDebugMode) {}
      return false;
    }

    String source = await getCollectSource(msg.authorId);

    // 尝试从数据库查找消息
    MessageModel? msg2 = await MessageRepo(tableName: tb).find(msg.id);

    // 如果数据库中没有找到消息，尝试从Message对象创建
    if (msg2 == null) {
      if (kDebugMode) {}
      try {
        // 创建一个基本的MessageModel
        final payload = _extractPayloadFromMessage(msg);
        msg2 = MessageModel(
          autoId: 0,
          msg.id,
          type: tb, // 使用表名作为类型
          fromId: parseModelInt(msg.authorId),
          toId: parseModelInt(msg.metadata?['peer_id']),
          payload: payload,
          createdAt:
              msg.createdAt?.millisecondsSinceEpoch ??
              DateTimeHelper.millisecond(),
          isAuthor: msg.authorId == UserRepoLocal.to.currentUid ? 1 : 0,
          conversationUk3: "", // 可能为空，因为我们是直接收藏消息
          status: 10, // 假设为已发送状态
          msgType: payload['msg_type'] as String?, // ✅ 修复：从 payload 提取 msg_type
        );
      } on Exception {
        if (kDebugMode) {}
        return false;
      }
    }

    Map<String, dynamic> info = msg2.toJson();
    var payload = info['payload'];
    if (payload is String) {
      try {
        info['payload'] = jsonDecode(payload);
      } on Exception {
        if (kDebugMode) {}
        info['payload'] = <String, dynamic>{};
      }
    }

    // 确保metadata包含在info中
    if (msg.metadata != null) {
      info['metadata'] = msg.metadata;
    }

    // ⚠️ 重要：确保 msg_type 在顶层（用于转发时恢复消息）
    // MessageModel.toJson() 可能不会输出 msg_type（如果它为空）
    // 所以我们需要显式地确保它存在

    // 优先使用 msg2.msgType（从 MessageModel 获取）
    String? finalMsgType = msg2.msgType?.toString();

    // 如果 msg2.msgType 为空，尝试从 payload 中获取
    if (finalMsgType == null || finalMsgType.isEmpty) {
      if (info['payload'] is Map) {
        final payloadData = info['payload'] as Map<String, dynamic>;
        finalMsgType = payloadData['msg_type']?.toString();
        if (kDebugMode) {}
      }
    }

    // 如果仍然为空，根据 kind 推断
    if (finalMsgType == null || finalMsgType.isEmpty) {
      switch (kind) {
        case 1:
          finalMsgType = 'text';
          break;
        case 2:
          finalMsgType = 'image';
          break;
        case 3:
          finalMsgType = 'audio';
          break;
        case 4:
          finalMsgType = 'video';
          break;
        case 5:
          finalMsgType = 'file';
          break;
        case 6:
          finalMsgType = 'location';
          break;
        case 7:
          finalMsgType = 'visitCard';
          break;
        default:
          finalMsgType = 'text';
      }
      if (kDebugMode) {}
    }

    // 强制设置 msg_type 到顶层
    info['msg_type'] = finalMsgType;

    if (kDebugMode) {}

    // 显示加载状态
    AppLoading.show(status: t.main.collecting);

    bool res = await UserCollectApi().add(kind, msg.id, source, info);

    // 隐藏加载状态
    AppLoading.dismiss();

    if (kDebugMode) {}

    if (res) {
      // 本地缓存失败不应让整个收藏 uncaught（服务端已成功，
      // 列表刷新可从服务端拉回）——曾因 UNIQUE 冲突静默炸掉（QA#31）
      try {
        await UserCollectRepo().save({
          UserCollectRepo.createdAt: DateTimeHelper.millisecond(),
          UserCollectRepo.userId: UserRepoLocal.to.currentUid,
          UserCollectRepo.kind: kind,
          UserCollectRepo.kindId: msg.id,
          UserCollectRepo.source: source,
          UserCollectRepo.info: info,
        });
        if (kDebugMode) debugPrint("userCollectLogic/add 本地保存成功");
      } on Exception catch (e) {
        if (kDebugMode) {
          debugPrint("userCollectLogic/add 本地保存失败: ${e.runtimeType}");
        }
      }
    } else {
      if (kDebugMode) debugPrint("userCollectLogic/add 服务端保存失败");
    }

    return res;
  }

  /// 从Message对象提取payload
  Map<String, dynamic> _extractPayloadFromMessage(Message msg) {
    Map<String, dynamic> payload = {};

    if (msg is TextMessage) {
      payload = {"msg_type": "text", "text": msg.text};
    } else if (msg is ImageMessage) {
      payload = {
        "msg_type": "image",
        "name": msg.text ?? "",
        "text": msg.text ?? "",
        "size": msg.size ?? 0,
        "uri": msg.source,
        "width": msg.width ?? 0,
        "height": msg.height ?? 0,
      };
    } else if (msg is FileMessage) {
      payload = {
        "msg_type": "file",
        "name": msg.name,
        "text": msg.name,
        "size": msg.size ?? 0,
        "uri": msg.source,
        "mime_type": msg.mimeType ?? "",
      };
    } else if (msg is CustomMessage) {
      // CustomMessage 需要特殊处理
      payload = Map<String, dynamic>.from(msg.metadata ?? {});
      final msgType = payload['msg_type']?.toString() ?? '';

      if (msgType.isEmpty) {
        payload['msg_type'] = 'custom';
      }
    }

    // 添加peer_id
    payload['peer_id'] = msg.metadata?['peer_id'];

    return payload;
  }

  Future<List<Widget>> tagItems(BuildContext context) async {
    String scene = 'collect';
    List<Widget> widgetList = [];
    // 通过 Riverpod provider 获取 notifier（不能直接 new，否则 state 访问会崩溃）
    final repository = ref.read(userTagRelationProvider.notifier);
    List<String> items = await repository.getRecentTagItems(scene);

    for (String tag in items) {
      widgetList.add(
        Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              if (kDebugMode) debugPrint("searchLeading_tag onTap");
              // 收起展开面板
              state.kindActive = false;
              // 执行标签搜索
              searchByTag(context, tag, tag, () {});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: AppRadius.borderRadiusRegular,
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_offer, size: 12, color: AppColors.info),
                  AppSpacing.horizontalTiny,
                  Text(
                    tag,
                    style: TextStyle(
                      color: AppColors.info,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return widgetList;
  }

  void updateItem(UserCollectModel item) {
    final index = state.items.indexWhere((e) => e.kindId == item.kindId);
    if (index > -1) {
      state.items.setRange(index, index + 1, [item]);
    }
  }

  /// Kind 被收藏的资源种类： 1 文本  2 图片  3 语音  4 视频  5 文件  6 位置消息  7 个人名片
  /// 这个方法被其他文件调用，需要保留
  static int getCollectKind(dynamic message) {
    if (kDebugMode) debugPrint("getCollectKind type: ${message.runtimeType}");
    // 由于移除了 flutter_chat_types 依赖，这里简化处理
    // 根据 message 的 metadata 或其他属性判断类型
    if (message == null) return 0;

    try {
      String msgType = message.metadata?['msg_type'] as String? ?? '';
      String messageType = message.runtimeType.toString();

      // 判断文本消息
      if (messageType.contains('TextMessage')) {
        return 1;
      }

      // 判断图片消息
      if (messageType.contains('ImageMessage')) {
        return 2;
      }

      // 判断自定义消息类型
      if (messageType.contains('CustomMessage')) {
        switch (msgType) {
          case 'voice':
            return 3;
          case 'video':
            return 4;
          case 'location':
            return 6;
          case 'visitCard':
            return 7;
          default:
            // 检查payload中的msg_type
            String msgType =
                message.metadata?['payload']?['msg_type'] as String? ?? '';
            switch (msgType) {
              case 'text':
                return 1;
              case 'image':
                return 2;
              case 'file':
                return 5;
              default:
                // 如果无法确定类型，尝试从其他属性判断
                if (message.metadata?['uri'] != null) {
                  // 有uri可能是图片、视频或音频
                  if (message.metadata?['duration_ms'] != null) {
                    return msgType == 'video' ? 4 : 3;
                  }
                  return 2;
                }
                return 0;
            }
        }
      }

      // 判断文件消息
      if (messageType.contains('FileMessage')) {
        return 5;
      }
    } on Exception catch (e) {
      if (kDebugMode) debugPrint('getCollectKind error: ${e.runtimeType}');
    }

    return 0;
  }
}

/// UserCollect 辅助类
/// 提供静态方法访问 UserCollectNotifier 的功能
class UserCollectHelper {
  /// 添加收藏（静态方法，用于非 Widget 上下文）
  static Future<bool> add({required String tb, required dynamic msg}) async {
    // 注意：这个方法需要在有 WidgetRef 的上下文中使用
    // 或者创建一个临时的 UserCollectNotifier 实例
    final notifier = UserCollectNotifier();
    return await notifier.add(tb: tb, msg: msg as Message);
  }

  /// 获取收藏类型（静态方法）
  static int getCollectKind(dynamic message) {
    return UserCollectNotifier.getCollectKind(message);
  }
}
