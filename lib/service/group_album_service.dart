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
      iPrint('GroupAlbumService: 获取群相册失败 - $e');
      return const {
        'list': <Map<String, dynamic>>[],
        'total': 0,
        'page': 1,
        'size': 20,
      };
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

  Future<Map<String, dynamic>?> uploadPhoto({
    required String groupId,
    required String albumId,
    required String photoName,
    required List<int> photoBytes,
  }) async {
    try {
      return await _api.uploadPhoto(
        groupId: groupId,
        albumId: albumId,
        photoName: photoName,
        photoBytes: photoBytes,
      );
    } catch (e) {
      iPrint('GroupAlbumService: 上传相册图片失败 - $e');
      return null;
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
      iPrint('GroupAlbumService: 获取相册图片失败 - $e');
      return const {
        'list': <Map<String, dynamic>>[],
        'total': 0,
        'page': 1,
        'size': 20,
      };
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
