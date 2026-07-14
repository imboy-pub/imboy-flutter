import 'package:imboy/component/ui/app_loading.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/error_code.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/component/http/http_response.dart';

class GroupApi extends HttpClient {
  Future<Map<String, dynamic>?> page({
    int page = 1,
    int size = 10,
    String attr = '', // owner | join | manager
  }) async {
    IMBoyHttpResponse resp = await get(
      API.groupPage,
      queryParameters: {'page': page, 'size': size, 'attr': attr},
    );

    if (!resp.ok) {
      return null;
    }
    return resp.payload as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>> detail({required String gid}) async {
    IMBoyHttpResponse resp = await get(
      API.groupDetail,
      queryParameters: {"gid": gid},
    );
    if (resp.ok == false) {
      AppLoading.showError(resp.msg);
    }
    if (!resp.ok) return <String, dynamic>{};
    final payload = resp.payload as Map<String, dynamic>;
    // P0-B B4：群详情携带 e2ee_mode（后端 SELECT *），此处同步本地旗标——
    // 覆盖开关广播之后才入群、没收到 group_e2ee_mode S2C 的成员
    final e2eeMode =
        payload['e2ee_mode'] ??
        (payload['group'] is Map ? payload['group']['e2ee_mode'] : null);
    if (e2eeMode != null) {
      await GroupSessionService.to.setGroupE2EEMode(
        gid,
        int.tryParse(e2eeMode.toString()) ?? 0,
      );
    }
    return payload;
  }

  /// 获取群备注（仅自己可见）
  Future<String?> getRemark({required String gid}) async {
    IMBoyHttpResponse resp = await get(
      API.groupRemark,
      queryParameters: {'gid': gid},
    );
    if (!resp.ok) return null;
    return resp.payload['remark'] as String?;
  }

  /// 更新群备注（仅自己可见）
  Future<bool> updateRemark({
    required String gid,
    required String remark,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.groupRemark,
      data: {'gid': gid, 'remark': remark},
    );
    if (!resp.ok) {
      AppLoading.showError(resp.msg);
    }
    return resp.ok;
  }

  /// 开启群级 E2EE（仅群主，后端契约 0→1 单向，P0-B B4）
  Future<bool> setE2eeMode({required String gid}) async {
    IMBoyHttpResponse resp = await post(
      API.groupSetE2eeMode,
      data: {'gid': gid, 'e2ee_mode': 1},
    );
    if (!resp.ok) {
      AppLoading.showError(resp.msg);
      return false;
    }
    // 本地旗标立即升位；其他成员经 group_e2ee_mode S2C 广播 / 群详情同步
    await GroupSessionService.to.setGroupE2EEMode(gid, 1);
    return true;
  }

  Future<Map<String, dynamic>?> dissolve({required String gid}) async {
    IMBoyHttpResponse resp = await post(API.groupDissolve, data: {"gid": gid});
    if (resp.ok == false) {
      AppLoading.showError(resp.msg);
    }
    return resp.ok ? resp.payload as Map<String, dynamic>? : null;
  }

  /// 面对面建群
  Future<Map<String, dynamic>> groupFace2face({
    required String code,
    required String longitude,
    required String latitude,
  }) async {
    IMBoyHttpResponse resp = await get(
      API.groupFace2face,
      queryParameters: {
        "code": code,
        "longitude": longitude, // 经度
        "latitude": latitude, // 维度
      },
    );
    if (resp.ok == false) {
      AppLoading.showError(resp.msg);
    }
    return resp.ok ? resp.payload as Map<String, dynamic> : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> groupFace2faceSave({
    required String code,
    required String gid,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.groupFace2faceSave,
      data: {"code": code, "gid": gid},
    );
    if (resp.ok == false) {
      AppLoading.showError(resp.msg);
    }
    return resp.ok
        ? (resp.payload as Map<String, dynamic>)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>?> groupAdd({
    required List<String> memberUserIds,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.groupAdd,
      data: {"member_uids": memberUserIds},
    );
    return resp.ok ? resp.payload as Map<String, dynamic>? : null;
  }

  Future<bool> groupEdit({
    required String gid,
    required Map<String, dynamic> data,
  }) async {
    data['gid'] = gid;
    IMBoyHttpResponse resp = await post(API.groupEdit, data: data);
    if (resp.code == ErrorCode.ERROR) {
      AppLoading.showError(resp.msg);
    }
    return resp.ok ? true : false;
  }

  Future<int> addTag({required String scene, required String tagName}) async {
    IMBoyHttpResponse resp = await post(
      API.userTagAdd,
      data: {"scene": scene, "tag": tagName},
    );
    if (resp.code == ErrorCode.ERROR) {
      AppLoading.showError(resp.msg);
    }
    return resp.ok ? ((resp.payload['tagId'] as num?)?.toInt() ?? 0) : 0;
  }

  Future<Map<String, dynamic>?> pageRelation({
    int page = 1,
    int size = 10,
    required int tagId,
    String scene = '',
    String? kwd,
  }) async {
    String api = API.userTagRelationFriendPage;
    if (scene == 'collect') {
      api = API.userTagRelationCollectPage;
    } else if (scene == 'friend') {
      api = API.userTagRelationFriendPage;
    }
    IMBoyHttpResponse resp = await get(
      api,
      queryParameters: {
        'page': page,
        'size': size,
        'scene': scene,
        'tag_id': tagId,
        'kwd': kwd,
      },
    );

    if (!resp.ok) {
      return null;
    }
    return resp.payload as Map<String, dynamic>?;
  }

  Future<bool> removeRelation({
    required int tagId,
    required String objectId,
    required String scene,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.userTagRelationRemove,
      data: {"scene": scene, "tagId": tagId, "objectId": objectId},
    );
    return resp.ok ? true : false;
  }

  Future<bool> setRelation({
    required int tagId,
    required String tagName,
    required List<String> objectIds,
    required String scene,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.userTagRelationSet,
      data: {
        "scene": scene,
        "tagId": tagId,
        "tagName": tagName,
        "objectIds": objectIds,
      },
    );
    return resp.ok ? true : false;
  }

  /// 转让群主
  /// [gid] 群组ID
  /// [newOwnerUid] 新群主用户ID
  Future<bool> transfer({
    required String gid,
    required String newOwnerUid,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.groupTransfer,
      data: {'gid': gid, 'new_owner_uid': newOwnerUid},
    );

    return resp.ok;
  }
}
