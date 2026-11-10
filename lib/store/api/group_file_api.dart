import 'dart:io' as io;

import 'package:dio/dio.dart' show CancelToken;
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/api/attachment_direct_api.dart';

/// 群文件 bind 请求 seam（默认 POST /v1/group/file/bind；测试注入 fake）。
typedef GroupFileBindFn = Future<IMBoyHttpResponse> Function(
  Map<String, dynamic> body,
);

/// 群文件 API 客户端
class GroupFileApi extends HttpClient {
  int _toInt(dynamic raw, {int fallback = 0}) {
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? fallback;
    return fallback;
  }

  List<Map<String, dynamic>> _normalizeList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _normalizeCategoryStats(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map((item) {
      final map = Map<String, dynamic>.from(item);
      map['category'] = (map['category'] ?? '').toString();
      map['count'] = _toInt(map['count']);
      map['total_size'] = _toInt(map['total_size']);
      return map;
    }).toList();
  }

  /// 获取群文件列表
  Future<Map<String, dynamic>> getFiles({
    required String groupId,
    int page = 1,
    int size = 20,
    String? category,
  }) async {
    final query = <String, dynamic>{'gid': groupId, 'page': page, 'size': size};
    if (category != null && category.trim().isNotEmpty) {
      query['category'] = category.trim();
    }

    final resp = await get(API.groupFileList, queryParameters: query);

    // 链路：GroupFileService.getFiles(rethrow) → group_file_page._loadFiles(_error)
    resp.throwIfFailed();

    if (resp.payload == null) {
      return const {
        'list': <Map<String, dynamic>>[],
        'total': 0,
        'page': 1,
        'size': 20,
      };
    }

    final payload = Map<String, dynamic>.from(
      IMBoyHttpResponse.payloadAsMap(resp.payload),
    );
    final list = _normalizeList(payload['list'] ?? payload['items']);
    final total = _toInt(payload['total'], fallback: list.length);
    return {
      'list': list,
      'total': total,
      'page': _toInt(payload['page'], fallback: page),
      'size': _toInt(payload['size'], fallback: size),
    };
  }

  /// 获取群文件分类统计
  Future<List<Map<String, dynamic>>> getCategoryStats({
    required String groupId,
  }) async {
    final gid = groupId.trim();
    if (gid.isEmpty) {
      return [];
    }

    final resp = await get(
      API.groupFileCategories,
      queryParameters: {'gid': gid},
    );

    // 分类统计失败不阻塞列表：group_file_page._loadCategoryStats 已 catch 并降级
    resp.throwIfFailed();

    if (resp.payload == null) {
      return [];
    }

    final payload = Map<String, dynamic>.from(
      IMBoyHttpResponse.payloadAsMap(resp.payload),
    );
    return _normalizeCategoryStats(payload['items'] ?? payload['list']);
  }

  /// 搜索群文件
  Future<Map<String, dynamic>> searchFiles({
    required String groupId,
    required String keyword,
    int page = 1,
    int size = 20,
  }) async {
    final gid = groupId.trim();
    final kw = keyword.trim();
    if (gid.isEmpty || kw.isEmpty) {
      return const {
        'list': <Map<String, dynamic>>[],
        'total': 0,
        'page': 1,
        'size': 20,
      };
    }

    final resp = await get(
      API.groupFileSearch,
      queryParameters: {'gid': gid, 'keyword': kw, 'page': page, 'size': size},
    );

    // 链路：GroupFileService.searchFiles(rethrow) → group_file_page._loadFiles(_error)
    resp.throwIfFailed();

    if (resp.payload == null) {
      return const {
        'list': <Map<String, dynamic>>[],
        'total': 0,
        'page': 1,
        'size': 20,
      };
    }

    final payload = Map<String, dynamic>.from(
      IMBoyHttpResponse.payloadAsMap(resp.payload),
    );
    final list = _normalizeList(payload['items'] ?? payload['list']);
    final total = _toInt(payload['total'], fallback: list.length);
    return {
      'list': list,
      'total': total,
      'page': _toInt(payload['page'], fallback: page),
      'size': _toInt(payload['size'], fallback: size),
    };
  }

