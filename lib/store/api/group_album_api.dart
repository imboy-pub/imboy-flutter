import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';

/// 群相册 API 客户端
class GroupAlbumApi extends HttpClient {
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
    debugPrint("GroupAlbumApi_getAlbums resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return const {
        'list': <Map<String, dynamic>>[],
        'total': 0,
        'page': 1,
        'size': 20,
      };
    }

    final payload = Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>);
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
    debugPrint("GroupAlbumApi_createAlbum resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>);
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
    debugPrint("GroupAlbumApi_renameAlbum resp: ok=${resp.ok}");
    return resp.ok;
  }

  /// 上传相册图片
  Future<Map<String, dynamic>?> uploadPhoto({
    required String groupId,
    required String albumId,
    required String photoName,
    required List<int> photoBytes,
  }) async {
    final gid = groupId.trim();
    final aid = albumId.trim();
    final name = photoName.trim();
    if (gid.isEmpty || aid.isEmpty || name.isEmpty || photoBytes.isEmpty) {
      return null;
    }

    final resp = await post(
      API.groupAlbumPhotoUpload,
      data: FormData.fromMap({
        'gid': gid,
        'album_id': aid,
        'photo_name': name,
        'photo': MultipartFile.fromBytes(photoBytes, filename: name),
      }),
      options: Options(contentType: 'multipart/form-data'),
    );
    debugPrint("GroupAlbumApi_uploadPhoto resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>);
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
    debugPrint("GroupAlbumApi_getPhotos resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return const {
        'list': <Map<String, dynamic>>[],
        'total': 0,
        'page': 1,
        'size': 20,
      };
    }

    final payload = Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>);
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
    debugPrint("GroupAlbumApi_getPhotoDetail resp: ok=${resp.ok}");

    if (!resp.ok || resp.payload == null) {
      return null;
    }

    return Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>);
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
    debugPrint("GroupAlbumApi_deletePhoto resp: ok=${resp.ok}");
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
    debugPrint("GroupAlbumApi_updateAlbumCover resp: ok=${resp.ok}");
    return resp.ok;
  }

  /// 删除群相册
  Future<bool> deleteAlbum(dynamic albumId) async {
    if (albumId == null) return false;
    final text = albumId.toString().trim();
    if (text.isEmpty) return false;
    final resp = await post(API.groupAlbumDelete, data: {'album_id': text});
    debugPrint("GroupAlbumApi_deleteAlbum resp: ok=${resp.ok}");
    return resp.ok;
  }
}
