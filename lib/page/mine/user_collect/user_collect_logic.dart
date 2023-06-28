import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show formatBytes;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/message/message_audio_builder.dart';
import 'package:imboy/component/message/message_location_builder.dart';
import 'package:imboy/component/message/message_visit_card_builder.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/single/video_viewer.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:imboy/store/provider/user_collect_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_collect_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'user_collect_state.dart';

class UserCollectLogic extends GetxController {
  final UserCollectState state = UserCollectState();

  Future<List<UserCollectModel>> page(
      {int page = 1, int size = 10, String? kind, String? kwd}) async {
    List<UserCollectModel> list = [];
    page = page > 1 ? page : 1;
    int offset = (page - 1) * size;
    var repo = UserCollectRepo();

    // TODO kwd search 2023-06-14 23:33:09
    // 检查网络状态
    var res = await Connectivity().checkConnectivity();
    if (res == ConnectivityResult.none) {
      String where = '${UserCollectRepo.userId}=?';
      List<Object?> whereArgs = [UserRepoLocal.to.currentUid];
      String? orderBy;
      if (kind == state.recentUse) {
        orderBy = "${UserCollectRepo.updatedAt} desc";
        where = "$where and ${UserCollectRepo.updatedAt} > 0";
      } else if (int.tryParse(kind!) != null) {
        where = "$where and ${UserCollectRepo.kind}=?";
        whereArgs.add(kind);
      }
      if (strNoEmpty(kwd)) {
        where =
            "$where and (${UserCollectRepo.source} like '%$kwd%' or ${UserCollectRepo.remark} like '%$kwd%' or ${UserCollectRepo.info} like '%$kwd%')";
      }
      list = await repo.page(
        limit: size,
        offset: offset,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
      );
    }
    debugPrint("user_collect_s ${list.length}");
    if (list.isNotEmpty) {
      return list;
    }

    Map<String, dynamic> args = {
      'page': page,
      'size': size,
    };
    if (kind == state.recentUse) {
      args['order'] = state.recentUse;
    } else if (int.tryParse(kind!) != null) {
      args['kind'] = kind;
    }
    if (strNoEmpty(kwd)) {
      args['kwd'] = kwd;
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
      body = n.Row([
        Expanded(
          child: Text(
            obj.info['text'] ?? (obj.info['payload']['text'] ?? ''),
            style: const TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.normal,
            ),
            maxLines: scene == 'page' ? 4 : 16,
            overflow: TextOverflow.ellipsis,
          ),
        )
      ]);
    } else if (obj.kind == 2) {
      String uri = obj.info['payload']['uri'] ?? '';
      body = n.Row([
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
              )
      ]);
    } else if (obj.kind == 3) {
      int durationMS = obj.info['payload']['duration_ms'] ?? 0;
      // row > expand > column > text 换行有效
      body = scene == 'page'
          ? n.Row([
              Expanded(
                  flex: 9,
                  child: n.Column(
                    [
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
                    // 内容文本左对齐
                    crossAxisAlignment: CrossAxisAlignment.start,
                  )),
              // const Expanded(child: SizedBox()),
              Expanded(
                  flex: 1,
                  child: n.Column(const [
                    Icon(
                      Icons.graphic_eq,
                      size: 28,
                    ),
                  ])),
            ])
          : n.Row([
              SizedBox(
                height: 80,
                child: AudioMessageBuilder(
                  user: types.User(
                    id: UserRepoLocal.to.currentUid,
                    firstName: UserRepoLocal.to.current.nickname,
                    imageUrl: UserRepoLocal.to.current.avatar,
                  ),
                  message: MessageModel.fromJson(obj.info).toTypeMessage()
                      as types.CustomMessage,
                ),
              ),
            ])
        // 内容居中
        ..mainAxisAlignment = MainAxisAlignment.spaceBetween;
    } else if (obj.kind == 4) {
      String uri = obj.info['payload']['thumb']['uri'] ?? '';
      // debugPrint("item_4_uri $uri");
      body = n.Row([
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
        )
      ]);
    } else if (obj.kind == 5) {
      // String uri = obj.info['payload']['uri'] ?? '';
      String mimeType =
          (obj.info['payload']['mimeType'] ?? '').toString().toLowerCase();
      // Widget fileIcon = const Icon(
      //   Icons.quiz_outlined,
      //   size: 40,
      // );
      // if (mimeType == 'application/pdf') {
      //   fileIcon = const Icon(
      //     Icons.picture_as_pdf_outlined,
      //     size: 40,
      //   );
      // }
      body = scene == 'page'
          ? n.Row([
              n.Column(
                [
                  n.Row([
                    Text(
                      obj.info['payload']['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
                ],
                // 内容文本左对齐
                crossAxisAlignment: CrossAxisAlignment.start,
              ),
              const Expanded(child: SizedBox()),
              n.Column([
                n.Row([
                  Text(
                    "$mimeType  ${formatBytes(obj.info['payload']['size'] ?? '')}",
                    style: const TextStyle(
                      color: AppColors.MainTextColor,
                      fontSize: 14.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                ]),
                // fileIcon,
              ]),
            ])
          : n.Column([
              n.Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, [
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
              ]),
              n.Padding(
                top: 20,
                bottom: 20,
                child: n.Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, [
                  Text(
                    "${'文件大小'.tr}: ${formatBytes(obj.info['payload']['size'] ?? '')}",
                    style: const TextStyle(
                      fontSize: 14.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ]),
              ),
              n.Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, [
                Text(
                  mimeType,
                  style: const TextStyle(
                    color: AppColors.MainTextColor,
                    fontSize: 14.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ]);
    } else if (obj.kind == 6) {
      String title = obj.info['payload']['title'] ?? '';
      String address = obj.info['payload']['address'] ?? '';

      // row > expand > column > text 换行有效
      body = scene == 'page'
          ? n.Row([
              Expanded(
                flex: 9,
                child: n.Column(
                  [
                    Text(
                      title,
                      // "宝安区西乡径贝新村106号楼宝安区西乡径贝新村106号楼宝安区西乡径贝新村106号楼宝安区西乡径贝新村106号楼宝安区西乡径贝新村106号楼宝安区西乡径贝新村106号楼宝安区西乡径贝新村106号楼宝安区西乡径贝新村106号楼(…",
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
                      // "宝安区西乡径贝新村106号楼宝安区西乡径贝新村106号楼宝安区西乡径贝新村106号楼宝安区西乡径贝新村106号楼宝安区西乡径贝新村106号楼宝安区西乡径贝新村106号楼宝安区西乡径贝新村106号楼宝安区西乡径贝新村106号楼(…",
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.MainTextColor,
                        fontSize: 14.0,
                      ),
                    ),
                  ],
                  // 内容文本左对齐
                  crossAxisAlignment: CrossAxisAlignment.start,
                ),
              ),
              // const Expanded(flex: 1, child: SizedBox()),
              Expanded(
                  flex: 1,
                  child: n.Column(const [
                    Icon(
                      Icons.location_on_outlined,
                      size: 28,
                    ),
                  ])),
            ])
          : n.Row([
              Expanded(
                  flex: 1,
                  child: LocationMessageBuilder(
                    width: Get.width - 20,
                    height: Get.height - 160,
                    user: types.User(
                      id: UserRepoLocal.to.currentUid,
                      firstName: UserRepoLocal.to.current.nickname,
                      imageUrl: UserRepoLocal.to.current.avatar,
                    ),
                    message: MessageModel.fromJson(obj.info).toTypeMessage()
                        as types.CustomMessage,
                  ))
            ]);
    } else if (obj.kind == 7) {
      // row > expand > column > text 换行有效
      body = n.Row([
        Expanded(
            flex: 1,
            child: VisitCardMessageBuilder(
              // width: Get.width - 20,
              // height: Get.height - 160,
              user: types.User(
                id: UserRepoLocal.to.currentUid,
                firstName: UserRepoLocal.to.current.nickname,
                imageUrl: UserRepoLocal.to.current.avatar,
              ),
              message: MessageModel.fromJson(obj.info).toTypeMessage()
                  as types.CustomMessage,
            ))
      ]);
    }
    return body;
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

    state.searchLeading = n.Row([
      Icon(
        Icons.grid_view,
        size: 18,
        color: AppColors.MainTextColor.withOpacity(0.8),
      ),
      const SizedBox(width: 8),
      ElevatedButton(
        onPressed: () {
          // debugPrint("state.searchLeading ${state.searchLeading.toString()}");
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
          backgroundColor: MaterialStateProperty.resolveWith<Color>(
            (Set<MaterialState> states) {
              if (states.contains(MaterialState.pressed)) {
                return Colors.white.withOpacity(0.75);
              }
              // Use the component's default.
              return AppColors.ChatBg;
            },
          ),
        ),
        child: n.Row([
          Text(kindTips, style: const TextStyle(color: AppColors.ItemOnColor)),
          const SizedBox(width: 12),
          Icon(
            Icons.close,
            size: 16,
            color: AppColors.ItemOnColor.withOpacity(0.7),
          ),
        ]),
      )
    ]).obs;
  }

  Future<List<dynamic>> doSearch(query) async {
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
  static int getCollectKind(types.Message message) {
    String customType = message.metadata?['custom_type'] ?? '';
    if (message.type == types.MessageType.text) {
      return 1;
    } else if (message.type == types.MessageType.image) {
      return 2;
    } else if (customType == 'audio') {
      return 3;
    } else if (customType == 'video') {
      return 4;
    } else if (message.type == types.MessageType.file) {
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
  Future<bool> add(types.Message message) async {
    int kind = getCollectKind(message);
    String source = await getCollectSource(message.author.id);
    MessageModel? msg2 = await MessageRepo().find(message.id);
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
      message.id,
      source,
      info,
    );
    debugPrint(
        "userCollectLogic/add $kind, $source, info ${info.toString()} ;");
    if (res) {
      await UserCollectRepo().save({
        UserCollectRepo.createdAt: DateTimeHelper.currentTimeMillis(),
        UserCollectRepo.userId: UserRepoLocal.to.currentUid,
        UserCollectRepo.kind: kind,
        UserCollectRepo.kindId: message.id,
        UserCollectRepo.source: source,
        UserCollectRepo.info: info
      });
      // res = res2 > 0 ? true : false;
    }
    return res;
  }

  /// 转发收藏回调
  Future<bool> change(String kindId) async {
    bool res = await UserCollectProvider().change(
      action: 'transpond_callback',
      kindId: kindId,
    );

    debugPrint("send_to_view callback after $res");
    if (res) {
      await UserCollectRepo().save({
        UserCollectRepo.updatedAt: DateTimeHelper.currentTimeMillis(),
        UserCollectRepo.userId: UserRepoLocal.to.currentUid,
        UserCollectRepo.kindId: kindId
      });
      // res = res2 > 0 ? true : false;
    }
    return res;
  }

  Future<List<Widget>> tagItems() async {
    List<Widget> items = [];
    // items.add(ElevatedButton(
    //   onPressed: () {
    //     debugPrint("searchLeading ${state.searchLeading.toString()}");
    //     state.kindActive.value = !state.kindActive.value;
    //     // logic.searchByKind(key, value, () {
    //     //   state.kindActive.value = !state.kindActive.value;
    //     // });
    //   },
    //   style: ButtonStyle(
    //     backgroundColor: MaterialStateProperty.resolveWith<Color>(
    //           (Set<MaterialState> states) {
    //         if (states.contains(MaterialState.pressed)) {
    //           return Colors.white.withOpacity(0.75);
    //         }
    //         // Use the component's default.
    //         return Colors.white.withOpacity(0.95);
    //       },
    //     ),
    //   ),
    //   child: const Text(
    //     "  资料  ",
    //     style: TextStyle(color: AppColors.MainTextColor),
    //   ),
    // ));
    return items;
  }
}
