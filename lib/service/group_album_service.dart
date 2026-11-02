import 'package:flutter/foundation.dart';
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/store/api/group_album_api.dart';

/// 群相册服务
class GroupAlbumService {
  static GroupAlbumService _instance = GroupAlbumService._privateConstructor();
  static GroupAlbumService get to => _instance;

  @visibleForTesting
  static set instanceForTest(GroupAlbumService? service) {
    _instance = service ?? GroupAlbumService._privateConstructor();
  }

  GroupAlbumService._privateConstructor() : _api = GroupAlbumApi();
  GroupAlbumService.withApi(this._api);

  final GroupAlbumApi _api;

  Future<Map<String, dynamic>> getAlbums({
    required String groupId,
    int page = 1,
    int size = 20,
  }) async {
    try {
      return await _api.getAlbums(groupId: groupId, page: page, size: size);
    } catch (e) {
      // 不 fail-open：伪造空分页会让"网络挂了"渲染成"群相册被清空了"。
      // 调用点 group_album_page._loadAlbums 已据此渲染失败态 + 重试。
      iPrint('GroupAlbumService: 获取群相册失败 - $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> createAlbum({
    required String groupId,
    required String albumName,
    dynamic coverPhotoId,
  }) async {
    try {
      return await _api.createAlbum(
        groupId: groupId,
        albumName: albumName,
        coverPhotoId: coverPhotoId,
      );
    } catch (e) {
      iPrint('GroupAlbumService: 创建群相册失败 - $e');
      return null;
    }
  }

  Future<bool> renameAlbum({
    required dynamic albumId,
    required String albumName,
  }) async {
    try {
      return await _api.renameAlbum(albumId: albumId, albumName: albumName);
    } catch (e) {
      iPrint('GroupAlbumService: 重命名群相册失败 - $e');
      return false;
    }
  }

  /// direct-v1 批量直传相册照片（逐项 direct + bind_batch）。
  ///
  /// 逐项返回 [GroupAlbumUploadOutcome]（失败项保留本地重试：同
  /// clientUploadId 重试幂等恢复 direct 会话；bind_batch 重复调用幂等）。
  /// 整体异常（网络不可达等）时全部按 network_error 落账，不吞失败。
  Future<List<GroupAlbumUploadOutcome>> uploadPhotosDirect({
    required String groupId,
    required String albumId,
    required List<GroupAlbumUploadItem> items,
  }) async {
    try {
      return await _api.uploadPhotosDirect(
        groupId: groupId,
        albumId: albumId,
        items: items,
      );
    } catch (e) {
      iPrint('GroupAlbumService: 批量上传相册图片失败 - $e');
      return <GroupAlbumUploadOutcome>[
        for (final item in items)
          GroupAlbumUploadOutcome(
            item: item,
            ok: false,
            reason: 'network_error',
          ),
      ];
    }
  }

  Future<Map<String, dynamic>> getPhotos({
    required String albumId,
    int page = 1,
    int size = 20,
  }) async {
    try {
      return await _api.getPhotos(albumId: albumId, page: page, size: size);
    } catch (e) {
      // 不 fail-open：同 getAlbums，且分页场景伪造 total=0 会误判 _hasMore。
      iPrint('GroupAlbumService: 获取相册图片失败 - $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getPhotoDetail(dynamic photoId) async {
    try {
      return await _api.getPhotoDetail(photoId);
    } catch (e) {
      iPrint('GroupAlbumService: 获取相册图片详情失败 - $e');
      return null;
    }
  }

  Future<bool> deletePhoto(dynamic photoId) async {
    try {
      return await _api.deletePhoto(photoId);
    } catch (e) {
      iPrint('GroupAlbumService: 删除相册图片失败 - $e');
      return false;
    }
  }

  Future<bool> updateAlbumCover({
    required dynamic albumId,
    required dynamic photoId,
  }) async {
    try {
      return await _api.updateAlbumCover(albumId: albumId, photoId: photoId);
    } catch (e) {
      iPrint('GroupAlbumService: 设置相册封面失败 - $e');
      return false;
    }
  }

  Future<bool> deleteAlbum(dynamic albumId) async {
    try {
      return await _api.deleteAlbum(albumId);
    } catch (e) {
      iPrint('GroupAlbumService: 删除群相册失败 - $e');
      return false;
    }
  }
}