  /// direct-v1 直传群文件（V3-12；multipart 正文上传已退役，不留 fallback）。
  ///
  /// 链路：register(scope=group, scope_ref=gid) → declare → grant → 流式
  /// fixed-length PUT（全程不 readAsBytes，R04）→ finalize(CONFIRMED) →
  /// JSON bind `POST /v1/group/file/bind`。
  ///
  /// bind 合同（backend group_file_ds.validate_bind_metadata，只读核对）：
  /// * `file_md5` 必须空串——confirmed 附件只存 SHA-256，任何非空 MD5 都按
  ///   `unverifiable_file_md5` 整单拒绝；
  /// * `file_type` 必须与 declare 的 mime **逐字一致**（file_type_mismatch）；
  /// * `file_size` 必须与 confirmed size 一致（file_size_mismatch）。
  /// 跨群/跨账号 bind 被 cross_subject 拒（HTTP 403 信封）。
  ///
  /// 返回 bind payload（含 file_id）；direct 未 CONFIRMED（FINALIZING/封存）
  /// 或 bind 失败返回 null。direct 阶段异常原样上抛（调用方 catch 后可保留
  /// 本地文件用同 clientUploadId 重试——register 幂等恢复同一会话）。
  Future<Map<String, dynamic>?> uploadFileDirect({
    required String groupId,
    required io.File file,
    required String fileName,
    required String mime,
    String? clientUploadId,
    DirectSessionFn? sessionFn,
    DirectFilePutFn? putFn,
    GroupFileBindFn? bindFn,
  }) async {
    final String gid = groupId.trim();
    final String name = fileName.trim();
    if (gid.isEmpty || name.isEmpty) {
      return null;
    }

    final auth = authSessionReader.current;
    final owner = AccountLocalTaskOwner.capture(uid: auth.uid);
    final cancel = CancelToken();
    final task = AccountLocalTaskRegistry.instance.register(
      owner,
      onCancel: () => cancel.cancel('account local data cleanup'),
    );
    void check() {
      task.throwIfCancelled();
      if (!authSessionReader.isCurrent(auth) ||
          (currentEnv.isEmpty ? 'pro' : currentEnv) != owner.environment ||
          Env().apiBaseUrl != owner.endpoint) {
        throw const AccountLocalTaskCancelledException();
      }
    }

    void onAuthChanged() {
      if (!authSessionReader.isCurrent(auth)) {
        cancel.cancel('upload account changed');
      }
    }

    authSessionReader.addListener(onAuthChanged);
    try {
      check();
      // status 是 GET；其他 direct 操作使用 POST。
      Future<IMBoyHttpResponse> session(
        String path, {
        Map<String, dynamic>? body,
      }) async {
        check();
        final response = sessionFn != null
            ? await sessionFn(path, body: body)
            : path.endsWith('/status')
            ? await get(path, queryParameters: body, cancelToken: cancel)
            : await post(path, data: body, cancelToken: cancel);
        check();
        return response;
      }

      final DirectUploadResult direct = await DirectAttachmentApi.uploadFile(
        file,
        fileName: name,
        mime: mime,
        scope: 'group',
        scopeRef: gid,
        clientUploadId: clientUploadId,
        sessionFn: session,
        putFn: putFn,
        cancelToken: cancel,
      );
      check();
      if (direct.state != DirectAttachmentApi.stateConfirmed) {
        // FINALIZING/UNKNOWN_QUARANTINED：附件未经 proof，bind 只会被
        // not_confirmed 拒绝——不发起，如实报失败。
        return null;
      }

      final GroupFileBindFn bind =
          bindFn ??
          (Map<String, dynamic> body) =>
              post(API.groupFileBind, data: body, cancelToken: cancel);
      check();
      final IMBoyHttpResponse resp = await bind(<String, dynamic>{
        'gid': gid,
        'file_name': name,
        'file_type': mime,
        'object_key': direct.objectKey,
        'file_size': file.lengthSync(),
        'file_md5': '',
      });
      check();
      if (!resp.ok || resp.payload == null) {
        return null;
      }
      return Map<String, dynamic>.from(
        IMBoyHttpResponse.payloadAsMap(resp.payload),
      );
    } finally {
      authSessionReader.removeListener(onAuthChanged);
      task.finish();
    }
  }

  /// 删除群文件
  Future<bool> deleteFile(dynamic fileId) async {
    if (fileId == null) return false;
    final text = fileId.toString().trim();
    if (text.isEmpty) return false;
    final resp = await post(API.groupFileDelete, data: {'file_id': text});
    return resp.ok;
  }
}
