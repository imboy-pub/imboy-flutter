import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show formatBytes;
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:imboy/store/provider/user_collect_provider.dart';
import 'package:imboy/store/repository/user_collect_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;

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
        // where: '${UserCollectRepo.userId}=? and ('
        //     '${UserCollectRepo.source} like "%$kwd%" or ${UserCollectRepo.remark} like "%$kwd%"'
        //     ')',
        // whereArgs: [UserRepoLocal.to.currentUid],
        // orderBy: "${UserCollectRepo.createdAt} desc",
        where =
            "$where and (${UserCollectRepo.source} like \"%$kwd%\" or ${UserCollectRepo.remark} like \"%$kwd%\" or ${UserCollectRepo.info} like \"%$kwd%\")";
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
  Widget buildItemBody(UserCollectModel obj) {
    Widget body = const Spacer();
    // String type =
    //     obj.info['payload']['msg_type'] ?? '';
    // Kind 被收藏的资源种类： 1 文本  2 图片  3 语音  4 视频  5 文件  6 位置消息
    if (obj.kind == 1) {
      body = n.Row([
        Expanded(
          child: Text(
            obj.info['payload']['text'] ?? '',
            style: const TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.normal,
            ),
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
          ),
        )
      ]);
    } else if (obj.kind == 2) {
      String uri = obj.info['payload']['uri'] ?? '';
      body = n.Row([
        Image(
          width: Get.width * 0.5,
          height: 120,
          fit: BoxFit.cover,
          image: cachedImageProvider(
            uri,
            w: Get.width * 0.5,
          ),
        )
        // n.Column([]),
        // n.Column([]),
      ]);
    } else if (obj.kind == 3) {
      int durationMS = obj.info['payload']['duration_ms'] ?? 0;
      // row > expand > column > text 换行有效
      body = n.Row([
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
                Icons.record_voice_over_outlined,
                size: 28,
              ),
            ])),
      ]);
    } else if (obj.kind == 4) {
      String uri = obj.info['payload']['thumb']['uri'] ?? '';
      // debugPrint("item_4_uri $uri");
      body = n.Row([
        Image(
          width: Get.width * 0.5,
          height: 120,
          fit: BoxFit.cover,
          image: cachedImageProvider(
            uri,
            w: Get.width * 0.5,
          ),
        ),
        const Positioned.fill(
          child: SizedBox(
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
        // n.Column([]),
        // n.Column([]),
      ]);
      body = n.Row([
        Stack(
          alignment: Alignment.centerRight,
          children: <Widget>[
            Image(
              width: Get.width * 0.5,
              height: 120,
              fit: BoxFit.cover,
              image: cachedImageProvider(
                uri,
                w: Get.width * 0.5,
              ),
            ),
            const Positioned.fill(
              child: SizedBox(
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
      body = n.Row([
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
      ]);
    } else if (obj.kind == 6) {
      String title = obj.info['payload']['title'] ?? '';
      String address = obj.info['payload']['address'] ?? '';

      // row > expand > column > text 换行有效
      body = n.Row([
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
}
