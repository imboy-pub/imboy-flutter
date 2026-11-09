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
import 'package:mime/mime.dart';

/// 群相册 bind_batch 请求 seam（默认 POST /v1/group_album/photo/bind_batch；
/// 测试注入 fake）。
typedef GroupAlbumBindBatchFn = Future<IMBoyHttpResponse> Function(
  Map<String, dynamic> body,
);

/// 一次待直传的相册照片（本地重试时保留 file 与 clientUploadId）。
class GroupAlbumUploadItem {
  final io.File file;
  final String photoName;

  /// direct 会话幂等恢复键：同 item 重试复用同值，register 幂等恢复会话。
  final String clientUploadId;

  const GroupAlbumUploadItem({
    required this.file,
    required this.photoName,
    required this.clientUploadId,
  });
}

/// 单张照片的批量上传结果（逐项有账：失败项可单独重试，不整批回滚）。
class GroupAlbumUploadOutcome {
  final GroupAlbumUploadItem item;
  final bool ok;

  /// 失败原因码（direct_failed / unsupported_image_type / bind_rejected /
  /// bind_batch_failed / missing_result）；成功为空串。
  final String reason;

  /// bind 成功时的照片行（含 id/photo_id；重复 bind 为 duplicate:true）。
  final Map<String, dynamic>? photo;

  const GroupAlbumUploadOutcome({
    required this.item,
    required this.ok,
    this.reason = '',
    this.photo,
  });
}

