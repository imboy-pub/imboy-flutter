import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide AudioMessageBuilder;

// ignore: depend_on_referenced_packages
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/chat/message_audio_builder.dart' show AudioMessageBuilder;
import 'package:imboy/component/chat/message_location_builder.dart';
import 'package:imboy/component/chat/message_visit_card_builder.dart';

import 'package:imboy/page/single/video_viewer.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_logic.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:imboy/store/provider/user_collect_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_collect_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'user_collect_state.dart';

// 用户收藏逻辑控制器
class UserCollectLogic extends GetxController {
  final UserCollectState state = UserCollectState();

  Future<List<UserCollectModel>> page({
    int page = 1,
    int size = 10,
    String? kind,
    String? tag,
    String? kwd,
    bool onRefresh = false,
  }) async {
    List<UserCollectModel> list = [];

    var repo = UserCollectRepo();

    if (onRefresh == false) {
      page = page > 1 ? page : 1;
      int offset = (page - 1) * size;

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
      iPrint("searchLeading_tag where $where");
      List<UserCollectModel> list = await repo.page(
        limit: size,
        offset: offset,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
      );
      iPrint("searchLeading_tag list ${list.length}");
      if (page == 1 && list.isEmpty) {
        // 第1页没有查到数据的时候到服务端去查询
      } else {
        return list;
      }
    }

    Map<String, dynamic> args = {
      'page': page,
      'size': size,
    };
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
    Map<String, dynamic>? payload = await UserCollectProvider().page(args);
    if (payload == null) {
      return [];
    }
    for (var json in payload['list']) {
      json['user_id'] = json['user_id'] ?? UserRepoLocal.to.currentUid;
      UserCollectModel model = UserCollectModel.fromJson(json);
      await repo.save(json);
      list.add(model);
    }
    return list;
  }