/// 群相册 API 客户端
class GroupAlbumApi extends HttpClient {
  /// 相册可 bind 的图片 MIME 白名单（backend group_album_ds
  /// ?ALLOWED_IMAGE_TYPES，逐字一致；image/jpg 非标准别名归一为 jpeg）。
  static const Set<String> albumAllowedMimeTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
  };

  /// bind_batch 单批上限（backend group_album_handler：length(Items) > 50 拒）。
  static const int bindBatchLimit = 50;

  /// 相册照片 MIME 解析（白名单外返回 null——不发起无谓的 direct 会话）。
  static String? albumMimeOf(String path, String fileName) {
    final String raw =
        lookupMimeType(fileName.isNotEmpty ? fileName : path) ??
        lookupMimeType(path) ??
        '';
    final String mime = raw == 'image/jpg' ? 'image/jpeg' : raw;
    return albumAllowedMimeTypes.contains(mime) ? mime : null;
  }

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

  /// 获取群相册列表
  Future<Map<String, dynamic>> getAlbums({
    required String groupId,
    int page = 1,
    int size = 20,
  }) async {
    final resp = await get(
      API.groupAlbumList,
      queryParameters: {'gid': groupId, 'page': page, 'size': size},
    );

    // 请求失败必须上抛：伪造空分页会让"网络挂了"渲染成"群相册被清空了"。
    // 链路：GroupAlbumService.getAlbums(rethrow) → group_album_page(_loadFailed)
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

  /// 创建群相册
  Future<Map<String, dynamic>?> createAlbum({
    required String groupId,
    required String albumName,
    dynamic coverPhotoId,
  }) async {
    final gid = groupId.trim();
    final name = albumName.trim();
    if (gid.isEmpty || name.isEmpty) {
      return null;
    }

    final data = <String, dynamic>{'gid': gid, 'album_name': name};
    final cover = coverPhotoId?.toString().trim();
    if (cover != null && cover.isNotEmpty) {
      data['cover_photo_id'] = cover;
    }

    final resp = await post(API.groupAlbumCreate, data: data);

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return Map<String, dynamic>.from(
      IMBoyHttpResponse.payloadAsMap(resp.payload),
    );
  }

  /// 重命名群相册
  Future<bool> renameAlbum({
    required dynamic albumId,
    required String albumName,
  }) async {
    final id = albumId?.toString().trim() ?? '';
    final name = albumName.trim();
    if (id.isEmpty || name.isEmpty) {
      return false;
    }
    final resp = await post(
      API.groupAlbumRename,
      data: {'album_id': id, 'album_name': name},
    );
    return resp.ok;
  }

  /// direct-v1 批量直传相册照片（V3-12；multipart 正文上传已退役，不留
  /// fallback）。逐项 register(scope=group)→declare→grant→流式 PUT→finalize
  /// （全程不 readAsBytes，R04），CONFIRMED 项汇总进一次/分批
  /// `POST /v1/group_album/photo/bind_batch`。
  ///
  /// bind_batch 合同（backend group_album_ds.bind_photos，只读核对）：
  /// * 返回 `{results:[{object_key,status:'ok'|'error',photo?,reason?}]}`
  ///   ——逐项结果，部分失败继续，不整批回滚；
  /// * 同 album+object_key 重复 bind 幂等（duplicate:true，status 仍 ok）；
  /// * 跨群/非本人 object_key 逐项 cross_subject 拒（error 项）。
  ///
  /// 逐项返回 [GroupAlbumUploadOutcome]；单项 direct 失败/白名单外 MIME 不
  /// 阻断其余项。bind_batch 传输层失败时，已 CONFIRMED 未绑定的项记
  /// `bind_batch_failed`（保留本地重试：重试走 bind_batch 幂等）。
  Future<List<GroupAlbumUploadOutcome>> uploadPhotosDirect({
    required String groupId,
    required String albumId,
    required List<GroupAlbumUploadItem> items,
    DirectSessionFn? sessionFn,
    DirectFilePutFn? putFn,
    GroupAlbumBindBatchFn? bindBatchFn,
  }) async {
    final String gid = groupId.trim();
    final String aid = albumId.trim();
    if (gid.isEmpty || aid.isEmpty || items.isEmpty) {
      return const <GroupAlbumUploadOutcome>[];
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

      // 逐项 direct：白名单外直接落账失败；direct 异常按项吞掉（其余项继续）。
      // outcomes 按输入顺序占位（成功项在 bind 后回填），调用方按下标对账。
      final List<GroupAlbumUploadOutcome?> slots =
          List<GroupAlbumUploadOutcome?>.filled(items.length, null);
      final List<_ReadyBind> ready = <_ReadyBind>[];
      for (int i = 0; i < items.length; i++) {
        check();
        final GroupAlbumUploadItem item = items[i];
        final String? mime = albumMimeOf(item.file.path, item.photoName);
        if (mime == null) {
          slots[i] = GroupAlbumUploadOutcome(
            item: item,
            ok: false,
            reason: 'unsupported_image_type',
          );
          continue;
        }
        try {
          final DirectUploadResult direct =
              await DirectAttachmentApi.uploadFile(
                item.file,
                fileName: item.photoName,
                mime: mime,
                scope: 'group',
                scopeRef: gid,
                clientUploadId: item.clientUploadId,
                sessionFn: session,
                putFn: putFn,
                cancelToken: cancel,
              );
          check();
          if (direct.state != DirectAttachmentApi.stateConfirmed) {
            slots[i] = GroupAlbumUploadOutcome(
              item: item,
              ok: false,
              reason: 'not_confirmed',
            );
            continue;
          }
          ready.add(
            _ReadyBind(
              item: item,
              slotIndex: i,
              objectKey: direct.objectKey,
              mime: mime,
            ),
          );
        } on DirectUploadCancelled {
          check();
          // 本地取消：按项失败记账（不阻断其余项，本地可重试）
          slots[i] = GroupAlbumUploadOutcome(
            item: item,
            ok: false,
            reason: 'cancelled',
          );
        } on Exception {
          check();
          slots[i] = GroupAlbumUploadOutcome(
            item: item,
            ok: false,
            reason: 'direct_failed',
          );
        }
      }
      if (ready.isEmpty) {
        return slots.cast<GroupAlbumUploadOutcome>();
      }

      // bind_batch：≤50/批（backend 硬门）；每批后合并逐项结果。
      // C08（source-audit C08-album-partial）：bindBatch 抛出的传输层异常
      // 与 !resp.ok 同形态按项落账——异常不再逃逸出本方法吞掉前面批次
      // 已回填的结果（部分失败继续，逐项有账）。
      Future<IMBoyHttpResponse> bindBatch(Map<String, dynamic> body) async {
        check();
        final response = bindBatchFn != null
            ? await bindBatchFn(body)
            : await post(
                API.groupAlbumPhotoBindBatch,
                data: body,
                cancelToken: cancel,
              );
        check();
        return response;
      }

      for (int i = 0; i < ready.length; i += bindBatchLimit) {
        check();
        final List<_ReadyBind> chunk = ready.sublist(
          i,
          i + bindBatchLimit > ready.length ? ready.length : i + bindBatchLimit,
        );
        Map<String, dynamic>? payload;
        try {
          final IMBoyHttpResponse resp = await bindBatch(<String, dynamic>{
            'gid': gid,
            'items': <Map<String, dynamic>>[
              for (final _ReadyBind r in chunk)
                <String, dynamic>{
                  'album_id': aid,
                  'photo_name': r.item.photoName,
                  'photo_size': r.item.file.lengthSync(),
                  'mime_type': r.mime,
                  'sha256': await sha256OfFile(r.item.file),
                  'object_key': r.objectKey,
                },
            ],
          });
          if (resp.ok && resp.payload != null) {
            payload = Map<String, dynamic>.from(
              IMBoyHttpResponse.payloadAsMap(resp.payload),
            );
          }
        } on Exception {
          check();
          // 传输层异常：整批按项落账失败（照片已 CONFIRMED，重试只重
          // bind_batch 幂等），继续下一批——不吞掉前序批次结果。
          payload = null;
        }
        if (payload == null) {
          for (final _ReadyBind r in chunk) {
            slots[r.slotIndex] = GroupAlbumUploadOutcome(
              item: r.item,
              ok: false,
              reason: 'bind_batch_failed',
            );
          }
          continue;
        }
        _matchBindResults(chunk, payload['results'], slots);
      }
      return slots.cast<GroupAlbumUploadOutcome>();
    } finally {
      authSessionReader.removeListener(onAuthChanged);
      task.finish();
    }
  }

  /// bind_batch 逐项结果按 object_key 对回本地 item（结果缺项视为失败），
  /// 回填到 [slots] 对应下标。
  static void _matchBindResults(
    List<_ReadyBind> chunk,
    dynamic rawResults,
    List<GroupAlbumUploadOutcome?> slots,
  ) {
    final Map<String, Map<String, dynamic>> byKey =
        <String, Map<String, dynamic>>{};
    if (rawResults is List) {
      for (final dynamic r in rawResults) {
        if (r is Map) {
          final Map<String, dynamic> m = Map<String, dynamic>.from(r);
          byKey['${m['object_key']}'] = m;
        }
      }
    }
    for (final _ReadyBind r in chunk) {
      final Map<String, dynamic>? res = byKey[r.objectKey];
      if (res != null && '${res['status']}' == 'ok') {
        final dynamic photo = res['photo'];
        slots[r.slotIndex] = GroupAlbumUploadOutcome(
          item: r.item,
          ok: true,
          photo: photo is Map ? Map<String, dynamic>.from(photo) : res,
        );
      } else {
        slots[r.slotIndex] = GroupAlbumUploadOutcome(
          item: r.item,
          ok: false,
          reason: res == null ? 'missing_result' : 'bind_rejected',
        );
      }
    }
  }

  /// 获取相册图片列表
  Future<Map<String, dynamic>> getPhotos({
    required String albumId,
    int page = 1,
    int size = 20,
  }) async {
    final aid = albumId.trim();
    if (aid.isEmpty) {
      return const {
        'list': <Map<String, dynamic>>[],
        'total': 0,
        'page': 1,
        'size': 20,
      };
    }

    final resp = await get(
      API.groupAlbumPhotoList,
      queryParameters: {'album_id': aid, 'page': page, 'size': size},
    );

    // 同 getAlbums；且伪造 total=0 还会让分页误判 _hasMore
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

  /// 获取相册图片详情
  Future<Map<String, dynamic>?> getPhotoDetail(dynamic photoId) async {
    if (photoId == null) return null;
    final text = photoId.toString().trim();
    if (text.isEmpty) return null;

    final resp = await get(
      API.groupAlbumPhotoDetail,
      queryParameters: {'photo_id': text},
    );

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return Map<String, dynamic>.from(
      IMBoyHttpResponse.payloadAsMap(resp.payload),
    );
  }

  /// 删除相册图片
  Future<bool> deletePhoto(dynamic photoId) async {
    if (photoId == null) return false;
    final text = photoId.toString().trim();
    if (text.isEmpty) return false;

    final resp = await post(
      API.groupAlbumPhotoDelete,
      data: {'photo_id': text},
    );
    return resp.ok;
  }

  /// 设为群相册封面
  Future<bool> updateAlbumCover({
    required dynamic albumId,
    required dynamic photoId,
  }) async {
    final aid = albumId?.toString().trim() ?? '';
    final pid = photoId?.toString().trim() ?? '';
    if (aid.isEmpty || pid.isEmpty) return false;

    final resp = await post(
      API.groupAlbumCoverUpdate,
      data: {'album_id': aid, 'photo_id': pid},
    );
    return resp.ok;
  }

  /// 删除群相册
  Future<bool> deleteAlbum(dynamic albumId) async {
    if (albumId == null) return false;
    final text = albumId.toString().trim();
    if (text.isEmpty) return false;
    final resp = await post(API.groupAlbumDelete, data: {'album_id': text});
    return resp.ok;
  }
}

/// direct CONFIRMED 待 bind 的中间态（object_key 与 mime 属会话冻结值；
/// slotIndex 记输入下标，bind 结果按原顺序回填）。
class _ReadyBind {
  final GroupAlbumUploadItem item;
  final int slotIndex;
  final String objectKey;
  final String mime;

  const _ReadyBind({
    required this.item,
    required this.slotIndex,
    required this.objectKey,
    required this.mime,
  });
}