  /// 显示分类标签
  /// scene page | detail
  Widget buildItemBody(UserCollectModel obj, String scene) {
    Widget body = const Spacer();
    // String type =
    //     obj.info['payload']['msg_type'] ?? '';
    // Kind 被收藏的资源种类： 1 文本  2 图片  3 语音  4 视频  5 文件  6 位置消息
    if (obj.kind == 1) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              obj.info['text'] ?? (obj.info['payload']['text'] ?? ''),
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.normal,
              ),
              maxLines: scene == 'page' ? 4 : 160,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else if (obj.kind == 2) {
      String uri = obj.info['payload']['uri'] ?? '';
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          scene == 'page'
              ? Image(
            width: Get.width * 0.5,
            height: 120,
            fit: BoxFit.cover,
            image: cachedImageProvider(
              uri,
              w: Get.width,
            ),
          )
              : InkWell(
            onTap: () async {
              zoomInPhotoView(uri);
            },
            child: Image(
              // detail 里面减去左右 padding 和
              width: Get.width - 20,
              fit: BoxFit.cover,
              image: cachedImageProvider(
                uri,
                w: Get.width,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Text(
                  formatBytes(obj.info['payload']['size'] ?? ''),
                  style: const TextStyle(
                    // color: AppColors.MainTextColor,
                    fontSize: 14.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  " ${obj.info['payload']['width']}X${obj.info['payload']['height']}",
                  style: const TextStyle(
                    // color: AppColors.MainTextColor,
                    fontSize: 14.0,
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
      int durationMS = obj.info['payload']['durationMs'] ?? 0;
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
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              children: const [
                Icon(
                  Icons.graphic_eq,
                  size: 28,
                ),
              ],
            ),
          ),
        ],
      )
          : Row(
        children: [
          SizedBox(
            height: 80,
            child: AudioMessageBuilder(
              type: obj.info['type'],
              user: User(
                id: UserRepoLocal.to.currentUid,
                name: UserRepoLocal.to.current.nickname,
                imageSource: UserRepoLocal.to.current.avatar,
              ),
              info: obj.info,
            ),
          ),
        ],
      );
    } else if (obj.kind == 4) {
      String uri = obj.info['payload']['thumb']['uri'] ?? '';
      // debugPrint("item_4_uri $uri");
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.centerRight,
            children: <Widget>[
              Image(
                width: scene == 'page' ? Get.width * 0.5 : Get.width - 20,
                height: scene == 'page' ? 120 : Get.height * 0.618,
                fit: BoxFit.cover,
                image: cachedImageProvider(
                  uri,
                  w: Get.width * 0.5,
                ),
              ),
              Positioned.fill(
                child: InkWell(
                  onTap: () {
                    final String uri = obj.info['payload']['video']['uri'] ?? '';
                    final String thumb =
                        obj.info['payload']['thumb']['uri'] ?? '';
                    // debugPrint("chat_video_user_collect_detail_view $uri; ${obj.info['payload']['video'].toString()}");
                    if (uri.isEmpty) {
                      EasyLoading.showError('收藏的视频消息格式有误，找不到 video uri');
                    } else {
                      Get.to(
                            () => VideoViewerPage(url: uri, thumb: thumb),
                        transition: Transition.rightToLeft,
                        popGesture: true, // 右滑，返回上一页
                      );
                    }
                  },
                  child: const SizedBox(
                    height: 100,
                    child: Center(
                      child: Icon(
                        Icons.video_library,
                        color: Colors.white,
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
                  formatBytes(obj.info['payload']['video']['size'] ?? 0),
                  style: const TextStyle(
                    // color: AppColors.MainTextColor,
                    fontSize: 14.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  " ${obj.info['payload']['video']['width']}X${obj.info['payload']['video']['height']}",
                  style: const TextStyle(
                    // color: AppColors.MainTextColor,
                    fontSize: 14.0,
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
      String mimeType =
      (obj.info['payload']['mime_type'] ?? '').toString().toLowerCase();
      body = scene == 'page'
          ? Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      obj.info['payload']['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.normal,
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
                    "$mimeType  ${formatBytes(obj.info['payload']['size'] ?? '')}",
                    style: const TextStyle(
                      // color: AppColors.MainTextColor,
                      fontSize: 14.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
              Text(
                obj.info['payload']['name'] ?? '',
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.normal,
                ),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  "${'file_size'.tr}: ${formatBytes(obj.info['payload']['size'] ?? '')}",
                  style: const TextStyle(
                    fontSize: 14.0,
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
                style: const TextStyle(
                  // color: AppColors.MainTextColor,
                  fontSize: 14.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      );
    } else if (obj.kind == 6) {
      String title = obj.info['payload']['title'] ?? '';
      String address = obj.info['payload']['address'] ?? '';

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
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  address,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    // color: AppColors.MainTextColor,
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              children: const [
                Icon(
                  Icons.location_on_outlined,
                  size: 28,
                ),
              ],
            ),
          ),
        ],
      )
          : Row(
        children: [
          Expanded(
            flex: 1,
            child: LocationMessageBuilder(
              width: Get.width - 20,
              height: Get.height - 160,
              user: User(
                id: UserRepoLocal.to.currentUid,
                name: UserRepoLocal.to.current.nickname,
                imageSource: UserRepoLocal.to.current.avatar,
              ),
              info: obj.info,
            ),
          ),
        ],
      );
    } else if (obj.kind == 7) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: VisitCardMessageBuilder(
              user: User(
                id: UserRepoLocal.to.currentUid,
                name: UserRepoLocal.to.current.nickname,
                imageSource: UserRepoLocal.to.current.avatar,
              ),
              info: obj.info,
            ),
          ),
        ],
      );
    }
    return scene == 'detail'
        ? SizedBox(
      width: Get.width - 8,
      height: Get.height - 120,
      child: SingleChildScrollView(child: body),
    )
        : body;
  }

  /// 点击分类标签，按Tag搜索
  Future<void> searchByTag(
      String tag,
      String kindTips,
      Function callback,
      ) async {
    state.page = 1;
    iPrint("searchLeading_tag searchByTag tag $tag, kindTips $kindTips");
    var list = await page(page: state.page, size: state.size, tag: tag);
    if (list.isNotEmpty) {
      state.page += 1;
    }
    state.items.value = list;

    state.searchTrailing = [
      InkWell(
          onTap: () {
            if (state.kwd.value.isEmpty) {
              return;
            }
            doSearch(state.kwd.value);
          },
          child: const Icon(Icons.search)),
    ].map((e) => e).obs;

    state.searchLeading = Row(
      children: [
        ElevatedButton(
          onPressed: () {
            state.searchLeading = null;
            state.searchTrailing = null;
            state.kwd = ''.obs;
            state.searchController.text = "";
            state.kindActive.value = !state.kindActive.value;
            state.kindActive.value = !state.kindActive.value;
            state.kind = 'all';
            callback();
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.pressed)) {
                  return Theme.of(Get.context!)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.75);
                }
                return Theme.of(Get.context!).colorScheme.surface;
              },
            ),
          ),
          child: Row(
            children: [
              // icon 翻转
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Transform.scale(
                  scaleX: -1,
                  child: Icon(
                    Icons.local_offer,
                    size: 18,
                    color: Theme.of(Get.context!)
                        .colorScheme
                        .onPrimary
                        .withValues(alpha: 0.75),
                  ),
                ),
              ),
              Text(
                kindTips,
                style: TextStyle(
                  color: Theme.of(Get.context!).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.close,
                size: 16,
                color:
                Theme.of(Get.context!).colorScheme.onPrimary.withValues(alpha: 0.75),
              ),
            ],
          ),
        ),
      ],
    ).obs;
  }

  /// 点击分类标签，按分类搜索
  Future<void> searchByKind(
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
    state.items.value = list;

    state.searchTrailing = [
      InkWell(
          onTap: () {
            if (state.kwd.value.isEmpty) {
              return;
            }
            doSearch(state.kwd.value);
          },
          child: const Icon(Icons.search)),
    ].map((e) => e).obs;

    state.searchLeading = Row(
      children: [
        ElevatedButton(
          onPressed: () {
            state.searchLeading = null;
            state.searchTrailing = null;
            state.kwd = ''.obs;
            state.searchController.text = "";
            state.kindActive.value = !state.kindActive.value;
            state.kindActive.value = !state.kindActive.value;
            state.kind = 'all';
            callback();
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>(
                  (Set<WidgetState> states) {
                if (states.contains(WidgetState.pressed)) {
                  return Theme.of(Get.context!)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.75);
                }
                return Theme.of(Get.context!).colorScheme.surface;
              },
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Transform.scale(
                  scaleX: -1,
                  child: Icon(
                    Icons.grid_view,
                    size: 18,
                    color: Theme.of(Get.context!)
                        .colorScheme
                        .onPrimary
                        .withValues(alpha: 0.8),
                  ),
                ),
              ),
              Text(
                kindTips,
                style: TextStyle(
                  color: Theme.of(Get.context!).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.close,
                size: 16,
                color:
                Theme.of(Get.context!).colorScheme.onPrimary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ],
    ).obs;
  }

  Future<List<dynamic>> doSearch(dynamic query) async {
    debugPrint("user_collect_s_doSearch ${query.toString()}");

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
    state.items.value = list;
    return list;
  }

  /// 删除收藏
  Future<bool> remove(UserCollectModel obj) async {
    bool res = await UserCollectProvider().remove(kindId: obj.kindId);
    if (res) {
      int res2 = await UserCollectRepo().delete(obj.kindId);
      res = res2 > 0 ? true : false;
    }
    return res;
  }

  /// Kind 被收藏的资源种类： 1 文本  2 图片  3 语音  4 视频  5 文件  6 位置消息  7 个人名片
  static int getCollectKind(Message message) {
    String customType = message.metadata?['custom_type'] ?? '';
    if (message is TextMessage) {
      return 1;
    } else if (message is ImageMessage) {
      return 2;
    } else if (customType == 'audio') {
      return 3;
    } else if (customType == 'video') {
      return 4;
    } else if (message is FileMessage) {
      return 5;
    } else if (customType == 'location') {
      return 6;
    } else if (customType == 'visit_card') {
      return 7;
    }

    return 0;
  }

  /// 收藏的信息来源，消息发布中的昵称或者备注
  Future<String> getCollectSource(String authorId) async {
    ContactModel? obj =
    await ContactRepo().findByUid(authorId, autoFetch: true);
    debugPrint(
        "userCollectLogic/getCollectSource ${obj?.title}; ${obj?.toJson().toString()} ;");
    if (obj == null) {
      return '';
    }
    return obj.title;
  }

  /// 添加收藏
  Future<bool> add({required String tb, required Message msg}) async {
    int kind = getCollectKind(msg);
    String source = await getCollectSource(msg.authorId);
    MessageModel? msg2 = await MessageRepo(tableName: tb).find(msg.id);
    if (msg2 == null) {
      return false;
    }
    Map<String, dynamic> info = msg2.toJson();
    var payload = info['payload'];
    if (payload is String) {
      info['payload'] = jsonDecode(payload);
    }
    bool res = await UserCollectProvider().add(
      kind,
      msg.id,
      source,
      info,
    );
    debugPrint(
        "userCollectLogic/add $kind, $source, info ${info.toString()} ;");
    if (res) {
      await UserCollectRepo().save({
        UserCollectRepo.createdAt: DateTimeHelper.millisecond(),
        UserCollectRepo.userId: UserRepoLocal.to.currentUid,
        UserCollectRepo.kind: kind,
        UserCollectRepo.kindId: msg.id,
        UserCollectRepo.source: source,
        UserCollectRepo.info: info
      });
    }
    return res;
  }

  /// 转发收藏回调
  Future<bool> change(String kindId) async {
    bool res = await UserCollectProvider().change({
      'action': 'transpond_callback',
      'kind_id': kindId,
    });

    if (res) {
      await UserCollectRepo().save({
        UserCollectRepo.updatedAt: DateTimeHelper.millisecond(),
        UserCollectRepo.userId: UserRepoLocal.to.currentUid,
        UserCollectRepo.kindId: kindId
      });
    }
    return res;
  }

  /// 备注收藏
  Future<bool> remark(String kindId, String remark) async {
    bool res = await UserCollectProvider().change({
      'action': 'remark',
      'kind_id': kindId,
      'remark': remark,
    });
    debugPrint("send_to_view callback after $res");
    if (res) {
      await UserCollectRepo().save({
        UserCollectRepo.updatedAt: DateTimeHelper.millisecond(),
        UserCollectRepo.userId: UserRepoLocal.to.currentUid,
        UserCollectRepo.kindId: kindId,
        UserCollectRepo.remark: remark,
      });
    }
    return res;
  }

  Future<List<Widget>> tagItems() async {
    String scene = 'collect';
    List<Widget> widgetList = [];
    List<String> items = await UserTagRelationLogic().getRecentTagItems(scene);

    for (String tag in items) {
      widgetList.add(ElevatedButton(
        onPressed: () {
          debugPrint("searchLeading_tag $tag ${state.searchLeading.toString()}");
          state.kindActive.value = !state.kindActive.value;
          searchByTag(tag, tag, () {
            state.kindActive.value = !state.kindActive.value;
          });
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return Theme.of(Get.context!)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.75);
              }
              return Theme.of(Get.context!)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.95);
            },
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 2, right: 2),
          child: Text(
            tag,
            style: TextStyle(color: Theme.of(Get.context!).colorScheme.onPrimary),
          ),
        ),
      ));
    }
    return widgetList;
  }

  void updateItem(UserCollectModel item) {
    final index = state.items.indexWhere((e) => e.kindId == item.kindId);
    if (index > -1) {
      state.items.setRange(index, index + 1, [item]);
    }
  }
}